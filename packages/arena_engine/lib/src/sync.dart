/// Online 1v1 sync helpers: serializable move-log entries, validated
/// replay, sync hashes and per-round log summaries.
///
/// These are the pure-Dart primitives the match-sync layer (friend-duel
/// move documents, hash comparison, match records) builds on. Nothing
/// here performs I/O, reads walls clocks or touches platform APIs —
/// callers own transport and storage.
library;

import 'engine.dart';

/// The three digests a client reports for a match state: the whole-state
/// hash plus the two per-player hashes. Match-end agreement compares
/// these across both clients.
typedef SyncHashes = ({String state, String first, String second});

/// Computes all sync hashes for [state] in one call.
SyncHashes syncHashes(MatchState state) => (
  state: stateHash(state),
  first: playerHash(state, PlayerSlot.first),
  second: playerHash(state, PlayerSlot.second),
);

/// Hashes of the initial state produced by `newMatch(seed, config)`.
///
/// Friend-duel clients exchange these when a match is created so both
/// sides prove they computed the same seed/config deal before the first
/// move. Propagates the [newMatch] validation failure unchanged.
EngineResult<SyncHashes> initialSyncHashes(int seed, MatchConfig config) {
  final res = newMatch(seed, config);
  if (res is EngineFailure<MatchState>) return EngineFailure(res.error);
  return EngineOk(syncHashes((res as EngineOk<MatchState>).value));
}

/// Whether [move] is currently legal for [MatchState.activePlayer].
///
/// Membership check against [legalMoves] (which never mutates state or
/// consumes randomness). Note a well-formed but non-productive swap is
/// NOT in the legal set even though [applyMove] accepts it with a
/// [SwapRejected] event — use [applyMove] when the distinction matters.
EngineResult<bool> isLegalMove(MatchState state, Move move) {
  final legal = legalMoves(state);
  if (legal is EngineFailure<List<Move>>) return EngineFailure(legal.error);
  return EngineOk((legal as EngineOk<List<Move>>).value.contains(move));
}

/// One entry of the shared accepted-move log used by online friend
/// duels.
///
/// [index] is the 0-based position in the shared interleaved log — both
/// players' accepted moves in acceptance order, so the sequence is
/// contiguous `0..n-1`. Transport layers may store additional context
/// (slot, round, document id) alongside; the engine only needs [index],
/// [move] and the optional expected [hashAfter].
///
/// [hashAfter] is the post-move state hash the writer computed (see
/// [MoveResult.hashAfter]). When present, [replayEntries] and
/// [summarizeLog] verify it step by step, which is how clients detect
/// hash divergence instead of trusting a claimed final hash.
class MoveLogEntry {
  final int index;
  final Move move;
  final String? hashAfter;

  const MoveLogEntry({
    required this.index,
    required this.move,
    this.hashAfter,
  });

  /// Stable JSON encoding for move documents and saved logs. Field
  /// order is fixed; [Move.toJson] supplies the move payload.
  Map<String, Object?> toJson() => {
    'index': index,
    'move': move.toJson(),
    if (hashAfter != null) 'hashAfter': hashAfter,
  };

  /// Decodes an entry produced by [toJson]. Returns `null` on malformed
  /// input (non-map, missing/invalid index, undecodable move, wrong
  /// hashAfter type) so callers can flag corrupt log data.
  static MoveLogEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final index = json['index'];
    if (index is! int || index < 0) return null;
    final move = Move.fromJson(json['move']);
    if (move == null) return null;
    final hashAfter = json['hashAfter'];
    if (hashAfter != null && hashAfter is! String) return null;
    return MoveLogEntry(
      index: index,
      move: move,
      hashAfter: hashAfter as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MoveLogEntry &&
      other.index == index &&
      other.move == move &&
      other.hashAfter == hashAfter;

  @override
  int get hashCode => Object.hash(index, move, hashAfter);
}

/// A swap attempt that produced no match and involved no special piece.
/// Recorded separately from accepted moves in [LogSummary]; it never
/// consumed a turn or randomness.
class RejectedAttempt {
  final Move move;
  final String reason;

  const RejectedAttempt({required this.move, required this.reason});
}

/// One round's moves, split by player and by accepted/rejected.
class RoundMoveLog {
  /// Round number, `1..config.rounds`.
  final int round;

  /// Accepted moves played by [PlayerSlot.first] during [round].
  final List<Move> firstAccepted;

  /// Accepted moves played by [PlayerSlot.second] during [round].
  final List<Move> secondAccepted;

  /// Non-productive swap attempts by [PlayerSlot.first].
  final List<RejectedAttempt> firstRejected;

  /// Non-productive swap attempts by [PlayerSlot.second].
  final List<RejectedAttempt> secondRejected;

  RoundMoveLog._(this.round)
    : firstAccepted = [],
      secondAccepted = [],
      firstRejected = [],
      secondRejected = [];
}

/// Outcome of [summarizeLog]: the move log reorganized into per-round,
/// per-player buckets plus the final state hashes — the shape match
/// records need (contract §4: per-round move logs for both players with
/// accepted/rejected attempts distinguished).
class LogSummary {
  /// One entry per round that received at least one log entry, in order.
  final List<RoundMoveLog> rounds;

  /// Final match outcome, or `null` if the log ends mid-match.
  final MatchOutcome? outcome;

  /// Hash of the final state.
  final String stateHash;

  /// Per-player final hashes.
  final HashPair playerHashes;

