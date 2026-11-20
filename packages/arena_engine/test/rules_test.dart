/// Slice 2 rules tests: special creation/firing, extra moves, obstacles,
/// power charge and the three powers, plus a scripted five-round match.
///
/// Creation scenarios use short deterministic move logs found by search and
/// verified by replay; obstacle/power scenarios use hand-built boards.
library;

import 'package:arena_engine/arena_engine.dart';
import 'package:arena_engine/src/board.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Fixture helpers
// ---------------------------------------------------------------------------

/// Background pattern with no accidental three-in-a-row, overridable per
/// cell index. `overrides` maps cell index -> encoded cell value.
List<int> fixture({
  int width = 7,
  int height = 7,
  int colourCount = 5,
  Map<int, int>? overrides,
}) {
  final cells = List<int>.generate(width * height, (i) {
    final r = i ~/ width, c = i % width;
    return (r * 2 + c * 3 + 1) % colourCount;
  });
  overrides?.forEach((i, v) => cells[i] = v);
  return cells;
}

int idx(int row, int col, [int width = 7]) => row * width + col;

void expectCleanFixture(List<int> cells, {int width = 7, int height = 7}) {
  final b = MutableBoard(width, height, List<int>.of(cells), const []);
  expect(
    scanMatches(b),
    isEmpty,
    reason: 'fixture must not contain a pre-existing match',
  );
}

List<int> refillStates(int width, [int base = 5000]) =>
    [for (var c = 0; c < width; c++) GameRandom(base + c).state];

/// Builds a [MatchState] with custom boards. [firstCells] is player one's
/// board; [secondCells] defaults to a copy (both boards are independent).
MatchState stateWith({
  required List<int> firstCells,
  List<int>? secondCells,
  int width = 7,
  int height = 7,
  int colourCount = 5,
  int turnsPerPlayer = 5,
  int turn = 1,
  int turnMoves = 0,
  PlayerSlot active = PlayerSlot.first,
  List<int>? turnsRemaining,
  List<int>? scores,
  List<int>? charge,
  List<int>? rngState,
  List<List<ObstacleKind>>? pending,
  RainbowRule rainbowRule = RainbowRule.clearOneColour,
  PowerKind firstPower = PowerKind.zoomies,
  PowerKind secondPower = PowerKind.zoomies,
}) {
  BoardState board(List<int> cells) =>
      BoardState(width, height, cells, refillStates(width));
  return MatchState.create(
    seed: 42,
    config: MatchConfig(
      boardWidth: width,
      boardHeight: height,
      colourCount: colourCount,
      turnsPerPlayer: turnsPerPlayer,
      rainbowRule: rainbowRule,
      firstPower: firstPower,
      secondPower: secondPower,
    ),
    turn: turn,
    activePlayer: active,
    turnsRemaining:
        turnsRemaining ?? [turnsPerPlayer, turnsPerPlayer],
    turnMoves: turnMoves,
    scores: scores ?? [0, 0],
    boards: [board(firstCells), board(secondCells ?? List<int>.of(firstCells))],
    pendingObstacles: pending ?? [<ObstacleKind>[], <ObstacleKind>[]],
    powerCharge: charge ?? [0, 0],
    rngState: rngState ?? [GameRandom(11).state, GameRandom(22).state],
  );
}

EngineOk<MoveResult> mustApply(MatchState s, Move m) {
  final r = applyMove(s, m);
  expect(r, isA<EngineOk<MoveResult>>(), reason: 'move $m must be accepted');
  return r as EngineOk<MoveResult>;
}

/// First swap in [legalMoves], used to pass a turn deterministically.
Move firstSwap(MatchState s) {
  final moves = (legalMoves(s) as EngineOk<List<Move>>).value;
  return moves.firstWhere((m) => m is SwapMove, orElse: () => moves.first);
}

/// Index of the first cell holding [code] (compared on base piece code) on
/// [player]'s board, or -1.
int findSpecial(MatchState s, PlayerSlot player, int code) {
  final cells = s.boardOf(player).cells;
  for (var i = 0; i < cells.length; i++) {
    if (basePieceCode(cells[i]) == code) return i;
    if (code >= kFirstSpecial &&
        isSpecialCode(cells[i]) &&
        specialKindBaseOf(cells[i]) == code) {
      return i;
    }
  }
  return -1;
}

/// An adjacent regular-colour piece cell next to [at], or -1. Specials and
/// yarned pieces are skipped so the fired special has exactly one effect.
int neighbourPiece(BoardState b, int at) {
  final w = b.width, h = b.height;
  final r = at ~/ w, c = at % w;
  const deltas = [(0, -1), (0, 1), (-1, 0), (1, 0)];
  for (final (dr, dc) in deltas) {
    final nr = r + dr, nc = c + dc;
    if (nr < 0 || nr >= h || nc < 0 || nc >= w) continue;
    final j = nr * w + nc;
    final code = b.cells[j];
    if (isColourCode(code) && !isYarnedCode(code)) return j;
  }
  return -1;
}

