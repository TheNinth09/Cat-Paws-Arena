import 'dart:async';

import 'package:arena_engine/arena_engine.dart';

import 'match_store.dart';
import 'online_errors.dart';

/// One phone's view of a friend match. Both phones build the same engine
/// state from the shared seed and move log; every opponent move is replayed
/// with `arena_engine` and its hash compared before it is accepted.
///
/// Works without Cloud Functions: opponent moves arrive through
/// [watch] (Firestore listener) or [refresh] (polling / app resume).
class MatchSession {
  MatchSession._(this.store, this.record, this.uid, this.slot, this._state);

  static const config = MatchConfig.duel();

  final MatchStore store;
  final String uid;
  final PlayerSlot slot;
  MatchRecord record;
  MatchState _state;
  int _applied = 0;
  DateTime? _lastMoveAt;
  MatchFlag? _flag;

  /// Loads the match and replays the whole log, e.g. after an app restart.
  static Future<MatchSession> open(
    MatchStore store,
    String matchId,
    String uid,
  ) async {
    final record =
        await store.readMatch(matchId) ??
        (throw const OnlineException(OnlineErrorCode.notInMatch));
    final slot =
        record.slotOf(uid) ??
        (throw const OnlineException(OnlineErrorCode.notInMatch));
    final start = newMatch(record.seed, config);
    final session = MatchSession._(
      store,
      record,
      uid,
      slot,
      (start as EngineOk<MatchState>).value,
    );
    session._flag = record.flag;
    if (record.engineVersion != kEngineVersion ||
        record.contractVersion != kMatchContractVersion ||
        record.config != config.fingerprint) {
      await session._raise(MatchFlag.unknownVersion);
      return session;
    }
    await session.refresh();
    return session;
  }

  String get matchId => record.matchId;
  MatchState get state => _state;
  int get movesApplied => _applied;
  MatchFlag? get flag => _flag;
  bool get isOver => _state.outcome != null || record.forfeitWinner != null;
  bool get isMyTurn => _flag == null && !isOver && _state.activePlayer == slot;

  /// Server time of the last move; the slow-play limit runs from here.
  DateTime? get lastMoveAt => _lastMoveAt;
  DateTime? get deadline => _lastMoveAt?.add(roundLimit);

  /// Plays [move] locally and appends it to the shared log. A rejected
  /// swap changes nothing and is not sent.
  Future<MoveResult> play(Move move) async {
    if (!isMyTurn) {
      throw const MatchException(MatchErrorCode.notYourTurn);
    }
    final result = applyMove(_state, move);
    if (result is! EngineOk<MoveResult>) {
      throw const OnlineException(OnlineErrorCode.backend, 'invalid_move');
    }
    final res = result.value;
    if (_isRejected(res)) return res;
    final index = _applied;
    try {
      await store.appendMove(
        matchId,
        MoveRecord(
          index: index,
          uid: uid,
          slot: slot,
          move: move.toJson(),
          hashAfter: res.hashAfter,
          next: _nextOf(res.state),
        ),
      );
    } on MatchException catch (e) {
      if (e.code == MatchErrorCode.moveConflict) await refresh();
      rethrow;
    }
    // [watch] may already have accepted this move from the store.
    if (_applied == index) {
      _state = res.state;
      _applied++;
      // Local estimate until [refresh] reads the server time.
      _lastMoveAt = DateTime.now().toUtc();
    }
    await _maybeFinish();
    return res;
  }

  /// Reads the log and applies moves this phone has not seen. Returns how
  /// many were applied. Safe to call from a polling timer.
  Future<int> refresh() async {
    final before = _applied;
    for (final move in await store.readMoves(matchId)) {
      if (move.index < _applied) {
        _lastMoveAt = move.at ?? _lastMoveAt;
        continue;
      }
      if (!await _accept(move)) break;
    }
    record = await store.readMatch(matchId) ?? record;
    _flag ??= record.flag;
    await _maybeFinish();
    await _checkFinals();
    return _applied - before;
  }

  /// Live updates: each accepted opponent move, in order.
  Stream<MoveRecord> watch() async* {
    await for (final move in store.watchMoves(matchId, from: _applied)) {
      if (move.index < _applied) continue;
      if (!await _accept(move)) return;
      if (move.slot != slot) yield move;
    }
  }

  /// Polls [refresh] every [every]; the Spark-safe your-turn fallback when
  /// no push function is deployed. Cancel the returned timer when done.
  Timer poll(Duration every, {void Function(int applied)? onChange}) =>
      Timer.periodic(every, (_) async {
        if (_flag != null || record.forfeitWinner != null) return;
        if (record.finals.length == PlayerSlot.values.length) return;
        final n = await refresh();
        if (n > 0) onChange?.call(n);
      });

  /// Claims the win when the opponent let the 24-hour limit pass.
  Future<void> claimForfeit() async {
    if (isMyTurn || isOver) {
      throw const MatchException(MatchErrorCode.notYourTurn);
    }
    await store.claimForfeit(matchId, slot);
    record = await store.readMatch(matchId) ?? record;
  }

  /// Both phones wrote the same result and nobody flagged the match. Only
  /// then may trophies or paws be awarded.
  bool get counts {
    final a = record.finals[PlayerSlot.first];
    final b = record.finals[PlayerSlot.second];
    return _flag == null && a != null && a == b;
  }

  static PlayerSlot? _nextOf(MatchState s) =>
      s.outcome == null ? s.activePlayer : null;

  static bool _isRejected(MoveResult res) =>
      res.hashBefore == res.hashAfter &&
      res.events.length == 1 &&
      res.events.first is SwapRejected;

  Future<bool> _accept(MoveRecord move) async {
    if (_flag != null) return false;
    if (move.index != _applied) return _raise(MatchFlag.badLog);
    // The rules check the sender at write time; it may be anonymized later.
    final sender = move.uid == kDeletedUid
        ? move.slot
        : record.slotOf(move.uid);
    if (sender != move.slot ||
        move.slot != _state.activePlayer ||
        _state.outcome != null) {
      return _raise(MatchFlag.wrongTurn);
    }
    final decoded = Move.fromJson(move.move);
    final result = decoded == null ? null : applyMove(_state, decoded);
    if (result is! EngineOk<MoveResult> || _isRejected(result.value)) {
      return _raise(MatchFlag.invalidMove);
    }
    if (result.value.hashAfter != move.hashAfter) {
      return _raise(MatchFlag.hashMismatch);
    }
    if (move.next != _nextOf(result.value.state)) {
      return _raise(MatchFlag.wrongTurn);
    }
    _state = result.value.state;
    _applied++;
    _lastMoveAt = move.at ?? _lastMoveAt;
    await _maybeFinish();
    return true;
  }

  Future<bool> _raise(MatchFlag reason) async {
    _flag ??= reason;
    await store.flagMatch(matchId, reason);
    return false;
  }

  Future<void> _maybeFinish() async {
    final outcome = _state.outcome;
    if (outcome == null || record.finals.containsKey(slot)) return;
    await store.writeFinal(
      matchId,
      slot,
      MatchFinal(
        first: _state.scores[0],
        second: _state.scores[1],
        hash: stateHash(_state),
        outcome: outcome,
      ),
    );
    record = await store.readMatch(matchId) ?? record;
    await _checkFinals();
  }

  Future<void> _checkFinals() async {
    final a = record.finals[PlayerSlot.first];
    final b = record.finals[PlayerSlot.second];
    if (a != null && b != null && a != b) await _raise(MatchFlag.finalMismatch);
  }
}
