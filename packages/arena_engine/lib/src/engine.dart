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
/// when the state cannot accept a move (a finished match or a player with
/// no moves left).
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
  final charge = state.chargeOf(slot);
  if (charge >= powerChargeCost(PowerKind.zoomies)) {
    for (var row = 0; row < board.height; row++) {
      moves.add(PowerMove(power: PowerKind.zoomies, targetRow: row));
    }
  }
  if (charge >= powerChargeCost(PowerKind.shadowPounce)) {
    moves.add(const PowerMove(power: PowerKind.shadowPounce));
  }
  if (charge >= powerChargeCost(PowerKind.laserChase)) {
    moves.add(const PowerMove(power: PowerKind.laserChase));
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

  return _result(work, hashBefore);
}

EngineResult<MoveResult> _applyPower(
  MatchState state,
  PowerMove move,
  PlayerSlot slot,
  String hashBefore,
) {
  final cost = powerChargeCost(move.power);
  if (state.chargeOf(slot) < cost) {
    return EngineFailure(
      EngineError(
        EngineErrorCode.insufficientCharge,
        'power charge below cost',
      ),
    );
  }
  if (state.movesLeft(slot) <= 0) {
    return _invalidMove('no moves remaining this round');
  }
  final h = state.boardOf(slot).height;
  if (move.power == PowerKind.zoomies) {
    final row = move.targetRow;
    if (row == null || row < 0 || row >= h) {
      return _invalidMove('zoomies requires a target row in bounds');
    }
  } else if (move.targetRow != null) {
    return _invalidMove('this power takes no target row');
  }

  final work = _Work.fromState(state);
  final board = work.boards[slot.index];
  work.movesRemaining[slot.index]--;
  work.powerCharge[slot.index] -= cost;
  work.events.add(
    PowerCharged(player: slot, amount: -cost),
  );

  final rng = work.rngFor(slot);
  switch (move.power) {
    case PowerKind.zoomies:
      _powerZoomies(work, slot, move.targetRow!, rng);
    case PowerKind.shadowPounce:
      _powerShadowPounce(work, slot);
    case PowerKind.laserChase:
      _powerLaserChase(work, slot, rng);
  }
  work.storeRng(slot, rng);

  applyGravityAndRefill(
    board: board,
    colourCount: work.config.colourCount,
    player: slot,
    events: work.events,
  );
  _resolveMatches(work, slot);
  _finishTurn(work, state);

  return _result(work, hashBefore);
}