/// Cells a fired special at [pos] would clear, replicating the spec:
/// line clears its row/column, bomb its 3x3; rainbow and copter are
/// computed in fireSpecial where the rng stream is available.
Set<int> expectedBlast(List<int> scratch, int w, int h, int pos, int base) {
  final r = pos ~/ w, c = pos % w;
  final cells = <int>{};
  void addIfPiece(int j) {
    if (isPieceCode(scratch[j])) cells.add(j);
  }

  switch (base >= kFirstSpecial ? specialKindBaseOf(base) : base) {
    case kLineRow:
      for (var cc = 0; cc < w; cc++) {
        addIfPiece(r * w + cc);
      }
    case kLineColumn:
      for (var rr = 0; rr < h; rr++) {
        addIfPiece(rr * w + c);
      }
    case kBomb:
      for (var rr = r - 1; rr <= r + 1; rr++) {
        if (rr < 0 || rr >= h) continue;
        for (var cc = c - 1; cc <= c + 1; cc++) {
          if (cc < 0 || cc >= w) continue;
          addIfPiece(rr * w + cc);
        }
      }
  }
  return cells;
}

List<CellPos> posListOf(int w, Set<int> cells) {
  final sorted = cells.toList()..sort();
  return [for (final i in sorted) (row: i ~/ w, col: i % w)];
}

// ---------------------------------------------------------------------------
// Special creation (deterministic replay logs)
// ---------------------------------------------------------------------------

