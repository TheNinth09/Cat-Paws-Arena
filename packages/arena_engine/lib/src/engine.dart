/// Engine API: match creation, legal moves, transitions, replay and
/// hashing. Pure Dart — no Flutter, Flame, dart:io, dart:ui, timers,
/// platform channels, network clients, wall-clock reads or ambient
/// randomness.
library;

import 'board.dart';
import 'model.dart';
import 'rng.dart';

export 'model.dart';
export 'rng.dart' show GameRandom;

/// Creates a new match from [seed] and [config].
///
/// Same inputs always produce the same initial state and hash. [seed] may
/// be any 64-bit integer, including zero and negatives; the full value is
/// folded into the generator domain. Validation failures return
/// [EngineFailure] with [EngineErrorCode.invalidConfig] or
/// [EngineErrorCode.unsupportedEngineVersion].
EngineResult<MatchState> newMatch(int seed, MatchConfig config) {
  final configError = _validateConfig(config);
  if (configError != null) return EngineFailure(configError);

  final deal = dealBoard(seed, 1, config);
  MutableBoard copyOf(MutableBoard b) => MutableBoard(
    b.width,
    b.height,
    List<int>.of(b.cells),
    List<int>.of(b.refillState),
  );

  return EngineOk(
    MatchState.create(
      seed: seed,
      config: config,
      round: 1,
      activePlayer: PlayerSlot.first,
      movesRemaining: [config.movesPerRound, config.movesPerRound],
      scores: [0, 0],
      boards: [deal.freeze(), copyOf(deal).freeze()],
      pendingObstacles: const [
        <ObstacleKind>[],
        <ObstacleKind>[],
      ],
      powerCharge: [0, 0],
      rngState: [
        GameRandom(GameRandom.deriveSeed(seed, ['fx', 0])).state,
        GameRandom(GameRandom.deriveSeed(seed, ['fx', 1])).state,
      ],
    ),
  );
}

/// All currently legal moves for [MatchState.activePlayer].
///
/// Does not mutate state or consume randomness. An empty list is valid only
/// when the state cannot accept a move (a finished match).
EngineResult<List<Move>> legalMoves(MatchState state) {
  if (state.isFinished) return const EngineOk(const []);
  final slot = state.activePlayer;
  if (state.movesLeft(slot) <= 0) return const EngineOk(const []);
  final board = MutableBoard.fromState(state.boardOf(slot));
  final pairs = legalSwapPairs(board);
  final w = board.width;
  CellPos pos(int index) => (row: index ~/ w, col: index % w);
  final moves = <Move>[
    for (final (a, b) in pairs)
      SwapMove(firstCell: pos(a), secondCell: pos(b)),
  ];
  if (state.movesLeft(slot) > 0 && state.chargeOf(slot) >= kPowerCost) {
    moves.add(const PowerMove(power: PowerKind.shadowPounce));
    moves.add(const PowerMove(power: PowerKind.laserChase));
    for (var row = 0; row < board.height; row++) {
      moves.add(PowerMove(power: PowerKind.zoomies, targetRow: row));
    }
  }
  return EngineOk(List<Move>.unmodifiable(moves));
}

/// Applies [move] for the active player, returning the new state and the
/// ordered events produced by the transition.
///
/// A well-formed swap that creates no match and involves no special piece
/// is explicitly rejected: the result is [EngineOk] with unchanged state,
/// a single [SwapRejected] event and identical before/after hashes — no
/// turn or randomness is consumed. Structurally invalid input returns
/// [EngineFailure].
EngineResult<MoveResult> applyMove(MatchState state, Move move) {
  if (state.isFinished) {
    return const EngineFailure(
      EngineError(EngineErrorCode.matchFinished, 'match already ended'),
    );
  }
  final slot = state.activePlayer;
  final hashBefore = stateHash(state);

  switch (move) {
    case SwapMove():
      return _applySwap(state, move, slot, hashBefore);
    case PowerMove():
      return _applyPower(state, move, slot, hashBefore);
  }
}

