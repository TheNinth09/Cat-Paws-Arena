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
      turn: 1,
      activePlayer: PlayerSlot.first,
      turnsRemaining: [
        config.turnsPerPlayer,
        config.turnsPerPlayer,
      ],
      turnMoves: 0,
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
/// Does not mutate state or consume randomness. Always includes
/// [EndTurnMove] — turns end only through it. Swaps are the productive
/// adjacent pairs; a [PowerMove] appears only when the meter is full and
/// names the power the active player's cat brought into the match.
EngineResult<List<Move>> legalMoves(MatchState state) {
  if (state.isFinished) return const EngineOk([]);
  final slot = state.activePlayer;
  final board = MutableBoard.fromState(state.boardOf(slot));
  final pairs = legalSwapPairs(board);
  final w = board.width;
  CellPos pos(int index) => (row: index ~/ w, col: index % w);
  final moves = <Move>[
    for (final (a, b) in pairs)
      SwapMove(firstCell: pos(a), secondCell: pos(b)),
    // Tap detonations: every unlocked special fires via a self-swap.
    for (var i = 0; i < board.cells.length; i++)
      if (isPieceCode(board.cells[i]) &&
          !isYarnedCode(board.cells[i]) &&
          isSpecialCode(board.cells[i]))
        SwapMove(firstCell: pos(i), secondCell: pos(i)),
  ];
  if (state.canFirePower(slot)) {
    moves.add(PowerMove(power: state.config.powerFor(slot)));
  }
  moves.add(const EndTurnMove());
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
    case EndTurnMove():
      return _applyEndTurn(state, slot, hashBefore);
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

  final work = _Work.fromState(state);
  final board = work.boards[slot.index];
  if (a == b) {
    // Tap detonation: tapping a special piece fires it in place.
    if (!isSpecialCode(board.cells[a])) {
      return _invalidMove('swap cells must differ');
    }
    work.turnMoves++;
    _fireSwapSpecials(work, slot, a, a);
    _resolveMatches(work, slot);
    _ensureLegalMove(work, slot);
    return _result(work, hashBefore);
  }
  if (!board.adjacent(a, b)) return _invalidMove('swap cells not adjacent');
  if (!swappablePair(board, a, b)) {
    return _invalidMove('swap involves a blocked or locked cell');
  }

  final ca = board.cells[a];
  final cb = board.cells[b];
  final bothSpecial = isSpecialCode(ca) && isSpecialCode(cb);
  // A special never merges with a plain piece: it fires by tap, by a
  // special+special combo, or — for the rainbow paw — by touching the
  // colour it should clear. Any other special+normal swap is rejected.
  final rainbowOnColour =
      (basePieceCode(ca) == kRainbow && isColourCode(cb)) ||
      (basePieceCode(cb) == kRainbow && isColourCode(ca));
  if (!bothSpecial &&
      !rainbowOnColour &&
      (isSpecialCode(ca) || isSpecialCode(cb))) {
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
            reason: 'special-blocked',
          ),
        ],
        hashBefore: hashBefore,
        hashAfter: hashBefore,
      ),
    );
  }
  final fires = bothSpecial || rainbowOnColour;

  // Simulate the swap to test productivity.
  board.cells[a] = cb;
  board.cells[b] = ca;
  final productive = fires || scanMatches(board).isNotEmpty;
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
  work.turnMoves++;

  if (bothSpecial) {
    _fireCombo(work, slot, first, second);
  } else if (rainbowOnColour) {
    _fireSwapSpecials(work, slot, first, second);
  }
  _resolveMatches(work, slot);
  _ensureLegalMove(work, slot);

  return _result(work, hashBefore);
}

