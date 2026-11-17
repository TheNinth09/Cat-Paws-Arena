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
/// line clears its row/column, bomb its 3x3, rainbow handled separately.
Set<int> expectedBlast(List<int> scratch, int w, int h, int pos, int base) {
  final r = pos ~/ w, c = pos % w;
  final cells = <int>{};
  void addIfPiece(int j) {
    if (isPieceCode(scratch[j])) cells.add(j);
  }

  switch (base) {
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
      expect(waveCleared.points, waveCleared.cells.length * kPointsPerPiece);
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

    test('a 2x2 square creates a bomb piece', () {
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

      final bomb = events.whereType<SpecialCreated>().firstWhere(
        (e) => e.kind == SpecialKind.bomb,
        orElse: () => throw StateError('no bomb created'),
      );
      // The anchor is the group's lowest-index cell (top-left corner).
      expect(bomb.cell, (row: 2, col: 2));
      expect(bomb.orientation, isNull);
      final waveCleared = clearedBefore(events, bomb);
      expect(waveCleared.cells, isNot(contains((row: 2, col: 2))));
      for (final p in [
        (row: 2, col: 3),
        (row: 3, col: 2),
        (row: 3, col: 3),
      ]) {
        expect(waveCleared.cells, contains(p));
      }
      expect(findSpecial(res.value.state, PlayerSlot.first, kBomb), isNonNegative);
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
    final partner = neighbourPiece(board, specialAt);
    expect(partner, isNonNegative, reason: 'special needs a swappable neighbour');

    // Simulate the swap on a scratch copy to compute the expected blast.
    final w = board.width, h = board.height;
    final scratch = List<int>.of(board.cells);
    final tmp = scratch[specialAt];
    scratch[specialAt] = scratch[partner];
    scratch[partner] = tmp;
    final specialNow = partner; // special moved to the partner's cell
    final base = basePieceCode(tmp);

    final res = mustApply(
      state,
      SwapMove(
        firstCell: (row: specialAt ~/ w, col: specialAt % w),
        secondCell: (row: partner ~/ w, col: partner % w),
      ),
    );
    final fired = res.value.events.whereType<SpecialFired>().firstWhere(
      (e) => kind == null || e.kind == kind,
      orElse: () => throw StateError('no SpecialFired event'),
    );

    Set<int> expected;
    if (base == kRainbow) {
      expected = <int>{};
      if (config.rainbowRule == RainbowRule.clearOneColour) {
        // Partner piece colour decides; fall back to a drawn colour.
        final partnerCode = scratch[specialAt];
        final target = isColourCode(partnerCode)
            ? basePieceCode(partnerCode)
            : -1;
        if (target >= 0) {
          for (var j = 0; j < scratch.length; j++) {
            if (isColourCode(scratch[j]) && basePieceCode(scratch[j]) == target) {
              expected.add(j);
            }
          }
        }
        expected.add(specialNow);
      } else {
        // Replicate the deterministic partial Fisher-Yates pick.
        final rng = GameRandom.fromState(state.rngState[PlayerSlot.first.index]);
        final eligible = <int>[
          for (var j = 0; j < scratch.length; j++)
            if (isPieceCode(scratch[j])) j,
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
    } else {
      expected = expectedBlast(scratch, w, h, specialNow, base);
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

  test('a fired bomb clears a 3x3 area', () {
    const w = 7, h = 7;
    final bombAt = idx(3, 3);
    final cells = fixture(overrides: {bombAt: kBomb});
    final state = stateWith(firstCells: cells);
    final board = state.boardOf(PlayerSlot.first);
    final partner = neighbourPiece(board, bombAt);
    expect(partner, isNonNegative, reason: 'bomb needs a swappable neighbour');

    final scratch = List<int>.of(board.cells);
    final tmp = scratch[bombAt];
    scratch[bombAt] = scratch[partner];
    scratch[partner] = tmp;

    final res = mustApply(
      state,
      SwapMove(
        firstCell: (row: bombAt ~/ w, col: bombAt % w),
        secondCell: (row: partner ~/ w, col: partner % w),
      ),
    );
    final fired = res.value.events.whereType<SpecialFired>().firstWhere(
      (e) => e.kind == SpecialKind.bomb,
      orElse: () => throw StateError('no SpecialFired event'),
    );
    expect(fired.cells, posListOf(w, expectedBlast(scratch, w, h, partner, kBomb)));
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
    expect(state.turnsLeft(PlayerSlot.first), 5);
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

    // First ends turn 7: only the opponent's queue lands, on their board.
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
    expect(boxes(st1.boardOf(PlayerSlot.first)), 0);

    // Second ends turn 8: first's two boxes land on first's board.
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
    expect(boxes(st2.boardOf(PlayerSlot.first)), 2);
    expect(boxes(st2.boardOf(PlayerSlot.second)), 1);
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

  test('zoomies clears the fullest row and sends two boxes', () {
    final cells = fixture();
    final s = stateWith(firstCells: cells, charge: [kPowerMeterMax, 0]);
    final res = mustApply(
      s,
      const PowerMove(power: PowerKind.zoomies),
    );
    final st = res.value.state;
    final fired = res.value.events.whereType<PowerFired>().single;
    expect(fired.power, PowerKind.zoomies);
    // Every fixture row holds 7 pieces; ties go to the lowest row.
    expect(fired.cells, hasLength(7));
    expect(fired.cells.every((p) => p.row == 0), isTrue);
    expect(fired.points, 70);
    final queued = res.value.events.whereType<ObstacleQueued>().toList();
    expect(queued, hasLength(1));
    expect(queued.single.player, PlayerSlot.second);
    expect(queued.single.sourceTurn, 1);
    expect(queued.single.count, kPowerObstacleCount);
    expect(st.pendingObstacles[1], hasLength(kPowerObstacleCount));
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
              e is PowerFired && e.player == PlayerSlot.first)
          .fold<int>(0, (a, e) => a + switch (e) {
                Cleared c => c.points,
                SpecialFired f => f.points,
                PowerFired f => f.points,
                _ => 0,
              }),
    );
  });

  test('shadow pounce clears the most common colour', () {
    // Overwhelming colour 0: a sparse grid so no two overridden cells are
    // adjacent and no pattern cell can complete a run between them.
    final overrides = <int, int>{
      for (var r = 0; r < 7; r += 3)
        for (var c = 0; c < 7; c += 3) idx(r, c): 0,
    };
    final cells = fixture(overrides: overrides);
    final s = stateWith(
      firstCells: cells,
      charge: [kPowerMeterMax, 0],
      firstPower: PowerKind.shadowPounce,
    );
    expectCleanFixture(cells);

    // Expected: every colour-0 piece on the pre-fire board.
    final expected = <int>{
      for (var i = 0; i < cells.length; i++)
        if (isColourCode(cells[i]) && basePieceCode(cells[i]) == 0) i,
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

  test('laser chase breaks eight pieces and sends two boxes', () {
    final cells = fixture();
    final s = stateWith(
      firstCells: cells,
      charge: [kPowerMeterMax, 0],
      firstPower: PowerKind.laserChase,
    );
    expectCleanFixture(cells);

    // Replicate the deterministic pick of piece cells.
    final rng = GameRandom.fromState(s.rngState[PlayerSlot.first.index]);
    final eligible = <int>[
      for (var i = 0; i < cells.length; i++)
        if (isPieceCode(cells[i])) i,
    ];
    final expected = <int>{};
    for (var k = 0; k < kLaserBreakCount && k < eligible.length; k++) {
      final j = k + rng.nextInt(eligible.length - k);
      final t = eligible[k];
      eligible[k] = eligible[j];
      eligible[j] = t;
      expected.add(eligible[k]);
    }

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
