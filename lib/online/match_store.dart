/// Friend-match records shared by both phones (docs/contract.md §3–4).
/// A match is a seed plus an ordered move log; each phone replays the
/// other's moves with `arena_engine` and compares hashes.
library;

import 'package:arena_engine/arena_engine.dart';

/// Bumped only with an announced contract change.
const kMatchContractVersion = 1;

/// The UID `onUserDeleted` writes in place of a deleted player's.
const kDeletedUid = 'deleted';

/// Slow play: a player who does not move for this long (server time, from
/// the last move) forfeits.
const roundLimit = Duration(hours: 24);

/// Live play: suggested per-move timer shown by the duel screen.
const liveMoveLimit = Duration(seconds: 30);

/// Match-sync errors. Separate from `OnlineErrorCode` so screens that
/// switch over that enum stay exhaustive.
enum MatchErrorCode {
  /// A move with this index is already in the log; reload and replay.
  moveConflict,

  /// It is the other player's turn, or the match is over.
  notYourTurn,

  /// The 24-hour limit has not passed yet.
  deadlineNotPassed,
}

class MatchException implements Exception {
  const MatchException(this.code);
  final MatchErrorCode code;

  @override
  String toString() => 'MatchException(${code.name})';
}

/// Why a match was flagged. A flagged match awards nothing.
enum MatchFlag {
  hashMismatch('hash_mismatch'),
  invalidMove('invalid_move'),
  wrongTurn('wrong_turn'),
  badLog('bad_log'),
  unknownVersion('unknown_version'),
  finalMismatch('final_mismatch');

  const MatchFlag(this.wire);
  final String wire;

  static MatchFlag? fromWire(Object? value) {
    for (final f in values) {
      if (f.wire == value) return f;
    }
    return null;
  }
}

/// One player's claimed result after the last move.
class MatchFinal {
  const MatchFinal({
    required this.first,
    required this.second,
    required this.hash,
    required this.outcome,
  });
  final int first, second;
  final String hash;
  final MatchOutcome outcome;

  Map<String, Object?> toJson() => {
    'first': first,
    'second': second,
    'hash': hash,
    'outcome': outcome.name,
  };

  static MatchFinal? fromJson(Object? json) {
    if (json is! Map) return null;
    final first = json['first'], second = json['second'], hash = json['hash'];
    final outcome = MatchOutcome.values.asNameMap()[json['outcome']];
    if (first is! int || second is! int || hash is! String || outcome == null) {
      return null;
    }
    return MatchFinal(
      first: first,
      second: second,
      hash: hash,
      outcome: outcome,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MatchFinal &&
      other.first == first &&
      other.second == second &&
      other.hash == hash &&
      other.outcome == outcome;

  @override
  int get hashCode => Object.hash(first, second, hash, outcome);
}

class MatchRecord {
  const MatchRecord({
    required this.matchId,
    required this.roomCode,
    required this.hostUid,
    required this.guestUid,
    required this.seed,
    required this.config,
    required this.engineVersion,
    required this.contractVersion,
    this.finals = const {},
    this.flag,
    this.forfeitWinner,
  });

  final String matchId, roomCode, hostUid, guestUid;
  final int seed;

  /// `MatchConfig.fingerprint`; only the agreed duel is accepted.
  final String config;
  final int engineVersion, contractVersion;
  final Map<PlayerSlot, MatchFinal> finals;
  final MatchFlag? flag;

  /// Set when a player claimed the win after the 24-hour round limit.
  final PlayerSlot? forfeitWinner;

  /// The host plays [PlayerSlot.first], the guest [PlayerSlot.second].
  PlayerSlot? slotOf(String uid) => uid == hostUid
      ? PlayerSlot.first
      : uid == guestUid
      ? PlayerSlot.second
      : null;
}

/// One accepted move in the shared log.
class MoveRecord {
  const MoveRecord({
    required this.index,
    required this.uid,
    required this.slot,
    required this.move,
    required this.hashAfter,
    required this.next,
    this.at,
  });
  final int index;
  final String uid;
  final PlayerSlot slot;

  /// `Move.toJson()`; decoded with `Move.fromJson` before replay.
  final Map<String, Object?> move;

  /// `stateHash` after the move, as the sender computed it.
  final String hashAfter;

  /// Who moves next after this move (null: the match is over). The rules
  /// use it for the forfeit check; each phone verifies it on replay.
  final PlayerSlot? next;

  /// Server time of the write; null until the server stamps it.
  final DateTime? at;
}

abstract interface class MatchStore {
  Future<MatchRecord?> readMatch(String matchId);
  Stream<MatchRecord> watchMatch(String matchId);
  Future<List<MoveRecord>> readMoves(String matchId);

  /// Moves with `index >= from`, in order, including later ones.
  Stream<MoveRecord> watchMoves(String matchId, {int from = 0});

  /// Create-only; throws `MatchErrorCode.moveConflict` if [move.index]
  /// already exists.
  Future<void> appendMove(String matchId, MoveRecord move);
  Future<void> writeFinal(String matchId, PlayerSlot slot, MatchFinal result);

  /// Sets the flag once; later flags are ignored.
  Future<void> flagMatch(String matchId, MatchFlag reason);

  /// Records a forfeit win for [winner]; the rules require the last move to
  /// hand the turn to the loser at least [roundLimit] ago.
  Future<void> claimForfeit(String matchId, PlayerSlot winner);
}