EngineResult<MoveResult> _applyPower(
  MatchState state,
  PowerMove move,
  PlayerSlot slot,
  String hashBefore,
) {
  if (move.power != state.config.powerFor(slot)) {
    return _invalidMove('power is not the one this cat brought');
  }
  if (!state.canFirePower(slot)) {
    return const EngineFailure(
      EngineError(
        EngineErrorCode.insufficientCharge,
        'power meter is not full',
      ),
    );
  }

  final work = _Work.fromState(state);
  final board = work.boards[slot.index];
  work.turnMoves++;
  final spent = work.powerCharge[slot.index];
  work.powerCharge[slot.index] = 0;
  work.events.add(PowerCharged(player: slot, amount: -spent));

  final rng = work.rngFor(slot);
  switch (move.power) {
    case PowerKind.zoomies:
      _powerZoomies(work, slot, rng);
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
  _ensureLegalMove(work, slot);

  return _result(work, hashBefore);
}

/// Ends the active player's turn early: emits [TurnEnded], consumes one
/// turn, hands the turn to the opponent and lands their queued cardboard
/// boxes on their persistent board at the start of their next turn.
/// The match ends when both players have used all their turns — the
/// higher score wins, equal scores draw.
EngineResult<MoveResult> _applyEndTurn(
  MatchState state,
  PlayerSlot slot,
  String hashBefore,
) {
  final work = _Work.fromState(state);
  work.turnMoves = 0;
  work.turnsRemaining[slot.index]--;

  final finished =
      work.turnsRemaining[PlayerSlot.first.index] <= 0 &&
      work.turnsRemaining[PlayerSlot.second.index] <= 0;
  if (finished) {
    work.outcome =
        work.scores[0] > work.scores[1]
            ? MatchOutcome.firstWins
            : work.scores[1] > work.scores[0]
            ? MatchOutcome.secondWins
            : MatchOutcome.draw;
  }

  work.events.add(
    TurnEnded(
      turn: work.turn,
      scores: work.scorePairSnapshot(),
      outcome: work.outcome,
    ),
  );

  if (finished) {
    // Obstacles still queued have no next turn and are discarded.
    return _result(work, hashBefore);
  }

  work.turn++;
  final next = slot.other;
  work.activePlayer = next;

  // Obstacles earned during the turn that just ended land on the
  // opponent's board now, at the start of their next turn.
  if (work.pending[next.index].isNotEmpty) {
    _landObstacles(work, next);
    work.pending[next.index].clear();
  }
  _ensureLegalMove(work, next);

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
  int turn;
  PlayerSlot activePlayer;
  final List<int> turnsRemaining;
  int turnMoves;
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
    required this.turn,
    required this.activePlayer,
    required this.turnsRemaining,
    required this.turnMoves,
    required this.scores,
    required this.boards,
    required this.pending,
    required this.powerCharge,
    required this.rngState,
    required this.outcome,
  });

  factory _Work.fromState(MatchState s) {
    // Shared board: both players act on the same 7×7 board, alternating
    // turns. `newMatch` already seeds identical boards for both slots, so
    // sharing one mutable instance keeps replays deterministic.
    final shared = MutableBoard.fromState(s.boards.first);
    return _Work._(
      seed: s.seed,
      config: s.config,
      turn: s.turn,
      activePlayer: s.activePlayer,
      turnsRemaining: List<int>.of(s.turnsRemaining),
      turnMoves: s.turnMoves,
      scores: List<int>.of(s.scores),
      boards: [shared, shared],
      pending: [for (final q in s.pendingObstacles) List<ObstacleKind>.of(q)],
      powerCharge: List<int>.of(s.powerCharge),
      rngState: List<int>.of(s.rngState),
      outcome: s.outcome,
    );
  }

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
    turn: turn,
    activePlayer: activePlayer,
    turnsRemaining: turnsRemaining,
    turnMoves: turnMoves,
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
      config.turnsPerPlayer < 1 ||
      config.turnSeconds < 1) {
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
    if (isYarnedCode(board.cells[i]) || isBoxCode(board.cells[i])) {
      broken.add(i);
    }
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

/// Adds charge for [pieces] cleared by [slot], capped at
/// [kPowerMeterMax] (100%). Emits [PowerCharged] with the actual positive
/// delta; no event fires when the meter is already full.
void _addCharge(_Work work, PlayerSlot slot, int pieces) {
  if (pieces <= 0) return;
  final gain = pieces * kChargePerPiece;
  final before = work.powerCharge[slot.index];
  final after =
      before + gain > kPowerMeterMax ? kPowerMeterMax : before + gain;
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
    case kCopter:
      // Priority target: a box if any exist, otherwise a random colour
      // piece. The copter itself is consumed.
      final boxes = <int>[
        for (var j = 0; j < scratch.length; j++)
          if (isBoxCode(scratch[j])) j,
      ];
      if (boxes.isNotEmpty) {
        cells.add(boxes[rng.nextInt(boxes.length)]);
      } else {
        final colours = <int>[
          for (var j = 0; j < scratch.length; j++)
            if (j != index && isColourCode(scratch[j])) j,
        ];
        if (colours.isNotEmpty) {
          cells.add(colours[rng.nextInt(colours.length)]);
        }
      }
      cells.add(index);
    default:
      break;
  }
  return cells;
}