  const LogSummary({
    required this.rounds,
    required this.outcome,
    required this.stateHash,
    required this.playerHashes,
  });
}

/// Replays [entries] — the shared accepted-move log — from
/// `newMatch(seed, config)` in order, with integrity checks the plain
/// [replay] cannot perform because it only sees bare moves:
///
/// * `entry.index` must equal its 0-based position — gaps, duplicates
///   and out-of-order entries are rejected (`index-not-contiguous`).
/// * Each [MoveLogEntry.hashAfter], when present, must equal the hash
///   the engine recomputes after that step (`hash-mismatch`) — clients
///   verify every claimed hash instead of trusting the final one.
/// * Turn order, coordinates and move validity are enforced by
///   [applyMove]; extra entries after match end are rejected.
///
/// Failures return [EngineErrorCode.replayDivergence] with `position`,
/// `reason` and the offending move/index in details.
EngineResult<ReplayResult> replayEntries(
  int seed,
  MatchConfig config,
  List<MoveLogEntry> entries,
) {
  final start = newMatch(seed, config);
  if (start is EngineFailure<MatchState>) return EngineFailure(start.error);
  var state = (start as EngineOk<MatchState>).value;

  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    if (entry.index != i) {
      return EngineFailure(
        EngineError(
          EngineErrorCode.replayDivergence,
          'move log entry index ${entry.index} at position $i is not contiguous',
          {
            'position': i,
            'reason': 'index-not-contiguous',
            'index': entry.index,
          },
        ),
      );
    }
    final applied = _applyEntry(state, entry, i);
    if (applied is EngineFailure<_Step>) return EngineFailure(applied.error);
    final step = (applied as EngineOk<_Step>).value;
    state = step.state;
    if (state.isFinished && i < entries.length - 1) {
      return EngineFailure(
        EngineError(
          EngineErrorCode.replayDivergence,
          'replay has moves after match end at position $i',
          {'position': i, 'reason': 'moves-after-finish'},
        ),
      );
    }
  }

  return EngineOk(
    ReplayResult(
      state: state,
      hash: stateHash(state),
      movesApplied: entries.length,
    ),
  );
}

/// Replays [entries] like [replayEntries] but additionally buckets every
/// entry into its round and player, separating accepted moves from
/// non-productive swap attempts — the per-round move logs a saved match
/// record stores.
///
/// Entries are attributed to the round and player that were active
/// *before* the move applied, so a round-ending move still counts toward
/// the round that produced it and extra moves stay with their player.
EngineResult<LogSummary> summarizeLog(
  int seed,
  MatchConfig config,
  List<MoveLogEntry> entries,
) {
  final start = newMatch(seed, config);
  if (start is EngineFailure<MatchState>) return EngineFailure(start.error);
  var state = (start as EngineOk<MatchState>).value;

  final byRound = <int, RoundMoveLog>{};
  RoundMoveLog bucketFor(int round) =>
      byRound.putIfAbsent(round, () => RoundMoveLog._(round));

  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    if (entry.index != i) {
      return EngineFailure(
        EngineError(
          EngineErrorCode.replayDivergence,
          'move log entry index ${entry.index} at position $i is not contiguous',
          {
            'position': i,
            'reason': 'index-not-contiguous',
            'index': entry.index,
          },
        ),
      );
    }
    final round = state.round;
    final player = state.activePlayer;
    final applied = _applyEntry(state, entry, i);
    if (applied is EngineFailure<_Step>) return EngineFailure(applied.error);
    final step = (applied as EngineOk<_Step>).value;
    state = step.state;

    final bucket = bucketFor(round);
    final isFirst = player == PlayerSlot.first;
    if (step.rejectedReason != null) {
      final attempt = RejectedAttempt(
        move: entry.move,
        reason: step.rejectedReason!,
      );
      (isFirst ? bucket.firstRejected : bucket.secondRejected).add(attempt);
    } else {
      (isFirst ? bucket.firstAccepted : bucket.secondAccepted).add(entry.move);
    }

    if (state.isFinished && i < entries.length - 1) {
      return EngineFailure(
        EngineError(
          EngineErrorCode.replayDivergence,
          'replay has moves after match end at position $i',
          {'position': i, 'reason': 'moves-after-finish'},
        ),
      );
    }
  }

  final rounds = byRound.values.toList()
    ..sort((a, b) => a.round.compareTo(b.round));
  return EngineOk(
    LogSummary(
      rounds: List.unmodifiable(rounds),
      outcome: state.outcome,
      stateHash: stateHash(state),
      playerHashes: (
        first: playerHash(state, PlayerSlot.first),
        second: playerHash(state, PlayerSlot.second),
      ),
    ),
  );
}

/// Internal per-step result shared by [replayEntries] and [summarizeLog]:
/// the new state plus the rejection reason when the entry was a
/// non-productive swap.
class _Step {
  final MatchState state;
  final String? rejectedReason;
  const _Step(this.state, this.rejectedReason);
}

EngineResult<_Step> _applyEntry(
  MatchState state,
  MoveLogEntry entry,
  int position,
) {
  final res = applyMove(state, entry.move);
  if (res is EngineFailure<MoveResult>) {
    return EngineFailure(
      EngineError(
        EngineErrorCode.replayDivergence,
        'replay failed at move $position: ${res.error.message}',
        {
          'position': position,
          'reason': res.error.code.name,
          'move': entry.move.toJson(),
        },
      ),
    );
  }
  final ok = (res as EngineOk<MoveResult>).value;
  if (entry.hashAfter != null && entry.hashAfter != ok.hashAfter) {
    return EngineFailure(
      EngineError(
        EngineErrorCode.replayDivergence,
        'state hash mismatch after move $position',
        {
          'position': position,
          'reason': 'hash-mismatch',
          'expected': entry.hashAfter,
          'actual': ok.hashAfter,
        },
      ),
    );
  }
  String? rejected;
  if (ok.events.length == 1 && ok.events.single is SwapRejected) {
    rejected = (ok.events.single as SwapRejected).reason;
  }
  return EngineOk(_Step(ok.state, rejected));
}