EngineResult<MoveResult> _applySwap(
  MatchState state,
  SwapMove move,
  PlayerSlot slot,
  String hashBefore,
) {
  final boardState = state.boardOf(slot);
  final w = boardState.width;
  final h = boardState.height;
  bool validPos(CellPos p) => p.row >= 0 && p.row < h && p.col >= 0 && p.col < w;
  if (!validPos(move.firstCell) || !validPos(move.secondCell)) {
    return _invalidMove('swap cell out of bounds');
  }
  final a = move.firstCell.row * w + move.firstCell.col;
  final b = move.secondCell.row * w + move.secondCell.col;
  if (a == b) return _invalidMove('swap cells must differ');

  final work = _Work.fromState(state);
  final board = work.boards[slot.index];
  if (!board.adjacent(a, b)) return _invalidMove('swap cells not adjacent');
  if (!swappablePair(board, a, b)) {
    return _invalidMove('swap involves a blocked or locked cell');
  }

  final ca = board.cells[a];
  final cb = board.cells[b];
  final involvesSpecial = isSpecialCode(ca) || isSpecialCode(cb);

  // Simulate the swap to test productivity.
  board.cells[a] = cb;
  board.cells[b] = ca;
  final productive = involvesSpecial || scanMatches(board).isNotEmpty;
  if (!productive) {
    board.cells[a] = ca;
    board.cells[b] = cb;
    final first = a < b ? a : b;
    final second = a < b ? b : a;
    return EngineOk(
      MoveResult(
        state: state,
        events: [
          SwapRejected(
            player: slot,
            firstCell: _posOf(w, first),
            secondCell: _posOf(w, second),
            reason: 'no-match',
          ),
        ],
        hashBefore: hashBefore,
        hashAfter: hashBefore,
      ),
    );
  }

  // Accepted: emit Swapped in canonical (index-ordered) cell order.
  final first = a < b ? a : b;
  final second = a < b ? b : a;
  work.events.add(
    Swapped(
      player: slot,
      firstCell: _posOf(w, first),
      secondCell: _posOf(w, second),
    ),
  );
  work.movesRemaining[slot.index]--;

  _fireSwapSpecials(work, slot, first, second);
  _resolveMatches(work, slot);
  _finishTurn(work, state);

  final newState = work.freeze();
  final events = List<GameEvent>.of(work.events);
  if (newState.isFinished) {
    events.add(
      MatchEnded(
        outcome: newState.outcome!,
        scores: newState.scorePair,
        finalHashes: (
          first: playerHash(newState, PlayerSlot.first),
          second: playerHash(newState, PlayerSlot.second),
        ),
      ),
    );
  }
  return EngineOk(
    MoveResult(
      state: newState,
      events: List<GameEvent>.unmodifiable(events),
      hashBefore: hashBefore,
      hashAfter: stateHash(newState),
    ),
  );
}

EngineResult<MoveResult> _applyPower(
  MatchState state,
  PowerMove move,
  PlayerSlot slot,
  String hashBefore,
) {
  // Powers are enabled by the full ruleset; the core slice exposes swaps only.
  return _invalidMove('power moves are not enabled by this engine version');
}

/// Mutable working copy of a [MatchState] for one transition.
class _Work {
  final int seed;
  final MatchConfig config;
  int round;
  PlayerSlot activePlayer;
  final List<int> movesRemaining;
  final List<int> scores;
  final List<MutableBoard> boards;
  final List<List<ObstacleKind>> pending;
  final List<int> powerCharge;
  final List<int> rngState;
  MatchOutcome? outcome;
  final List<GameEvent> events = <GameEvent>[];

  _Work._({
    required this.seed,
    required this.config,
    required this.round,
    required this.activePlayer,
    required this.movesRemaining,
    required this.scores,
    required this.boards,
    required this.pending,
    required this.powerCharge,
    required this.rngState,
    required this.outcome,
  });

  factory _Work.fromState(MatchState s) => _Work._(
    seed: s.seed,
    config: s.config,
    round: s.round,
    activePlayer: s.activePlayer,
    movesRemaining: List<int>.of(s.movesRemaining),
    scores: List<int>.of(s.scores),
    boards: [for (final b in s.boards) MutableBoard.fromState(b)],
    pending: [for (final q in s.pendingObstacles) List<ObstacleKind>.of(q)],
    powerCharge: List<int>.of(s.powerCharge),
    rngState: List<int>.of(s.rngState),
    outcome: s.outcome,
  );

  GameRandom rngFor(PlayerSlot p) => GameRandom.fromState(rngState[p.index]);

  void storeRng(PlayerSlot p, GameRandom rng) {
    rngState[p.index] = rng.state;
  }

  ScorePair scorePairSnapshot() => (
    first: scores[PlayerSlot.first.index],
    second: scores[PlayerSlot.second.index],
  );

  MatchState freeze() => MatchState.create(
    seed: seed,
    config: config,
    round: round,
    activePlayer: activePlayer,
    movesRemaining: movesRemaining,
    scores: scores,
    boards: [for (final b in boards) b.freeze()],
    pendingObstacles: pending,
    powerCharge: powerCharge,
    rngState: rngState,
    outcome: outcome,
  );
}

CellPos _posOf(int w, int index) => (row: index ~/ w, col: index % w);

List<CellPos> _posList(int w, List<int> indices) {
  final sorted = List<int>.of(indices)..sort();
  return [for (final i in sorted) _posOf(w, i)];
}

EngineFailure<MoveResult> _invalidMove(String message) => EngineFailure(
  EngineError(EngineErrorCode.invalidMove, message),
);