SpecialKind _specialKindOf(int base) => switch (base) {
  kLineRow || kLineColumn => SpecialKind.line,
  kBomb => SpecialKind.bomb,
  kCopter => SpecialKind.copter,
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
  // Sabotage: firing a special sends 1–2 boxes to the opponent.
  _earnObstacles(work, slot.other, 1 + rng.nextInt(2));
  work.storeRng(slot, rng);
}

/// Fires the combined effect of two adjacent special pieces swapped onto
/// each other (Royal Kingdom pair rules). [first] and [second] are the
/// post-swap cell indices; both specials are consumed by the blast.
void _fireCombo(_Work work, PlayerSlot slot, int first, int second) {
  final board = work.boards[slot.index];
  final w = board.width;
  final h = board.height;
  final scratch = List<int>.of(board.cells);
  final rng = work.rngFor(slot);
  final kindA = _specialKindOf(basePieceCode(scratch[first]));
  final kindB = _specialKindOf(basePieceCode(scratch[second]));

  /// Copter priority: a box if any exist, else a random colour piece.
  int copterTarget(Set<int> exclude) {
    final boxes = <int>[
      for (var i = 0; i < scratch.length; i++)
        if (isBoxCode(scratch[i]) && !exclude.contains(i)) i,
    ];
    if (boxes.isNotEmpty) return boxes[rng.nextInt(boxes.length)];
    final colours = <int>[
      for (var i = 0; i < scratch.length; i++)
        if (isColourCode(scratch[i]) && !exclude.contains(i)) i,
    ];
    if (colours.isEmpty) return -1;
    return colours[rng.nextInt(colours.length)];
  }

  final cells = <int>{first, second};
  final kinds = {kindA, kindB};

  void crossAt(int index) {
    final r = index ~/ w, c = index % w;
    for (var cc = 0; cc < w; cc++) {
      final j = r * w + cc;
      if (isPieceCode(scratch[j])) cells.add(j);
    }
    for (var rr = 0; rr < h; rr++) {
      final j = rr * w + c;
      if (isPieceCode(scratch[j])) cells.add(j);
    }
  }

  if (kindA == SpecialKind.rainbow && kindB == SpecialKind.rainbow) {
    // Rainbow + rainbow clears the whole board.
    for (var i = 0; i < scratch.length; i++) {
      if (isPieceCode(scratch[i])) cells.add(i);
    }
  } else if (kindA == SpecialKind.rainbow || kindB == SpecialKind.rainbow) {
    // Rainbow + special: convert the most frequent colour into that
    // special kind and detonate the chain.
    final other = kindA == SpecialKind.rainbow ? kindB : kindA;
    final counts = List<int>.filled(kPieceColours, 0);
    for (final c in scratch) {
      if (isColourCode(c)) counts[basePieceCode(c)]++;
    }
    var target = 0;
    for (var i = 1; i < counts.length; i++) {
      if (counts[i] > counts[target]) target = i;
    }
    final converted = <int>[
      for (var i = 0; i < scratch.length; i++)
        if (isColourCode(scratch[i]) && basePieceCode(scratch[i]) == target)
          i,
    ];
    cells.addAll(converted);
    for (final j in converted) {
      final base = switch (other) {
        SpecialKind.line => j.isEven ? kLineRow : kLineColumn,
        SpecialKind.bomb => kBomb,
        SpecialKind.copter => kCopter,
        _ => kLineRow,
      };
      cells.addAll(
        _specialEffectCells(
          work: work,
          slot: slot,
          index: j,
          base: base,
          scratch: scratch,
          otherSwap: j,
          rng: rng,
        ),
      );
    }
  } else if (kinds.length == 1) {
    switch (kindA) {
      case SpecialKind.line:
        // Rocket + rocket clears the whole row and column in a cross.
        crossAt(second);
      case SpecialKind.bomb:
        // Bomb + bomb: 5×5 explosion centred on the second cell.
        final r = second ~/ w, c = second % w;
        for (var rr = r - 2; rr <= r + 2; rr++) {
          for (var cc = c - 2; cc <= c + 2; cc++) {
            if (rr < 0 || rr >= h || cc < 0 || cc >= w) continue;
            final j = rr * w + cc;
            if (isPieceCode(scratch[j])) cells.add(j);
          }
        }
      case SpecialKind.copter:
        // Copter + copter launches three copters at three targets.
        final taken = <int>{};
        for (var k = 0; k < 3; k++) {
          final t = copterTarget(taken);
          if (t < 0) break;
          taken.add(t);
          cells.add(t);
        }
      case SpecialKind.rainbow:
        break;
    }
  } else if (kinds.contains(SpecialKind.copter)) {
    // Copter + rocket/bomb: the copter carries the special to a priority
    // target and detonates it there.
    final carry = kindA == SpecialKind.copter ? kindB : kindA;
    final t = copterTarget(const {});
    if (t >= 0) {
      if (carry == SpecialKind.bomb) {
        final tr = t ~/ w, tc = t % w;
        for (var rr = tr - 1; rr <= tr + 1; rr++) {
          for (var cc = tc - 1; cc <= tc + 1; cc++) {
            if (rr < 0 || rr >= h || cc < 0 || cc >= w) continue;
            final j = rr * w + cc;
            if (isPieceCode(scratch[j]) || isBoxCode(scratch[j])) {
              cells.add(j);
            }
          }
        }
      } else {
        crossAt(t);
        if (isBoxCode(scratch[t])) cells.add(t);
      }
    }
  } else {
    // Rocket + bomb: three rows and three columns centred on the second
    // cell.
    final r = second ~/ w, c = second % w;
    for (var rr = r - 1; rr <= r + 1; rr++) {
      if (rr < 0 || rr >= h) continue;
      for (var cc = 0; cc < w; cc++) {
        final j = rr * w + cc;
        if (isPieceCode(scratch[j])) cells.add(j);
      }
    }
    for (var cc = c - 1; cc <= c + 1; cc++) {
      if (cc < 0 || cc >= w) continue;
      for (var rr = 0; rr < h; rr++) {
        final j = rr * w + cc;
        if (isPieceCode(scratch[j])) cells.add(j);
      }
    }
  }

  // Commit: write the scratch back, then score, charge, gravity, sabotage.
  for (final j in cells) {
    scratch[j] = kCellEmpty;
  }
  board.cells.setAll(0, scratch);
  final sorted = cells.toList()..sort();
  work.events.add(
    SpecialFired(
      player: slot,
      kind: kindA,
      cells: _posList(w, sorted),
      points: sorted.length * kPointsPerPiece,
    ),
  );
  _addScore(work, slot, sorted.length);
  _addCharge(work, slot, sorted.length);
  _removePieceCells(work, slot, cells);
  applyGravityAndRefill(
    board: board,
    colourCount: work.config.colourCount,
    player: slot,
    events: work.events,
  );
  _earnObstacles(work, slot.other, 1 + rng.nextInt(2));
  work.storeRng(slot, rng);
}