EngineResult<MoveResult> _result(_Work work, String hashBefore) {
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

// ---------------------------------------------------------------------------
// Clearing helpers
// ---------------------------------------------------------------------------

/// Removes [cells] from [slot]'s board: sets them empty, breaks boxes
/// orthogonally adjacent to any removed cell (unless [breakBoxes] is false)
/// and consumes yarn locks on removed pieces. Emits one [ObstacleBroken]
/// event when anything was consumed. Returns the consumed obstacle cells.
Set<int> _removePieceCells(
  _Work work,
  PlayerSlot slot,
  Set<int> cells, {
  bool breakBoxes = true,
}) {
  final board = work.boards[slot.index];
  final w = board.width;
  final h = board.height;
  final broken = <int>{};
  for (final i in cells) {
    if (isYarnedCode(board.cells[i])) broken.add(i);
    board.cells[i] = kCellEmpty;
  }
  if (breakBoxes) {
    for (final i in cells) {
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
  }
  if (broken.isNotEmpty) {
    work.events.add(
      ObstacleBroken(player: slot, cells: _posList(w, broken.toList())),
    );
  }
  return broken;
}

/// Adds [pieces] worth of charge to [slot], capped at [kPowerCost], and
/// emits [PowerCharged] with the actual positive delta.
void _addCharge(_Work work, PlayerSlot slot, int pieces) {
  if (pieces <= 0) return;
  final gain = pieces * kChargePerPiece;
  final before = work.powerCharge[slot.index];
  final after = before + gain > kPowerCost ? kPowerCost : before + gain;
  final delta = after - before;
  if (delta <= 0) return;
  work.powerCharge[slot.index] = after;
  work.events.add(PowerCharged(player: slot, amount: delta));
}

/// Awards score for [pieces] cleared by [slot].
void _addScore(_Work work, PlayerSlot slot, int pieces) {
  work.scores[slot.index] += pieces * kPointsPerPiece;
}

// ---------------------------------------------------------------------------
// Special pieces
// ---------------------------------------------------------------------------

/// The cell a bomb is created on inside a bent [group]: the lowest-index
/// cell that has a matched neighbour on both axes. Falls back to the
/// group's first cell (unreachable for real bent groups).
int _bombAnchor(MatchGroup group, MutableBoard board) {
  final w = board.width;
  final inGroup = group.cells.toSet();
  for (final i in group.cells) {
    final r = i ~/ w, c = i % w;
    bool member(int rr, int cc) =>
        rr >= 0 &&
        rr < board.height &&
        cc >= 0 &&
        cc < w &&
        inGroup.contains(rr * w + cc);
    final hasH = member(r, c - 1) || member(r, c + 1);
    final hasV = member(r - 1, c) || member(r + 1, c);
    if (hasH && hasV) return i;
  }
  return group.cells.first;
}

/// Computes the cells a special piece at [index] would clear, reading
/// [scratch] (a working copy of the board where earlier effects are already
/// removed). [otherSwap] is the other cell of the activating swap, used by
/// the rainbow to pick its colour.
Set<int> _specialEffectCells({
  required _Work work,
  required PlayerSlot slot,
  required int index,
  required int base,
  required List<int> scratch,
  required int otherSwap,
  required GameRandom rng,
}) {
  final board = work.boards[slot.index];
  final w = board.width;
  final h = board.height;
  final r = index ~/ w, c = index % w;
  final cells = <int>{};

  void collectRow(int rr) {
    for (var cc = 0; cc < w; cc++) {
      final j = rr * w + cc;
      if (isPieceCode(scratch[j])) cells.add(j);
    }
  }

  void collectCol(int cc) {
    for (var rr = 0; rr < h; rr++) {
      final j = rr * w + cc;
      if (isPieceCode(scratch[j])) cells.add(j);
    }
  }

  switch (base) {
    case kLineRow:
      collectRow(r);
    case kLineColumn:
      collectCol(c);
    case kBomb:
      for (var rr = r - 1; rr <= r + 1; rr++) {
        if (rr < 0 || rr >= h) continue;
        for (var cc = c - 1; cc <= c + 1; cc++) {
          if (cc < 0 || cc >= w) continue;
          final j = rr * w + cc;
          if (isPieceCode(scratch[j])) cells.add(j);
        }
      }
    case kRainbow:
      if (work.config.rainbowRule == RainbowRule.clearOneColour) {
        var target = -1;
        if (isColourCode(scratch[otherSwap])) {
          target = basePieceCode(scratch[otherSwap]);
        } else {
          target = rng.nextInt(work.config.colourCount);
        }
        for (var j = 0; j < scratch.length; j++) {
          if (isColourCode(scratch[j]) &&
              basePieceCode(scratch[j]) == target) {
            cells.add(j);
          }
        }
      } else {
        final eligible = <int>[
          for (var j = 0; j < scratch.length; j++)
            if (isPieceCode(scratch[j])) j,
        ];
        final take =
            eligible.length < kRainbowRemoveCount
                ? eligible.length
                : kRainbowRemoveCount;
        // Partial Fisher–Yates for `take` distinct picks.
        for (var k = 0; k < take; k++) {
          final j = k + rng.nextInt(eligible.length - k);
          final t = eligible[k];
          eligible[k] = eligible[j];
          eligible[j] = t;
          cells.add(eligible[k]);
        }
      }
      cells.add(index); // the rainbow piece itself is consumed
    default:
      break;
  }
  return cells;
}

SpecialKind _specialKindOf(int base) => switch (base) {
  kLineRow || kLineColumn => SpecialKind.line,
  kBomb => SpecialKind.bomb,
  kRainbow => SpecialKind.rainbow,
  _ => throw ArgumentError.value(base, 'base', 'not a special code'),
};

/// Fires special pieces on the two swapped cells ([first], [second],
/// ascending). Each special's effect is computed on a scratch copy where
/// earlier effects are already removed, so a special consumed by another
/// special's blast does not fire. All effects resolve before a single
/// gravity+refill step.
void _fireSwapSpecials(_Work work, PlayerSlot slot, int first, int second) {
  final board = work.boards[slot.index];
  final w = board.width;
  final scratch = List<int>.of(board.cells);
  final rng = work.rngFor(slot);

  final fired = <(SpecialKind, Set<int>)>[];
  for (final idx in [first, second]) {
    if (!isSpecialCode(scratch[idx])) continue;
    final base = basePieceCode(scratch[idx]);
    final effect = _specialEffectCells(
      work: work,
      slot: slot,
      index: idx,
      base: base,
      scratch: scratch,
      otherSwap: idx == first ? second : first,
      rng: rng,
    );
    for (final j in effect) {
      scratch[j] = kCellEmpty;
    }
    fired.add((_specialKindOf(base), effect));
  }
  if (fired.isEmpty) {
    work.storeRng(slot, rng);
    return;
  }

  // Commit: write the scratch board back, then emit events in firing order.
  board.cells.setAll(0, scratch);
  final allCleared = <int>{};
  var chargePieces = 0;
  for (final (kind, effect) in fired) {
    final sorted = effect.toList()..sort();
    allCleared.addAll(sorted);
    chargePieces += sorted.length;
    work.events.add(
      SpecialFired(
        player: slot,
        kind: kind,
        cells: _posList(w, sorted),
        points: sorted.length * kPointsPerPiece,
      ),
    );
    _addScore(work, slot, sorted.length);
  }
  _addCharge(work, slot, chargePieces);
  _removePieceCells(work, slot, allCleared);
  applyGravityAndRefill(
    board: board,
    colourCount: work.config.colourCount,
    player: slot,
    events: work.events,
  );
  work.storeRng(slot, rng);
}

/// Resolves colour matches on [slot]'s board until stable. Each wave:
/// detect groups, create specials on qualifying anchors, clear the rest,
/// break adjacent obstacles, award extra moves for matches of 4+, then
/// gravity and refill. Repeats while matches exist.
void _resolveMatches(_Work work, PlayerSlot slot) {
  final board = work.boards[slot.index];
  final w = board.width;

  while (true) {
    final groups = scanMatches(board);
    if (groups.isEmpty) break;

    // Decide special creations: bent -> bomb, straight 5+ -> rainbow,
    // straight 4 -> line (orientation perpendicular to the run).
    final creations = <(int, int, LineOrientation?)>[]; // anchor, code, orient
    final anchors = <int>{};
    for (final g in groups) {
      int anchor;
      int code;
      LineOrientation? orient;
      if (g.isBent) {
        anchor = _bombAnchor(g, board);
        code = kBomb;
      } else if (g.cells.length >= 5) {
        anchor = g.cells.first;
        code = kRainbow;
      } else if (g.cells.length == 4) {
        anchor = g.cells.first;
        // A horizontal run rewards a column clearer and vice versa.
        if (g.isStraightHorizontal) {
          code = kLineColumn;
          orient = LineOrientation.column;
        } else {
          code = kLineRow;
          orient = LineOrientation.row;
        }
      } else {
        continue;
      }
      creations.add((anchor, code, orient));
      anchors.add(anchor);
    }

    final matched = <int>{};
    for (final g in groups) {
      matched.addAll(g.cells);
    }
    matched.removeAll(anchors);
    final sorted = matched.toList()..sort();
    final points = sorted.length * kPointsPerPiece;
    work.events.add(
      Cleared(player: slot, cells: _posList(w, sorted), points: points),
    );
    _addScore(work, slot, sorted.length);

    // Transform anchors into specials in place (yarn lock is preserved).
    creations.sort((a, b) => a.$1.compareTo(b.$1));
    for (final (anchor, code, orient) in creations) {
      final wasYarned = isYarnedCode(board.cells[anchor]);
      board.cells[anchor] = code + (wasYarned ? kYarnOffset : 0);
      work.events.add(
        SpecialCreated(
          player: slot,
          kind: _specialKindOf(code),
          orientation: orient,
          cell: _posOf(w, anchor),
        ),
      );
    }

    // A match of four or more cells in a group awards one extra move,
    // capped at twice movesPerRound so a round cannot become endless.
    final extras = groups.where((g) => g.cells.length >= 4).length;
    if (extras > 0) {
      final cap = work.config.movesPerRound * 2;
      final before = work.movesRemaining[slot.index];
      final after = before + extras > cap ? cap : before + extras;
      if (after > before) {
        work.movesRemaining[slot.index] = after;
        work.events.add(
          ExtraMove(
            player: slot,
            round: work.round,
            movesRemaining: after,
          ),
        );
      }
    }

    _addCharge(work, slot, sorted.length);
    _removePieceCells(work, slot, matched.toSet());
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

/// Closes the current round: emits [RoundEnded], lands queued obstacles on
/// the next round's fresh boards and deals them (or marks the match
/// finished after the last round, discarding unplayed obstacles).
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
    // Obstacles earned in the final round have no next round and are
    // discarded with the pending queues.
    return;
  }

  work.events.add(RoundEnded(round: work.round, scores: scores, outcome: null));

  // Next round: fresh identical deals for both players.
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
    work.movesRemaining[p] = config.movesPerRound;
  }
  work.activePlayer = PlayerSlot.first;

  // Land each player's queued obstacles on their fresh board, then make
  // sure the board still has a legal move.
  for (var p = 0; p < 2; p++) {
    final slot = PlayerSlot.values[p];
    if (work.pending[p].isNotEmpty) {
      _landObstacles(work, slot);
    }
    work.pending[p].clear();
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

/// Places [slot]'s pending obstacles on their fresh round board, in queue
/// order, using [slot]'s RNG stream. Boxes replace a random piece cell;
/// yarn locks a random regular-colour piece. Obstacles that find no
/// eligible cell are discarded.
void _landObstacles(_Work work, PlayerSlot slot) {
  final board = work.boards[slot.index];
  final w = board.width;
  final rng = work.rngFor(slot);
  final placed = <int>[];

  for (final kind in work.pending[slot.index]) {
    if (kind == ObstacleKind.box) {
      final eligible = <int>[
        for (var i = 0; i < board.cells.length; i++)
          if (isPieceCode(board.cells[i])) i,
      ];
      if (eligible.isEmpty) continue;
      final pick = eligible[rng.nextInt(eligible.length)];
      board.cells[pick] = kCellBox;
      placed.add(pick);
    } else {
      final eligible = <int>[
        for (var i = 0; i < board.cells.length; i++)
          if (isColourCode(board.cells[i]) && !isYarnedCode(board.cells[i])) i,
      ];
      if (eligible.isEmpty) continue;
      final pick = eligible[rng.nextInt(eligible.length)];
      board.cells[pick] += kYarnOffset;
      placed.add(pick);
    }
  }
  work.storeRng(slot, rng);

  if (placed.isNotEmpty) {
    work.events.add(
      ObstacleLanded(player: slot, cells: _posList(w, placed)),
    );
  }
}

// ---------------------------------------------------------------------------
// Powers
// ---------------------------------------------------------------------------

/// Queues [count] obstacles of random kind for [receiver], drawn from
/// [sender]'s RNG. Emits [ObstacleQueued] with the number actually queued
/// (the pending queue is capped at [kMaxPendingObstacles]).
void _earnObstacles(
  _Work work,
  PlayerSlot sender,
  PlayerSlot receiver,
  int count,
  GameRandom rng,
) {
  final queue = work.pending[receiver.index];
  var added = 0;
  for (var k = 0; k < count && queue.length < kMaxPendingObstacles; k++) {
    queue.add(ObstacleKind.values[rng.nextInt(ObstacleKind.values.length)]);
    added++;
  }
  if (added > 0) {
    work.events.add(
      ObstacleQueued(
        player: receiver,
        sourceRound: work.round,
        count: added,
      ),
    );
  }
}

/// Clears every piece in [row] of [slot]'s board, then sends
/// [kZoomiesObstacleCount] obstacles to the opponent.
void _powerZoomies(_Work work, PlayerSlot slot, int row, GameRandom rng) {
  final board = work.boards[slot.index];
  final w = board.width;
  final cells = <int>{};
  for (var c = 0; c < w; c++) {
    final i = row * w + c;
    if (isPieceCode(board.cells[i])) cells.add(i);
  }
  final sorted = cells.toList()..sort();
  work.events.add(
    PowerFired(
      player: slot,
      power: PowerKind.zoomies,
      cells: _posList(w, sorted),
      points: sorted.length * kPointsPerPiece,
    ),
  );
  _addScore(work, slot, sorted.length);
  _addCharge(work, slot, sorted.length);
  _removePieceCells(work, slot, cells);
  _earnObstacles(
    work,
    slot,
    slot.other,
    kZoomiesObstacleCount,
    rng,
  );
}

/// Clears every piece of the most common colour on [slot]'s board.
/// Ties resolve to the lowest colour code.
void _powerShadowPounce(_Work work, PlayerSlot slot) {
  final board = work.boards[slot.index];
  final w = board.width;
  final counts = List<int>.filled(kPieceColours, 0);
  for (final code in board.cells) {
    if (isColourCode(code)) counts[basePieceCode(code)]++;
  }
  var target = 0;
  for (var i = 1; i < counts.length; i++) {
    if (counts[i] > counts[target]) target = i;
  }
  final cells = <int>{};
  for (var i = 0; i < board.cells.length; i++) {
    final code = board.cells[i];
    if (isColourCode(code) && basePieceCode(code) == target) cells.add(i);
  }
  final sorted = cells.toList()..sort();
  work.events.add(
    PowerFired(
      player: slot,
      power: PowerKind.shadowPounce,
      cells: _posList(w, sorted),
      points: sorted.length * kPointsPerPiece,
    ),
  );
  _addScore(work, slot, sorted.length);
  _addCharge(work, slot, sorted.length);
  _removePieceCells(work, slot, cells);
}

/// Breaks [kLaserBreakCount] random pieces on [slot]'s board, then clears
/// all of [slot]'s own obstacles (boxes and yarn locks).
void _powerLaserChase(_Work work, PlayerSlot slot, GameRandom rng) {
  final board = work.boards[slot.index];
  final w = board.width;
  final eligible = <int>[
    for (var i = 0; i < board.cells.length; i++)
      if (isPieceCode(board.cells[i])) i,
  ];
  final take =
      eligible.length < kLaserBreakCount ? eligible.length : kLaserBreakCount;
  final broken = <int>{};
  for (var k = 0; k < take; k++) {
    final j = k + rng.nextInt(eligible.length - k);
    final t = eligible[k];
    eligible[k] = eligible[j];
    eligible[j] = t;
    broken.add(eligible[k]);
  }
  final sorted = broken.toList()..sort();
  work.events.add(
    PowerFired(
      player: slot,
      power: PowerKind.laserChase,
      cells: _posList(w, sorted),
      points: sorted.length * kPointsPerPiece,
    ),
  );
  _addScore(work, slot, sorted.length);
  _addCharge(work, slot, sorted.length);
  // No adjacency box-break here: every own obstacle is cleared next, so a
  // single ObstacleBroken reports the full set.
  _removePieceCells(work, slot, broken, breakBoxes: false);

  final obstacleCells = <int>{};
  for (var i = 0; i < board.cells.length; i++) {
    final code = board.cells[i];
    if (code == kCellBox) {
      board.cells[i] = kCellEmpty;
      obstacleCells.add(i);
    } else if (isYarnedCode(code)) {
      board.cells[i] = code - kYarnOffset;
      obstacleCells.add(i);
    }
  }
  if (obstacleCells.isNotEmpty) {
    work.events.add(
      ObstacleBroken(player: slot, cells: _posList(w, obstacleCells.toList())),
    );
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