EngineError? _validateConfig(MatchConfig config) {
  if (config.engineVersion != kEngineVersion) {
    return const EngineError(
      EngineErrorCode.unsupportedEngineVersion,
      'engineVersion does not match this engine',
    );
  }
  if (config.boardWidth < 3 ||
      config.boardHeight < 3 ||
      config.colourCount < 5 ||
      config.colourCount > 6 ||
      config.rounds < 1 ||
      config.movesPerRound < 1) {
    return const EngineError(
      EngineErrorCode.invalidConfig,
      'config violates engine constraints',
    );
  }
  return null;
}

/// Fires any special pieces sitting on the two swapped cells, in ascending
/// cell order. Specials consumed by an earlier effect do not fire.
/// Core slice: boards never contain specials, so this is a no-op until the
/// full ruleset lands.
void _fireSwapSpecials(_Work work, PlayerSlot slot, int first, int second) {
  // Intentionally empty in the core slice.
}

/// Resolves colour matches on [slot]'s board until stable: clears, gravity,
/// refill, repeat. Emits [Cleared], [ObstacleBroken], [Fell] and
/// [Refilled] events and updates score.
void _resolveMatches(_Work work, PlayerSlot slot) {
  final board = work.boards[slot.index];
  final w = board.width;
  final h = board.height;

  while (true) {
    final groups = scanMatches(board);
    if (groups.isEmpty) break;

    final matched = <int>{};
    for (final g in groups) {
      matched.addAll(g.cells);
    }
    final sorted = matched.toList()..sort();
    final points = sorted.length * kPointsPerPiece;
    work.events.add(
      Cleared(player: slot, cells: _posList(w, sorted), points: points),
    );
    work.scores[slot.index] += points;

    final broken = <int>{};
    for (final i in sorted) {
      if (isYarnedCode(board.cells[i])) broken.add(i);
      board.cells[i] = kCellEmpty;
    }
    // Boxes adjacent to any cleared cell break.
    for (final i in sorted) {
      final r = i ~/ w, c = i % w;
      const deltas = [(0, -1), (0, 1), (-1, 0), (1, 0)];
      for (final (dr, dc) in deltas) {
        final nr = r + dr, nc = c + dc;
        if (nr < 0 || nr >= h || nc < 0 || nc >= w) continue;
        final j = nr * w + nc;
        if (board.cells[j] == kCellBox) {
          board.cells[j] = kCellEmpty;
          broken.add(j);
        }
      }
    }
    if (broken.isNotEmpty) {
      work.events.add(
        ObstacleBroken(player: slot, cells: _posList(w, broken.toList())),
      );
    }

    applyGravityAndRefill(
      board: board,
      colourCount: work.config.colourCount,
      player: slot,
      events: work.events,
    );
  }
}

/// After a move resolves: guarantee a legal move (reshuffle if needed),
/// then advance the turn or close the round/match.
void _finishTurn(_Work work, MatchState prev) {
  final slot = prev.activePlayer;
  final board = work.boards[slot.index];
  if (!hasLegalMove(board)) {
    final rng = work.rngFor(slot);
    reshuffleBoard(
      board: board,
      rng: rng,
      player: slot,
      events: work.events,
    );
    work.storeRng(slot, rng);
  }

  final firstDone = work.movesRemaining[PlayerSlot.first.index] <= 0;
  final secondDone = work.movesRemaining[PlayerSlot.second.index] <= 0;

  if (firstDone && secondDone) {
    _endRound(work);
    return;
  }

  final other = slot.other;
  if (work.movesRemaining[other.index] > 0) {
    work.activePlayer = other;
  }
  // Otherwise the same player continues (the opponent already finished).
}

/// Closes the current round: emits [RoundEnded], deals the next round's
/// boards (or marks the match finished after the last round).
void _endRound(_Work work) {
  final config = work.config;
  final scores = work.scorePairSnapshot();

  if (work.round >= config.rounds) {
    work.outcome =
        work.scores[0] > work.scores[1]
            ? MatchOutcome.firstWins
            : work.scores[1] > work.scores[0]
            ? MatchOutcome.secondWins
            : MatchOutcome.draw;
    work.events.add(
      RoundEnded(round: work.round, scores: scores, outcome: work.outcome),
    );
    return;
  }

  work.events.add(RoundEnded(round: work.round, scores: scores, outcome: null));

  // Next round: fresh identical deals for both players; queued obstacles
  // (none in the core slice) would land here.
  final nextRound = work.round + 1;
  work.round = nextRound;
  for (var p = 0; p < 2; p++) {
    final deal = dealBoard(work.seed, nextRound, config);
    work.boards[p] = MutableBoard(
      deal.width,
      deal.height,
      List<int>.of(deal.cells),
      List<int>.of(deal.refillState),
    );
    work.pending[p].clear();
    work.movesRemaining[p] = config.movesPerRound;
  }
  work.activePlayer = PlayerSlot.first;

  // Fresh deals guarantee a legal move; kept as a safety net for later
  // rulesets that place obstacles on the new boards.
  for (var p = 0; p < 2; p++) {
    final slot = PlayerSlot.values[p];
    final b = work.boards[p];
    if (!hasLegalMove(b)) {
      final rng = work.rngFor(slot);
      reshuffleBoard(
        board: b,
        rng: rng,
        player: slot,
        events: work.events,
        reason: 'round-start-no-move',
      );
      work.storeRng(slot, rng);
    }
  }
}