void main() {
  const duel = MatchConfig.duel();

  group('special creation', () {
    test('a straight four creates a column-clearing line piece', () {
      // Found by search: seed 6, three swaps; last creates a horizontal four.
      final log = <Move>[
        const SwapMove(firstCell: (row: 0, col: 2), secondCell: (row: 0, col: 3)),
        const SwapMove(firstCell: (row: 0, col: 2), secondCell: (row: 0, col: 3)),
        const SwapMove(firstCell: (row: 1, col: 3), secondCell: (row: 1, col: 4)),
      ];
      final rep = replay(6, duel, log);
      expect(rep, isA<EngineOk<ReplayResult>>());
      final state = (rep as EngineOk<ReplayResult>).value.state;
      final events = stateEventsOf(state, log);

      final created = events.whereType<SpecialCreated>().toList();
      expect(created, isNotEmpty);
      final line = created.firstWhere(
        (e) => e.kind == SpecialKind.line,
        orElse: () => throw StateError('no line created'),
      );
      expect(line.orientation, LineOrientation.column);
      expect(line.cell, (row: 1, col: 3));
      // The creating wave cleared at least the four's other three cells
      // (the wave may include simultaneous groups, so assert containment).
      final waveCleared = clearedBefore(events, line);
      expect(waveCleared.cells, isNot(contains((row: 1, col: 3))));
      expect(
        waveCleared.cells.where((p) => p.row == 1 && p.col != 3).length,
        greaterThanOrEqualTo(3),
      );
      // Points pay the cleared pieces scaled by the wave's cascade
      // multiplier (x1.0 + 0.5 per chained wave) plus the flat creation
      // bonus for every special that wave produced.
      final at = events.indexOf(waveCleared);
      var creations = 0;
      for (var i = at + 1;
          i < events.length && events[i] is SpecialCreated;
          i++) {
        creations++;
      }
      expect(
        [
          for (var w = 0; w < 8; w++)
            waveCleared.cells.length * kPointsPerPiece * (2 + w) ~/ 2 +
                creations * kPointsPerSpecialCreate,
        ],
        contains(waveCleared.points),
      );
      // The special piece exists somewhere on the creator's board.
      expect(findSpecial(state, PlayerSlot.first, kLineColumn), isNonNegative);
    });

    test('a bent five creates a bomb piece', () {
      // Hand-built L of five: row 2 cols 2-4 + col 4 rows 3-4. Swapping
      // (1,4)<->(2,4) drops the corner piece in place.
      final cells = fixture(overrides: {
        idx(2, 2): 0,
        idx(2, 3): 0,
        idx(2, 4): 1,
        idx(2, 5): 1,
        idx(1, 4): 0,
        idx(3, 4): 0,
        idx(4, 4): 0,
      });
      expectCleanFixture(cells);
      final res = mustApply(
        stateWith(firstCells: cells),
        const SwapMove(
          firstCell: (row: 1, col: 4),
          secondCell: (row: 2, col: 4),
        ),
      );
      final events = res.value.events;

      final bomb = events.whereType<SpecialCreated>().firstWhere(
        (e) => e.kind == SpecialKind.bomb,
        orElse: () => throw StateError('no bomb created'),
      );
      expect(bomb.cell, (row: 2, col: 4));
      expect(bomb.orientation, isNull);
      // Bent five: the four non-anchor cells cleared, anchor becomes bomb.
      final waveCleared = clearedBefore(events, bomb);
      expect(waveCleared.cells, isNot(contains((row: 2, col: 4))));
      for (final p in [
        (row: 2, col: 2),
        (row: 2, col: 3),
        (row: 3, col: 4),
        (row: 4, col: 4),
      ]) {
        expect(waveCleared.cells, contains(p));
      }
      expect(findSpecial(res.value.state, PlayerSlot.first, kBomb), isNonNegative);
    });

    test('a 2x2 square creates a copter piece', () {
      // Three corners already placed; swapping (3,3)<->(4,3) fills the
      // fourth and completes the square at rows 2-3, cols 2-3. (3,1) is
      // overridden off the fixture's colour-0 diagonal so the square does
      // not extend into a run.
      final cells = fixture(overrides: {
        idx(2, 2): 0,
        idx(2, 3): 0,
        idx(3, 1): 1,
        idx(3, 2): 0,
        idx(3, 3): 1,
        idx(4, 2): 1,
        idx(4, 3): 0,
      });
      expectCleanFixture(cells);
      final res = mustApply(
        stateWith(firstCells: cells),
        const SwapMove(
          firstCell: (row: 3, col: 3),
          secondCell: (row: 4, col: 3),
        ),
      );
      final events = res.value.events;

      final copter = events.whereType<SpecialCreated>().firstWhere(
        (e) => e.kind == SpecialKind.copter,
        orElse: () => throw StateError('no copter created'),
      );
      // The anchor is the group's lowest-index cell (top-left corner).
      expect(copter.cell, (row: 2, col: 2));
      expect(copter.orientation, isNull);
      final waveCleared = clearedBefore(events, copter);
      expect(waveCleared.cells, isNot(contains((row: 2, col: 2))));
      for (final p in [
        (row: 2, col: 3),
        (row: 3, col: 2),
        (row: 3, col: 3),
      ]) {
        expect(waveCleared.cells, contains(p));
      }
      expect(
        findSpecial(res.value.state, PlayerSlot.first, kCopter),
        isNonNegative,
      );
    });

    test('a straight five creates a rainbow piece', () {
      final log = <Move>[
        const SwapMove(firstCell: (row: 0, col: 1), secondCell: (row: 1, col: 1)),
      ];
      final rep = replay(20, duel, log);
      expect(rep, isA<EngineOk<ReplayResult>>());
      final state = (rep as EngineOk<ReplayResult>).value.state;
      final events = stateEventsOf(state, log);

      final rainbow = events.whereType<SpecialCreated>().firstWhere(
        (e) => e.kind == SpecialKind.rainbow,
        orElse: () => throw StateError('no rainbow created'),
      );
      expect(rainbow.cell, (row: 0, col: 0));
      final waveCleared = clearedBefore(events, rainbow);
      expect(waveCleared.cells, isNot(contains((row: 0, col: 0))));
      expect(waveCleared.cells.length, greaterThanOrEqualTo(4));
      expect(findSpecial(state, PlayerSlot.first, kRainbow), isNonNegative);
    });
  });

  // -------------------------------------------------------------------------
  // Special firing
  // -------------------------------------------------------------------------

  /// Replays [log], passes the turn once so [PlayerSlot.first] (the creator)
  /// is active again, then swaps the special with an adjacent piece.
  ({MatchState before, MatchState after, SpecialFired fired}) fireSpecial({
    required int seed,
    required List<Move> log,
    required MatchConfig config,
    required int specialCode,
    SpecialKind? kind,
  }) {
    final rep = replay(seed, config, log);
    expect(rep, isA<EngineOk<ReplayResult>>());
    var state = (rep as EngineOk<ReplayResult>).value.state;
    // Pass turns until the creator is active again (timed turns only
    // advance via EndTurnMove).
    var turnGuard = 0;
    while (state.activePlayer != PlayerSlot.first &&
        !state.isFinished &&
        turnGuard++ < 4) {
      state = mustApply(state, const EndTurnMove()).value.state;
    }
    expect(state.activePlayer, PlayerSlot.first);
    final specialAt = findSpecial(state, PlayerSlot.first, specialCode);
    expect(specialAt, isNonNegative, reason: 'special must exist pre-fire');
    final board = state.boardOf(PlayerSlot.first);

    // A non-rainbow special fires when the swap places it inside a run
    // of 3+ of the colour it was made from. Rebuild the state with a
    // run planted around the landing cell (rainbow instead keeps the
    // real piece colour — it clears whatever colour it touches), then
    // swap.
    final w = board.width, h = board.height;
    final scratch = List<int>.of(board.cells);
    final base = basePieceCode(scratch[specialAt]);
    var nb = neighbourPiece(board, specialAt);
    expect(nb, isNonNegative, reason: 'special needs an adjacent piece');
    final base2 = specialKindBaseOf(base);
    var plantColour = basePieceCode(scratch[nb]);
    var runCells = <int>{nb};
    if (base2 != kRainbow) {
      // A non-rainbow special fires when the swap places it inside a
      // run of 3+ of its own colour. Walk the colour neighbours and
      // pick a direction where the run can be planted: the special at
      // nb in the middle (nb-d holds the swapped-away piece, already
      // planted in its colour) or at the end (nb+d and nb+2d planted).
      plantColour = specialColourOf(base);
      bool inLine(int j, int d) =>
          j >= 0 &&
          j < scratch.length &&
          (d.abs() == w ? j % w == nb % w : j ~/ w == nb ~/ w);
      bool colourAt(int j) {
        final code = scratch[j];
        return isColourCode(code) && !isYarnedCode(code);
      }

      var foundRun = false;
      const deltas = [-1, 1, -7, 7];
      for (final d0 in deltas) {
        final cand = specialAt + d0;
        if (cand < 0 || cand >= scratch.length || !colourAt(cand)) {
          continue;
        }
        nb = cand;
        final d = nb - specialAt;
        // The run {specialAt, nb, nb+d} places the special in the
        // middle; the swapped-away piece already holds the colour.
        if (inLine(nb + d, d)) {
          runCells = {nb, nb + d};
          foundRun = true;
          break;
        }
      }
      expect(foundRun, isTrue, reason: 'no room to plant the firing run');
    }
    final cells = List<int>.of(scratch);
    for (final j in runCells) {
      cells[j] = plantColour;
    }
    if (base2 != kRainbow) {
      // Demote every other non-rainbow special to a plain piece of its
      // colour so no foreign run can pre-empt our ignition.
      for (var j = 0; j < cells.length; j++) {
        if (j != specialAt &&
            isSpecialCode(cells[j]) &&
            specialKindBaseOf(cells[j]) != kRainbow) {
          cells[j] = specialColourOf(cells[j]);
        }
      }
    }
    final swapped = stateWith(
      firstCells: cells,
      secondCells: state.boardOf(PlayerSlot.second).cells,
      width: w,
      height: h,
      colourCount: config.colourCount,
      turnsPerPlayer: config.turnsPerPlayer,
      turn: state.turn,
      turnMoves: state.turnMoves,
      active: state.activePlayer,
      turnsRemaining: List<int>.of(state.turnsRemaining),
      scores: List<int>.of(state.scores),
      charge: List<int>.of(state.powerCharge),
      rngState: List<int>.of(state.rngState),
      pending: [
        for (final q in state.pendingObstacles) List<ObstacleKind>.of(q),
      ],
      rainbowRule: config.rainbowRule,
      firstPower: config.powerFor(PlayerSlot.first),
      secondPower: config.powerFor(PlayerSlot.second),
    );

    // The special slides onto the planted cell and detonates there —
    // the expected blast is computed on the post-swap scratch.
    final specialNow = nb;
    final post = List<int>.of(scratch);
    post[nb] = scratch[specialAt];
    post[specialAt] = plantColour;
    final res = mustApply(
      swapped,
      SwapMove(
        firstCell: (row: specialAt ~/ w, col: specialAt % w),
        secondCell: (row: nb ~/ w, col: nb % w),
      ),
    );
    final fired = res.value.events.whereType<SpecialFired>().firstWhere(
      (e) => kind == null || e.kind == kind,
      orElse: () => throw StateError('no SpecialFired event'),
    );

    Set<int> expected;
    if (specialKindBaseOf(base) == kRainbow) {
      expected = <int>{};
      if (config.rainbowRule == RainbowRule.clearOneColour) {
        // The planted colour piece determines the cleared colour.
        for (var j = 0; j < post.length; j++) {
          if (isColourCode(post[j]) &&
              basePieceCode(post[j]) == plantColour) {
            expected.add(j);
          }
        }
        expected.add(specialNow);
      } else {
        // Replicate the deterministic partial Fisher-Yates pick.
        final rng = GameRandom.fromState(
          swapped.rngState[PlayerSlot.first.index],
        );
        final eligible = <int>[
          for (var j = 0; j < post.length; j++)
            if (isPieceCode(post[j])) j,
        ];
        final take = eligible.length < kRainbowRemoveCount
            ? eligible.length
            : kRainbowRemoveCount;
        for (var k = 0; k < take; k++) {
          final j = k + rng.nextInt(eligible.length - k);
          final t = eligible[k];
          eligible[k] = eligible[j];
          eligible[j] = t;
          expected.add(eligible[k]);
        }
        expected.add(specialNow);
      }
    } else if (specialKindBaseOf(base) == kCopter) {
      // Priority target: a box if any exist, else a random colour piece
      // (same rng stream the engine uses); the copter is consumed.
      expected = <int>{};
      final rng = GameRandom.fromState(
        swapped.rngState[PlayerSlot.first.index],
      );
      final boxes = <int>[
        for (var j = 0; j < post.length; j++)
          if (isBoxCode(post[j])) j,
      ];
      if (boxes.isNotEmpty) {
        expected.add(boxes[rng.nextInt(boxes.length)]);
      } else {
        final colours = <int>[
          for (var j = 0; j < post.length; j++)
            if (j != specialNow && isColourCode(post[j])) j,
        ];
        if (colours.isNotEmpty) {
          expected.add(colours[rng.nextInt(colours.length)]);
        }
      }
      expected.add(specialNow);
    } else {
      expected = expectedBlast(post, w, h, specialNow, base);
    }

    expect(
      fired.cells,
      posListOf(w, expected),
      reason: 'SpecialFired cells must match the hand-computed blast',
    );
    expect(fired.points, expected.length * kPointsPerPiece);
    return (before: state, after: res.value.state, fired: fired);
  }

  test('a fired line piece clears its whole column', () {
    fireSpecial(
      seed: 6,
      log: const [
        SwapMove(firstCell: (row: 0, col: 2), secondCell: (row: 0, col: 3)),
        SwapMove(firstCell: (row: 0, col: 2), secondCell: (row: 0, col: 3)),
        SwapMove(firstCell: (row: 1, col: 3), secondCell: (row: 1, col: 4)),
      ],
      config: duel,
      specialCode: kLineColumn,
      kind: SpecialKind.line,
    );
  });

  test('a fired copter strikes one target and is consumed', () {
    const w = 7;
    final copterAt = idx(3, 3), nb = idx(3, 4);
    // Bare kCopter is a colour-0 copter: it fires when the swap lands it
    // inside a colour-0 run — plant colour 0 at nb and one cell beyond.
    final cells = fixture(
      overrides: {copterAt: kCopter, nb: 0, idx(3, 5): 0},
    );
    final state = stateWith(firstCells: cells);
    final board = state.boardOf(PlayerSlot.first);
    final scratch = List<int>.of(board.cells);

    final res = mustApply(
      state,
      SwapMove(
        firstCell: (row: copterAt ~/ w, col: copterAt % w),
        secondCell: (row: nb ~/ w, col: nb % w),
      ),
    );
    final fired = res.value.events.whereType<SpecialFired>().firstWhere(
      (e) => e.kind == SpecialKind.copter,
      orElse: () => throw StateError('no SpecialFired event'),
    );
    // No boxes on the fixture board: the copter strikes one colour piece
    // (deterministic rng pick) and is consumed itself at its new cell.
    final post = List<int>.of(scratch)
      ..[nb] = scratch[copterAt]
      ..[copterAt] = 0;
    final rng = GameRandom.fromState(state.rngState[PlayerSlot.first.index]);
    final colours = <int>[
      for (var j = 0; j < post.length; j++)
        if (j != nb && isColourCode(post[j])) j,
    ];
    final expected = <int>{colours[rng.nextInt(colours.length)], nb};
    expect(fired.cells, posListOf(w, expected));
    expect(fired.points, expected.length * kPointsPerPiece);
  });

  test('a fired bomb clears a 3x3 area', () {
    const w = 7, h = 7;
    final bombAt = idx(3, 3), nb = idx(3, 4);
    // Bare kBomb is a colour-0 bomb: the swap must land it inside a
    // colour-0 run — plant colour 0 at nb and one cell beyond.
    final cells = fixture(overrides: {bombAt: kBomb, nb: 0, idx(3, 5): 0});
    final state = stateWith(firstCells: cells);
    final board = state.boardOf(PlayerSlot.first);
    final scratch = List<int>.of(board.cells);

    final res = mustApply(
      state,
      SwapMove(
        firstCell: (row: bombAt ~/ w, col: bombAt % w),
        secondCell: (row: nb ~/ w, col: nb % w),
      ),
    );
    final fired = res.value.events.whereType<SpecialFired>().firstWhere(
      (e) => e.kind == SpecialKind.bomb,
      orElse: () => throw StateError('no SpecialFired event'),
    );
    final post = List<int>.of(scratch)
      ..[nb] = scratch[bombAt]
      ..[bombAt] = 0;
    expect(fired.cells, posListOf(w, expectedBlast(post, w, h, nb, kBomb)));
    expect(fired.points, greaterThan(0));
  });

  test('a fired rainbow clears the swapped piece colour', () {
    fireSpecial(
      seed: 20,
      log: const [
        SwapMove(firstCell: (row: 0, col: 1), secondCell: (row: 1, col: 1)),
      ],
      config: duel,
      specialCode: kRainbow,
      kind: SpecialKind.rainbow,
    );
  });

  test('a fired rainbow removes 12 random pieces under removeRandomPieces',
      () {
    fireSpecial(
      seed: 20,
      log: const [
        SwapMove(firstCell: (row: 0, col: 1), secondCell: (row: 1, col: 1)),
      ],
      config: const MatchConfig(
        rainbowRule: RainbowRule.removeRandomPieces,
      ),
      specialCode: kRainbow,
      kind: SpecialKind.rainbow,
    );
  });

  // -------------------------------------------------------------------------
  // Extra moves and charge
  // -------------------------------------------------------------------------

  test('a match of four or more grants no extra move', () {
    // Bent five from seed 9: one swap, one group of five cells.
    final rep = replay(
      9,
      duel,
      const [SwapMove(firstCell: (row: 1, col: 3), secondCell: (row: 1, col: 4))],
    );
    expect(rep, isA<EngineOk<ReplayResult>>());
    final state = (rep as EngineOk<ReplayResult>).value.state;
    // Timed turns: the move count is informational only; the turn does
    // not advance until EndTurnMove.
    expect(state.turnMoves, 1);
    expect(state.activePlayer, PlayerSlot.first);
    expect(state.turn, 1);
    expect(state.turnsLeft(PlayerSlot.first), duel.turnsPerPlayer);
  });

  test('cleared pieces add power charge', () {
    final s = stateWith(firstCells: fixture(overrides: {
      idx(2, 0): 2,
      idx(2, 1): 0, idx(2, 2): 0, idx(2, 3): 1, idx(2, 4): 0,
    }));
    expectCleanFixture(s.boardOf(PlayerSlot.first).cells);
    final res = mustApply(
      s,
      const SwapMove(firstCell: (row: 2, col: 3), secondCell: (row: 2, col: 4)),
    );
    // Charge equals cleared pieces * kChargePerPiece (cascades included),
    // capped at kPowerMeterMax.
    final clearedPieces = res.value.events
        .whereType<Cleared>()
        .where((e) => e.player == PlayerSlot.first)
        .fold<int>(0, (a, e) => a + e.cells.length);
    expect(
      res.value.state.chargeOf(PlayerSlot.first),
      clearedPieces * kChargePerPiece > kPowerMeterMax
          ? kPowerMeterMax
          : clearedPieces * kChargePerPiece,
    );
    final charged = res.value.events.whereType<PowerCharged>().toList();
    final gained = charged
        .where((e) => e.amount > 0)
        .fold<int>(0, (a, e) => a + e.amount);
    expect(gained, res.value.state.chargeOf(PlayerSlot.first));
  });

  // -------------------------------------------------------------------------
  // Obstacles
  // -------------------------------------------------------------------------

  test('a box breaks when an adjacent piece is cleared', () {
    // Box at (4,4); a three-match on row 3 clears (3,4) next to it.
    final cells = fixture(overrides: {
      // Row 3: c2,c3 = 0,0 ; c4 = 1 ; c5 = 0 ; c6 = 4 ; c1 = 3 ; c0 = 2
      idx(3, 0): 2, idx(3, 1): 3, idx(3, 2): 0, idx(3, 3): 0,
      idx(3, 4): 1, idx(3, 5): 0, idx(3, 6): 4,
      idx(4, 4): kCellBox,
    });
    final s = stateWith(firstCells: cells);
    expectCleanFixture(cells);
    final res = mustApply(
      s,
      const SwapMove(firstCell: (row: 3, col: 4), secondCell: (row: 3, col: 5)),
    );
    // Swap puts 0 at c4 -> row3 c2,c3,c4 = 0,0,0 -> clears incl (3,4).
    final broken = res.value.events.whereType<ObstacleBroken>().toList();
    expect(broken, isNotEmpty);
    expect(
      broken.expand((e) => e.cells),
      contains((row: 4, col: 4)),
      reason: 'box at (4,4) must break',
    );
    // The box cell is a piece again after gravity+refill.
    expect(
      isPieceCode(res.value.state.boardOf(PlayerSlot.first).cellAt(4, 4)),
      isTrue,
    );
  });

  test('a yarned piece cannot be swapped but clears with its match', () {
    // Yarned 0 at (3,0); swap builds 0,0,0 across c0-c2.
    final cells = fixture(overrides: {
      idx(3, 0): 0 + kYarnOffset, idx(3, 1): 0, idx(3, 2): 1, idx(3, 3): 0,
      idx(3, 4): 2, idx(3, 5): 3, idx(3, 6): 4,
    });
    final s = stateWith(firstCells: cells);
    expectCleanFixture(cells);

    // Direct swap involving the yarned piece is rejected.
    final bad = applyMove(
      s,
      const SwapMove(firstCell: (row: 3, col: 0), secondCell: (row: 3, col: 1)),
    );
    expect(bad, isA<EngineFailure<MoveResult>>());
    expect(
      (bad as EngineFailure<MoveResult>).error.code,
      EngineErrorCode.invalidMove,
    );

    // Swapping c2/c3 makes c0,c1,c2 = yarned0,0,0 -> match incl. yarn.
    final res = mustApply(
      s,
      const SwapMove(firstCell: (row: 3, col: 2), secondCell: (row: 3, col: 3)),
    );
    final cleared = res.value.events.whereType<Cleared>().first;
    expect(cleared.cells, contains((row: 3, col: 0)));
    final broken = res.value.events.whereType<ObstacleBroken>().toList();
    expect(
      broken.expand((e) => e.cells),
      contains((row: 3, col: 0)),
      reason: 'the yarn lock is consumed when its piece clears',
    );
    // After resolution the cell holds an ordinary piece again.
    final after = res.value.state.boardOf(PlayerSlot.first).cellAt(3, 0);
    expect(isYarnedCode(after), isFalse);
  });

  test('queued boxes land on the opponent board at the start of their next turn', () {
    // Turn 7 of 10 (first's fourth turn), two turns left each; pending
    // boxes preset for both receivers.
    final guardian = fixture(overrides: {
      idx(0, 0): kBomb, // swapping it with (0,1) is always productive
    });
    final s = stateWith(
      firstCells: guardian,
      turn: 7,
      turnsRemaining: [2, 2],
      pending: const [
        [ObstacleKind.box, ObstacleKind.box],
        [ObstacleKind.box],
      ],
    );
    expectCleanFixture(guardian);

    int boxes(BoardState b) =>
        b.cells.where((c) => c == kCellBox).length;

    // First ends turn 7: the queue addressed to second lands on the
    // shared board — both players swap on one board, alternating turns.
    final m1 = mustApply(s, const EndTurnMove());
    final st1 = m1.value.state;
    expect(st1.turn, 8);
    expect(st1.activePlayer, PlayerSlot.second);
    expect(st1.turnsLeft(PlayerSlot.first), 1);
    expect(st1.turnsLeft(PlayerSlot.second), 2);
    final landed1 = m1.value.events.whereType<ObstacleLanded>().toList();
    expect(landed1, hasLength(1));
    expect(landed1.single.player, PlayerSlot.second);
    expect(landed1.single.cells, hasLength(1)); // one box
    expect(st1.pendingObstacles[1], isEmpty);
    expect(st1.pendingObstacles[0], hasLength(2));
    expect(boxes(st1.boardOf(PlayerSlot.second)), 1);
    // Shared board: the same physical box is visible from first's view.
    expect(boxes(st1.boardOf(PlayerSlot.first)), 1);

    // Second ends turn 8: first's two queued boxes land on the shared
    // board, joining the one already there.
    final m2 = mustApply(st1, const EndTurnMove());
    final st2 = m2.value.state;
    expect(st2.turn, 9);
    expect(st2.activePlayer, PlayerSlot.first);
    expect(st2.isFinished, isFalse);
    final landed2 = m2.value.events.whereType<ObstacleLanded>().toList();
    expect(landed2, hasLength(1));
    expect(landed2.single.player, PlayerSlot.first);
    expect(landed2.single.cells, hasLength(2)); // two boxes
    expect(st2.pendingObstacles[0], isEmpty);
    expect(boxes(st2.boardOf(PlayerSlot.first)), 3);
    expect(boxes(st2.boardOf(PlayerSlot.second)), 3);
  });

  // -------------------------------------------------------------------------
  // Powers
  // -------------------------------------------------------------------------

  test('a power needs a full meter and the cat\'s own power', () {
    final s = stateWith(firstCells: fixture(), charge: [kPowerMeterMax - 1, 0]);
    final r = applyMove(s, const PowerMove(power: PowerKind.zoomies));
    expect(r, isA<EngineFailure<MoveResult>>());
    expect(
      (r as EngineFailure<MoveResult>).error.code,
      EngineErrorCode.insufficientCharge,
    );
    // Firing a power the cat did not bring is an invalid move.
    final s2 = stateWith(firstCells: fixture(), charge: [kPowerMeterMax, 0]);
    final r2 = applyMove(s2, const PowerMove(power: PowerKind.shadowPounce));
    expect(r2, isA<EngineFailure<MoveResult>>());
    expect(
      (r2 as EngineFailure<MoveResult>).error.code,
      EngineErrorCode.invalidMove,
    );
  });

  test('the power meter is hard-capped at 100', () {
    // Same clear as the charge test but starting one point below the cap:
    // the meter saturates at kPowerMeterMax and never exceeds it.
    final s = stateWith(
      firstCells: fixture(overrides: {
        idx(2, 0): 2,
        idx(2, 1): 0, idx(2, 2): 0, idx(2, 3): 1, idx(2, 4): 0,
      }),
      charge: [kPowerMeterMax - 1, 0],
    );
    final res = mustApply(
      s,
      const SwapMove(firstCell: (row: 2, col: 3), secondCell: (row: 2, col: 4)),
    );
    expect(res.value.state.chargeOf(PlayerSlot.first), kPowerMeterMax);
  });

  test('zoomies converts two pieces into specials and sends boxes', () {
    final cells = fixture();
    final s = stateWith(firstCells: cells, charge: [kPowerMeterMax, 0]);
    // Replicate the deterministic picks: two random colour cells become
    // random specials (rng stream consumed in order).
    final rng = GameRandom.fromState(s.rngState[PlayerSlot.first.index]);
    final colours = <int>[
      for (var i = 0; i < cells.length; i++)
        if (isColourCode(cells[i])) i,
    ];
    final converted = <int>[];
    for (var k = 0; k < 2; k++) {
      converted.add(colours.removeAt(rng.nextInt(colours.length)));
      rng.nextInt(4); // specialBase pick
    }
    final res = mustApply(
      s,
      const PowerMove(power: PowerKind.zoomies),
    );
    final st = res.value.state;
    final created = res.value.events.whereType<SpecialCreated>().toList();
    expect(created, hasLength(2));
    final fired = res.value.events.whereType<PowerFired>().single;
    expect(fired.power, PowerKind.zoomies);
    // No boxes on the fixture board: cells are the two converted pieces.
    expect(fired.cells, posListOf(7, converted.toSet()));
    expect(fired.points, 0);
    // The contract detonates both fresh specials on the spot — their
    // score rides on SpecialFired/ObstacleBroken events, not PowerFired.
    expect(res.value.events.whereType<SpecialFired>(), isNotEmpty);
    final queued = res.value.events.whereType<ObstacleQueued>().toList();
    expect(queued, hasLength(1));
    expect(queued.single.player, PlayerSlot.second);
    expect(queued.single.sourceTurn, 1);
    // Sabotage through the shared special path: 1–2 boxes.
    expect(queued.single.count, inInclusiveRange(1, 2));
    expect(st.pendingObstacles[1].length, queued.single.count);
    // The meter was spent to zero, then partially refilled by the clears.
    expect(
      res.value.events
          .whereType<PowerCharged>()
          .any((e) => e.amount == -kPowerMeterMax),
      isTrue,
    );
    expect(st.chargeOf(PlayerSlot.first), greaterThan(0));
    expect(st.chargeOf(PlayerSlot.first), lessThanOrEqualTo(kPowerMeterMax));
    // Score equals the sum of point-bearing events.
    expect(
      st.scoreOf(PlayerSlot.first),
      res.value.events
          .where((e) =>
              e is Cleared && e.player == PlayerSlot.first ||
              e is SpecialFired && e.player == PlayerSlot.first ||
              e is PowerFired && e.player == PlayerSlot.first ||
              e is ObstacleBroken && e.player == PlayerSlot.first)
          .fold<int>(0, (a, e) => a + switch (e) {
                Cleared c => c.points,
                SpecialFired f => f.points,
                PowerFired f => f.points,
                ObstacleBroken b => b.points,
                _ => 0,
              }),
    );
  });

  test('shadow pounce clears the densest 3x3 area', () {
    // Full fixture: every 3x3 window holds 9 cells; the tie goes to the
    // lowest index, i.e. the top-left corner.
    final cells = fixture();
    final s = stateWith(
      firstCells: cells,
      charge: [kPowerMeterMax, 0],
      firstPower: PowerKind.shadowPounce,
    );
    expectCleanFixture(cells);

    final expected = <int>{
      for (var r = 0; r < 3; r++)
        for (var c = 0; c < 3; c++) idx(r, c),
    };
    final res = mustApply(
      s,
      const PowerMove(power: PowerKind.shadowPounce),
    );
    final fired = res.value.events.whereType<PowerFired>().single;
    expect(fired.power, PowerKind.shadowPounce);
    expect(fired.cells, posListOf(7, expected));
    expect(fired.points, expected.length * kPointsPerPiece);
    // Equal strength: shadow pounce also sends boxes to the opponent.
    expect(st_pendingBoxes(res.value.state), kPowerObstacleCount);
  });

  test('laser chase clears the most valuable row-column cross', () {
    final cells = fixture();
    final s = stateWith(
      firstCells: cells,
      charge: [kPowerMeterMax, 0],
      firstPower: PowerKind.laserChase,
    );
    expectCleanFixture(cells);

    // Replicate the deterministic pick: the pivot whose cross holds the
    // most boxes (x3) and pieces (x1), ties to the lowest index.
    var best = -1, row = 0, col = 0;
    for (var j = 0; j < cells.length; j++) {
      final r = j ~/ 7, c = j % 7;
      var n = 0;
      for (var cc = 0; cc < 7; cc++) {
        final cell = cells[r * 7 + cc];
        n += isBoxCode(cell) ? 3 : cell != kCellEmpty ? 1 : 0;
      }
      for (var rr = 0; rr < 7; rr++) {
        final cell = cells[rr * 7 + c];
        n += isBoxCode(cell) ? 3 : cell != kCellEmpty ? 1 : 0;
      }
      final pivot = cells[j];
      n -= isBoxCode(pivot) ? 3 : pivot != kCellEmpty ? 1 : 0;
      if (n > best) {
        best = n;
        row = r;
        col = c;
      }
    }
    final expected = <int>{
      for (var c = 0; c < 7; c++)
        if (isPieceCode(cells[row * 7 + c]) || isBoxCode(cells[row * 7 + c]))
          row * 7 + c,
      for (var r = 0; r < 7; r++)
        if (isPieceCode(cells[r * 7 + col]) || isBoxCode(cells[r * 7 + col]))
          r * 7 + col,
    };

    final res = mustApply(
      s,
      const PowerMove(power: PowerKind.laserChase),
    );
    final fired = res.value.events.whereType<PowerFired>().single;
    expect(fired.power, PowerKind.laserChase);
    expect(fired.cells, posListOf(7, expected));
    // Equal strength: laser chase queues boxes for the opponent too.
    expect(st_pendingBoxes(res.value.state), kPowerObstacleCount);
  });

  // -------------------------------------------------------------------------
  // Full scripted match
  // -------------------------------------------------------------------------

  test('a scripted timed-turn match ends with MatchEnded and consistent scores',
      () {
    const config = MatchConfig.duel();
    final start = newMatch(7, config);
    expect(start, isA<EngineOk<MatchState>>());
    var state = (start as EngineOk<MatchState>).value;
    final log = <Move>[];
    final events = <GameEvent>[];

    var guard = 0;
    while (!state.isFinished && guard++ < 600) {
      final moves = (legalMoves(state) as EngineOk<List<Move>>).value;
      expect(moves, isNotEmpty, reason: 'live match must always offer a move');
      // End the turn periodically; timed turns only advance via
      // EndTurnMove. Otherwise prefer a power when the meter is full,
      // then a productive swap.
      final Move move;
      if (log.length % 8 == 7 && moves.last is EndTurnMove) {
        move = const EndTurnMove();
      } else {
        final powers = [for (final m in moves) if (m is PowerMove) m];
        if (powers.isNotEmpty && log.length % 5 == 4) {
          move = powers.first;
        } else {
          move = moves.firstWhere(
            (m) => m is SwapMove,
            orElse: () => moves.first,
          );
        }
      }
      final res = applyMove(state, move);
      expect(res, isA<EngineOk<MoveResult>>());
      final ok = res as EngineOk<MoveResult>;
      events.addAll(ok.value.events);
      state = ok.value.state;
      log.add(move);
    }

    expect(state.isFinished, isTrue, reason: 'match must finish within guard');
    expect(state.turn, 2 * config.turnsPerPlayer);
    expect(state.turnsLeft(PlayerSlot.first), 0);
    expect(state.turnsLeft(PlayerSlot.second), 0);
    final ended = events.whereType<MatchEnded>().single;
    expect(ended.outcome, state.outcome);
    expect(ended.scores.first, state.scores[0]);
    expect(ended.scores.second, state.scores[1]);

    // Scores equal the sum of all point-bearing events per player.
    int pointsFor(PlayerSlot p) => events.fold<int>(0, (a, e) {
          if (e is Cleared && e.player == p) return a + e.points;
          if (e is SpecialFired && e.player == p) return a + e.points;
          if (e is PowerFired && e.player == p) return a + e.points;
          if (e is ObstacleBroken && e.player == p) return a + e.points;
          return a;
        });
    expect(pointsFor(PlayerSlot.first), state.scores[0]);
    expect(pointsFor(PlayerSlot.second), state.scores[1]);

    // The whole match replays deterministically to the same hash.
    final rep = replay(7, config, log);
    expect(rep, isA<EngineOk<ReplayResult>>());
    final repState = (rep as EngineOk<ReplayResult>).value;
    expect(repState.hash, stateHash(state));
    expect(repState.state.isFinished, isTrue);
  });
}

/// Pending box count queued for [PlayerSlot.second].
int st_pendingBoxes(MatchState s) =>
    s.pendingObstacles[PlayerSlot.second.index].length;

/// The [Cleared] event of the resolution wave that produced [created]:
/// the last [Cleared] emitted before it in the event stream.
Cleared clearedBefore(List<GameEvent> events, SpecialCreated created) {
  final at = events.indexOf(created);
  for (var i = at - 1; i >= 0; i--) {
    final e = events[i];
    if (e is Cleared) return e;
    if (e is TurnEnded || e is MatchEnded) break;
  }
  throw StateError('no Cleared wave before $created');
}

/// Replays [log] and returns every event emitted along the way, in order.
/// Used to inspect creation waves without keeping per-move results.
List<GameEvent> stateEventsOf(MatchState state, List<Move> log) {
  // Replay already applied the log; to see events we replay again and
  // collect them per step.
  final config = state.config;
  var s = (newMatch(state.seed, config) as EngineOk<MatchState>).value;
  final all = <GameEvent>[];
  for (final m in log) {
    final r = applyMove(s, m);
    if (r is EngineOk<MoveResult>) {
      all.addAll(r.value.events);
      s = r.value.state;
    }
  }
  return all;
}