/// Resolves colour matches on [slot]'s board until stable. Each wave:
/// detect groups, create specials on qualifying anchors, clear the rest,
/// break adjacent obstacles, charge the power meter, then gravity and
/// refill. Repeats while matches exist. Flat scoring: no extra moves.
void _resolveMatches(_Work work, PlayerSlot slot) {
  final board = work.boards[slot.index];
  final w = board.width;

  while (true) {
    final groups = scanMatches(board);
    if (groups.isEmpty) break;

    // Decide special creations: 2x2 square -> copter, bent -> bomb,
    // straight 5+ -> rainbow, straight 4 -> line (orientation
    // perpendicular to the run).
    final creations = <(int, int, LineOrientation?)>[]; // anchor, code, orient
    final anchors = <int>{};
    for (final g in groups) {
      int anchor;
      int code;
      LineOrientation? orient;
      if (g.isSquare) {
        anchor = _bombAnchor(g, board);
        code = kCopter;
      } else if (g.isBent) {
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

/// Guarantees [slot]'s board still has a legal move, reshuffling
/// deterministically when it does not. Called after every accepted move
/// and at the start of each turn for the incoming player.
void _ensureLegalMove(_Work work, PlayerSlot slot) {
  final board = work.boards[slot.index];
  if (hasLegalMove(board)) return;
  final rng = work.rngFor(slot);
  reshuffleBoard(
    board: board,
    rng: rng,
    player: slot,
    events: work.events,
  );
  work.storeRng(slot, rng);
}

/// Places [slot]'s pending obstacles on their persistent board at the
/// start of their turn, in queue order, using [slot]'s RNG stream. Boxes
/// replace a random piece cell; yarn locks a random regular-colour piece.
/// Obstacles that find no eligible cell are discarded.
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

/// Queues [count] cardboard boxes for [receiver] — they land on the
/// receiver's board at the start of their next turn. Emits [ObstacleQueued]
/// with the number actually queued (the pending queue is capped at
/// [kMaxPendingObstacles]).
void _earnObstacles(_Work work, PlayerSlot receiver, int count) {
  final queue = work.pending[receiver.index];
  var added = 0;
  for (var k = 0; k < count && queue.length < kMaxPendingObstacles; k++) {
    queue.add(ObstacleKind.box);
    added++;
  }
  if (added > 0) {
    work.events.add(
      ObstacleQueued(
        player: receiver,
        sourceTurn: work.turn,
        count: added,
      ),
    );
  }
}

/// Midnight Zoomies: transforms two random pieces into special pieces and
/// breaks two boxes, then sends [kPowerObstacleCount] boxes to the
/// opponent.
void _powerZoomies(_Work work, PlayerSlot slot, GameRandom rng) {
  final board = work.boards[slot.index];
  final w = board.width;

  const specialBases = [kLineRow, kLineColumn, kBomb, kCopter];
  final colours = <int>[
    for (var i = 0; i < board.cells.length; i++)
      if (isColourCode(board.cells[i])) i,
  ];
  final converted = <int>[];
  for (var k = 0; k < 2 && colours.isNotEmpty; k++) {
    final j = colours.removeAt(rng.nextInt(colours.length));
    board.cells[j] = specialBases[rng.nextInt(specialBases.length)];
    converted.add(j);
    work.events.add(
      SpecialCreated(
        player: slot,
        kind: _specialKindOf(basePieceCode(board.cells[j])),
        orientation: switch (basePieceCode(board.cells[j])) {
          kLineRow => LineOrientation.row,
          kLineColumn => LineOrientation.column,
          _ => null,
        },
        cell: _posOf(w, j),
      ),
    );
  }

  final boxes = <int>[
    for (var i = 0; i < board.cells.length; i++)
      if (isBoxCode(board.cells[i])) i,
  ];
  final broken = <int>[];
  for (var k = 0; k < 2 && boxes.isNotEmpty; k++) {
    broken.add(boxes.removeAt(rng.nextInt(boxes.length)));
  }
  for (final j in broken) {
    board.cells[j] = kCellEmpty;
  }
  if (broken.isNotEmpty) {
    work.events.add(
      ObstacleBroken(player: slot, cells: _posList(w, broken)),
    );
  }

  final shown = <int>[...converted, ...broken]..sort();
  work.events.add(
    PowerFired(
      player: slot,
      power: PowerKind.zoomies,
      cells: _posList(w, shown),
      points: broken.length * kPointsPerPiece,
    ),
  );
  _addScore(work, slot, broken.length);
  _addCharge(work, slot, converted.length + broken.length);
  _earnObstacles(work, slot.other, kPowerObstacleCount);
}

/// Shadow Pounce: clears every piece and box inside the densest 3×3 area
/// (deterministic pick — the fullest window, ties to the lowest index),
/// then sends [kPowerObstacleCount] boxes to the opponent.
void _powerShadowPounce(_Work work, PlayerSlot slot) {
  final board = work.boards[slot.index];
  final w = board.width;
  final h = board.height;

  var best = -1;
  var bestR = 0, bestC = 0;
  for (var r = 0; r + 2 < h; r++) {
    for (var c = 0; c + 2 < w; c++) {
      var n = 0;
      for (var rr = r; rr < r + 3; rr++) {
        for (var cc = c; cc < c + 3; cc++) {
          if (board.cells[rr * w + cc] != kCellEmpty) n++;
        }
      }
      if (n > best) {
        best = n;
        bestR = r;
        bestC = c;
      }
    }
  }
  final cells = <int>{};
  for (var rr = bestR; rr < bestR + 3; rr++) {
    for (var cc = bestC; cc < bestC + 3; cc++) {
      final j = rr * w + cc;
      if (board.cells[j] != kCellEmpty) cells.add(j);
    }
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
  _earnObstacles(work, slot.other, kPowerObstacleCount);
}

/// Laser Chase: clears one full row and one full column in a cross, then
/// sends [kPowerObstacleCount] boxes to the opponent.
void _powerLaserChase(_Work work, PlayerSlot slot, GameRandom rng) {
  final board = work.boards[slot.index];
  final w = board.width;
  final h = board.height;
  final row = rng.nextInt(h);
  final col = rng.nextInt(w);
  final cells = <int>{};
  for (var c = 0; c < w; c++) {
    final j = row * w + c;
    if (isPieceCode(board.cells[j]) || isBoxCode(board.cells[j])) {
      cells.add(j);
    }
  }
  for (var r = 0; r < h; r++) {
    final j = r * w + col;
    if (isPieceCode(board.cells[j]) || isBoxCode(board.cells[j])) {
      cells.add(j);
    }
  }
  final sorted = cells.toList()..sort();
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
  _removePieceCells(work, slot, cells);
  _earnObstacles(work, slot.other, kPowerObstacleCount);
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
const int kHashVersion = 2;

String _dualHash(String canonical) =>
    _hashPass(canonical, 2166136261) + _hashPass(canonical, 2654435761);

String _boardCanonical(BoardState b) =>
    '${b.width}x${b.height};${b.cells.join(',')};${b.refillState.join(',')}';

String _stateCanonical(MatchState s) => [
  'hv=$kHashVersion',
  'engine=${s.engineVersion}',
  'seed=${s.seed}',
  'config=${s.config.fingerprint}',
  'turn=${s.turn}',
  'active=${s.activePlayer.name}',
  'turnsLeft=${s.turnsRemaining.join(',')}',
  'turnMoves=${s.turnMoves}',
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
/// charge, RNG state, pending obstacles and turns remaining.
String playerHash(MatchState state, PlayerSlot player) {
  final i = player.index;
  final canonical = [
    'hv=$kHashVersion',
    'engine=${state.engineVersion}',
    'seed=${state.seed}',
    'config=${state.config.fingerprint}',
    'player=${player.name}',
    'turn=${state.turn}',
    'turnsLeft=${state.turnsRemaining[i]}',
    'score=${state.scores[i]}',
    'charge=${state.powerCharge[i]}',
    'rng=${state.rngState[i]}',
    'pending=${state.pendingObstacles[i].map((k) => k.name).join('+')}',
    'outcome=${state.outcome?.name ?? '-'}',
    'board=${_boardCanonical(state.boards[i])}',
  ].join(';');
  return _dualHash(canonical);
}