/// Replays [moves] from `newMatch(seed, config)` in order.
///
/// Returns the final state and hash. A failed step returns
/// [EngineFailure] with [EngineErrorCode.replayDivergence] whose details
/// carry `position` (0-based log index) and `reason`. An empty log is valid
/// and returns the initial state.
EngineResult<ReplayResult> replay(
  int seed,
  MatchConfig config,
  List<Move> moves,
) {
  final start = newMatch(seed, config);
  if (start is EngineFailure<MatchState>) {
    return EngineFailure(start.error);
  }
  var state = (start as EngineOk<MatchState>).value;

  for (var i = 0; i < moves.length; i++) {
    final result = applyMove(state, moves[i]);
    if (result is EngineFailure<MoveResult>) {
      return EngineFailure(
        EngineError(
          EngineErrorCode.replayDivergence,
          'replay failed at move $i: ${result.error.message}',
          {
            'position': i,
            'reason': result.error.code.name,
            'move': moves[i].toJson(),
          },
        ),
      );
    }
    state = (result as EngineOk<MoveResult>).value.state;
    if (state.isFinished && i < moves.length - 1) {
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
      movesApplied: moves.length,
    ),
  );
}

// ---------------------------------------------------------------------------
// Hashing
// ---------------------------------------------------------------------------

const int _hashModulus = GameRandom.modulus;

String _hashPass(String input, int offset) {
  var h = offset % _hashModulus;
  if (h < 0) h += _hashModulus;
  for (final unit in input.codeUnits) {
    // h < 2^31 and unit < 2^16, so the xor stays < 2^31; the multiply by
    // 1000003 (< 2^20) stays < 2^51 — exact on every platform.
    h = ((h ^ unit) * 1000003) % _hashModulus;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

/// Hash algorithm version, documented in the package README. Two
/// independent polynomial passes over the canonical state string produce a
/// 64-bit hex digest. Changing the algorithm or canonical layout is a
/// contract change.
const int kHashVersion = 1;

String _dualHash(String canonical) =>
    _hashPass(canonical, 2166136261) + _hashPass(canonical, 2654435761);

String _boardCanonical(BoardState b) =>
    '${b.width}x${b.height};${b.cells.join(',')};${b.refillState.join(',')}';

String _stateCanonical(MatchState s) => [
  'hv=$kHashVersion',
  'engine=${s.engineVersion}',
  'seed=${s.seed}',
  'config=${s.config.fingerprint}',
  'round=${s.round}',
  'active=${s.activePlayer.name}',
  'moves=${s.movesRemaining.join(',')}',
  'scores=${s.scores.join(',')}',
  'charge=${s.powerCharge.join(',')}',
  'rng=${s.rngState.join(',')}',
  'pending=${s.pendingObstacles.map((q) => q.map((k) => k.name).join('+')).join('|')}',
  'outcome=${s.outcome?.name ?? '-'}',
  'boards=${s.boards.map(_boardCanonical).join('|')}',
].join(';');

/// Deterministic hash of the full [MatchState]. Depends only on canonical
/// state — never on object identity, map order, locale or floats.
String stateHash(MatchState state) => _dualHash(_stateCanonical(state));

/// Deterministic per-player hash covering everything needed to verify one
/// side of the duel: seed, config, slot, that player's board, score,
/// charge, RNG state, pending obstacles and remaining moves.
String playerHash(MatchState state, PlayerSlot player) {
  final i = player.index;
  final canonical = [
    'hv=$kHashVersion',
    'engine=${state.engineVersion}',
    'seed=${state.seed}',
    'config=${state.config.fingerprint}',
    'player=${player.name}',
    'round=${state.round}',
    'moves=${state.movesRemaining[i]}',
    'score=${state.scores[i]}',
    'charge=${state.powerCharge[i]}',
    'rng=${state.rngState[i]}',
    'pending=${state.pendingObstacles[i].map((k) => k.name).join('+')}',
    'outcome=${state.outcome?.name ?? '-'}',
    'board=${_boardCanonical(state.boards[i])}',
  ].join(';');
  return _dualHash(canonical);
}
