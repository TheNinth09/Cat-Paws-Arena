import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arena_engine/arena_engine.dart' as engine;
import 'package:cat_paws_arena/main.dart';
import 'package:cat_paws_arena/board_game.dart';
import 'package:cat_paws_arena/duel_audio.dart';
import 'package:cat_paws_arena/duel_events.dart';
import 'package:cat_paws_arena/engine_events.dart';
import 'package:cat_paws_arena/match_controller.dart';
import 'package:cat_paws_arena/match_screen.dart';
import 'package:cat_paws_arena/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'artwork_test_support.dart';

void main() {
  testWidgets('runtime bundle contains only sprites and fonts', (tester) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final artwork = manifest.listAssets().where(
      (name) => name.startsWith('assets/'),
    );
    expect(artwork, isNotEmpty);
    expect(
      artwork.where(
        (name) =>
            !name.startsWith('assets/generated/') &&
            !name.startsWith('assets/fonts/') &&
            !name.startsWith('assets/audio/'),
      ),
      isEmpty,
    );
    await tester.pumpWidget(const MaterialApp(home: StudioSplash()));
    expectCleanArtwork(tester);
  });

  testWidgets('VS, gameplay and result never render screen mockups', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final p = Player(await SharedPreferences.getInstance())
      ..name = 'UnNumeFoarteLungDeJucător';
    await tester.pumpWidget(MaterialApp(home: MatchScreen(player: p, mode: 0)));
    expectCleanArtwork(tester);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 100));
    expectCleanArtwork(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Renunță'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('RENUNȚĂ'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ÎNFRÂNGERE'), findsOneWidget);
    expectCleanArtwork(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('board plays scripted contract events to the expected board', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    BoardPiece pc(int id, int kind) =>
        BoardPiece(id: id, kind: kind);

    // 7x7 board, kind = index % 5, id = index.
    final initial = BoardSnapshot(
      width: 7,
      height: 7,
      cells: [
        for (var i = 0; i < 49; i++) BoardCell(piece: pc(i, i % 5)),
      ],
    );
    final key = GlobalKey<BoardViewState>();
    final attempts = <(int, int)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 360,
              child: BoardView(
                key: key,
                initial: initial,
                onSwapAttempt: (a, b) => attempts.add((a, b)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final state = key.currentState!;
    expect(
      _grid(state.cells),
      [for (var i = 0; i < 49; i++) '${i % 5}'].join(),
    );

    final events = <BoardEvent>[
      const SwapRejected(
        player: PlayerSlot.first,
        firstCell: 0,
        secondCell: 7,
        reason: 'no-match',
      ),
      const Swapped(player: PlayerSlot.first, firstCell: 10, secondCell: 11),
      const Cleared(
        player: PlayerSlot.first,
        cells: [11, 18, 25],
        points: 30,
      ),
      const Fell(player: PlayerSlot.first, from: 4, to: 25),
      Refilled(
        player: PlayerSlot.first,
        cell: 18,
        piece: pc(102, 3),
      ),
      Refilled(
        player: PlayerSlot.first,
        cell: 11,
        piece: pc(101, 2),
      ),
      Refilled(
        player: PlayerSlot.first,
        cell: 4,
        piece: pc(100, 4),
      ),
      const ObstacleLanded(
        player: PlayerSlot.first,
        cells: [30, 31],
        obstacle: ObstacleKind.cardboardBox,
      ),
      const ObstacleBroken(player: PlayerSlot.first, cells: [30]),
      Refilled(
        player: PlayerSlot.first,
        cell: 30,
        piece: pc(103, 1),
      ),
      Shuffled(
        player: PlayerSlot.first,
        cells: [0, 1, 2, 3, 4, 5, 6],
        reason: 'test',
        pieces: {
          0: pc(3, 3),
          1: pc(2, 2),
          2: pc(1, 1),
          3: pc(0, 0),
          4: pc(100, 4),
          5: pc(5, 0),
          6: pc(6, 1),
        },
      ),
    ];

    final done = state.play(events);
    // The logical board is final before the animations finish.
    expect(_grid(state.cells), _expectedGrid);
    expect(state.busy, isTrue);
    await tester.pumpAndSettle();
    await done;
    expect(_grid(state.cells), _expectedGrid);
    expect(tester.takeException(), isNull);

    // Piece identity survives falls and shuffles.
    expect(state.cells[25].piece!.id, 4);
    expect(state.cells[10].piece!.id, 11);
    expect(state.cells[11].piece!.id, 101);
    expect(state.cells[30].piece!.id, 103);
    expect(state.cells[31].obstacle, ObstacleKind.cardboardBox);
    expect(state.cells[0].piece!.id, 3);

    // Input still works after the queue drains: tap cell 0 then cell 1.
    await tester.tapAt(const Offset(360 / 14, 140 + 360 / 14));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(3 * 360 / 14, 140 + 360 / 14));
    await tester.pump(const Duration(milliseconds: 50));
    expect(attempts, [(0, 1)]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  test('board widget imports no rule code', () {
    final src = File('lib/board_game.dart').readAsStringSync();
    expect(src, contains("import 'duel_events.dart'"));
    for (final banned in [
      'arena.dart',
      'match_controller',
      'MatchBoard',
      'matches(',
      'hasMove',
      'flame',
    ]) {
      expect(src, isNot(contains(banned)), reason: 'found $banned');
    }
  });

  test('every contract event type maps to a sound and a haptic', () {
    final out = _RecSfx();
    final haps = <HapticKind>[];
    final audio = DuelAudio(output: out, haptics: haps.add);
    final events = <BoardEvent>[
      const Swapped(player: PlayerSlot.first, firstCell: 0, secondCell: 1),
      const SwapRejected(
        player: PlayerSlot.first,
        firstCell: 0,
        secondCell: 7,
        reason: 'no-match',
      ),
      const Cleared(player: PlayerSlot.first, cells: [0], points: 10),
      const SpecialCreated(
        player: PlayerSlot.first,
        kind: SpecialKind.lineHorizontal,
        cell: 0,
      ),
      const SpecialFired(
        player: PlayerSlot.first,
        kind: SpecialKind.bomb,
        cells: [0],
        points: 20,
      ),
      const Fell(player: PlayerSlot.first, from: 0, to: 7),
      Refilled(
        player: PlayerSlot.first,
        cell: 0,
        piece: BoardPiece(id: 1, kind: 0),
      ),
      const ObstacleQueued(
        player: PlayerSlot.first,
        sourceRound: 0,
        count: 2,
      ),
      const ObstacleLanded(
        player: PlayerSlot.first,
        cells: [0],
        obstacle: ObstacleKind.cardboardBox,
      ),
      const ObstacleBroken(player: PlayerSlot.first, cells: [0]),
      const PowerCharged(player: PlayerSlot.first, amount: 100),
      const PowerFired(
        player: PlayerSlot.first,
        power: PowerKind.zoomies,
        cells: [0],
        points: 30,
      ),
      Shuffled(
        player: PlayerSlot.first,
        cells: [0],
        reason: 'test',
        pieces: {0: BoardPiece(id: 1, kind: 0)},
      ),
      const ExtraMove(player: PlayerSlot.first, round: 1, movesRemaining: 3),
      const RoundEnded(
        round: 1,
        scores: (first: 5, second: 3),
      ),
      const MatchEnded(
        outcome: MatchOutcome.firstWin,
        scores: (first: 9, second: 4),
        finalHashes: (first: 'a', second: 'b'),
      ),
    ];
    for (final e in events) {
      audio.play(e);
    }
    expect(out.plays, hasLength(events.length));
    expect(haps, hasLength(events.length));
    // Every WAV referenced by the cue table exists on disk.
    for (final play in out.plays) {
      expect(
        File('assets/${play.asset}').existsSync(),
        isTrue,
        reason: '${play.asset} missing',
      );
    }
    audio.dispose();
  });

  test('cascade raises the clear sound pitch each step', () {
    final out = _RecSfx();
    final audio = DuelAudio(output: out, haptics: (_) {});
    audio.play(const Swapped(player: PlayerSlot.first, firstCell: 0, secondCell: 1));
    audio.play(const Cleared(player: PlayerSlot.first, cells: [0], points: 10));
    audio.play(const Fell(player: PlayerSlot.first, from: 0, to: 7));
    audio.play(
      Refilled(player: PlayerSlot.first, cell: 0, piece: BoardPiece(id: 1, kind: 0)),
    );
    audio.play(const Cleared(player: PlayerSlot.first, cells: [1], points: 10));
    audio.play(
      const SpecialFired(
        player: PlayerSlot.first,
        kind: SpecialKind.lineHorizontal,
        cells: [2],
        points: 15,
      ),
    );
    // A new move resets the chain.
    audio.play(const Swapped(player: PlayerSlot.first, firstCell: 2, secondCell: 3));
    audio.play(const Cleared(player: PlayerSlot.first, cells: [3], points: 10));
    final pops = out.plays
        .where((p) => p.asset == 'generated/audio/sfx_pop.wav')
        .map((p) => p.rate)
        .toList();
    expect(pops, hasLength(3));
    expect(pops[0], closeTo(1.12, 1e-9));
    expect(pops[1], closeTo(1.24, 1e-9));
    expect(pops[2], closeTo(1.12, 1e-9));
    final specials = out.plays
        .where((p) => p.asset == 'generated/audio/sfx_special.wav')
        .map((p) => p.rate)
        .toList();
    expect(specials, hasLength(1));
    expect(specials.single, closeTo(1.36, 1e-9));
    audio.dispose();
  });

  test('sound setting off silences cues and haptics', () {
    final out = _RecSfx();
    final haps = <HapticKind>[];
    final audio = DuelAudio(
      output: out,
      haptics: haps.add,
      enabled: () => false,
    );
    audio.play(const Swapped(player: PlayerSlot.first, firstCell: 0, secondCell: 1));
    audio.play(const Cleared(player: PlayerSlot.first, cells: [0], points: 10));
    audio.play(const MatchEnded(
      outcome: MatchOutcome.draw,
      scores: (first: 1, second: 1),
      finalHashes: (first: 'a', second: 'b'),
    ));
    expect(out.plays, isEmpty);
    expect(haps, isEmpty);
    audio.dispose();
  });

  testWidgets('meta events show banner animations', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final initial = BoardSnapshot(
      width: 7,
      height: 7,
      cells: [
        for (var i = 0; i < 49; i++) BoardCell(piece: BoardPiece(id: i, kind: i % 5)),
      ],
    );
    final key = GlobalKey<BoardViewState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 360,
              child: BoardView(key: key, initial: initial),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    unawaited(
      key.currentState!.play([
        const ObstacleQueued(player: PlayerSlot.first, sourceRound: 0, count: 2),
        const PowerCharged(player: PlayerSlot.first, amount: 100),
        const ExtraMove(player: PlayerSlot.first, round: 0, movesRemaining: 3),
        const RoundEnded(round: 1, scores: (first: 5, second: 3)),
        const MatchEnded(
          outcome: MatchOutcome.firstWin,
          scores: (first: 9, second: 4),
          finalHashes: (first: 'a', second: 'b'),
        ),
      ]),
    );
    // Advance animation time in sub-300ms steps (larger jumps are ignored).
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('2 obstacole următoare!'), findsOneWidget);
    expect(find.text('ENERGIE MAXIMĂ!'), findsOneWidget);
    expect(find.text('MUTARE EXTRA!'), findsOneWidget);
    expect(find.text('Runda 1  •  5 – 3'), findsOneWidget);
    expect(find.text('VICTORIE!'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('every cell event type produces a board animation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    BoardPiece pc(int id, int kind) => BoardPiece(id: id, kind: kind);
    final initial = BoardSnapshot(
      width: 7,
      height: 7,
      cells: [
        for (var i = 0; i < 49; i++)
          BoardCell(piece: pc(i, i % 5)),
      ],
    );
    final key = GlobalKey<BoardViewState>();
    final fired = <BoardEvent>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 360,
              child: BoardView(
                key: key,
                initial: initial,
                onEvent: fired.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final state = key.currentState!;

    // One event per play; fx are created synchronously inside play(), so the
    // count proves each type scheduled a cell animation.
    final cases = <BoardEvent>[
      const Swapped(player: PlayerSlot.first, firstCell: 0, secondCell: 1),
      const SwapRejected(
        player: PlayerSlot.first,
        firstCell: 2,
        secondCell: 9,
        reason: 'blocked',
      ),
      const SpecialCreated(
        player: PlayerSlot.first,
        kind: SpecialKind.lineHorizontal,
        cell: 3,
      ),
      const Cleared(player: PlayerSlot.first, cells: [4, 5, 6], points: 30),
      const SpecialFired(
        player: PlayerSlot.first,
        kind: SpecialKind.bomb,
        cells: [7, 8, 9],
        points: 30,
      ),
      const PowerFired(
        player: PlayerSlot.first,
        power: PowerKind.laserChase,
        cells: [10, 11, 12],
        points: 30,
      ),
      const ObstacleLanded(
        player: PlayerSlot.first,
        cells: [20, 21],
        obstacle: ObstacleKind.slipper,
      ),
      const ObstacleBroken(player: PlayerSlot.first, cells: [20, 21]),
      const Fell(player: PlayerSlot.first, from: 40, to: 30),
      Refilled(player: PlayerSlot.first, cell: 40, piece: pc(200, 2)),
      Shuffled(
        player: PlayerSlot.first,
        cells: [0, 1, 2, 3, 4, 5, 6],
        reason: 'test',
        pieces: {
          0: pc(0, 0),
          1: pc(1, 1),
          2: pc(2, 2),
          3: pc(3, 3),
          4: pc(4, 4),
          5: pc(5, 0),
          6: pc(6, 1),
        },
      ),
    ];
    for (final e in cases) {
      final before = fired.length;
      final done = state.play([e]);
      expect(
        state.debugFxCount,
        greaterThan(0),
        reason: '$e produced no cell animation',
      );
      await tester.pumpAndSettle();
      await done;
      expect(fired.length, greaterThan(before), reason: '$e never fired');
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('power moment and frame probe render', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              PowerMoment(power: PowerKind.zoomies, t: 0.5),
              Positioned(
                left: 0,
                top: 0,
                width: 100,
                height: 100,
                child: FrameTimeOverlay(child: SizedBox.expand()),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('ZOOM!'), findsOneWidget);
    expect(find.byKey(const Key('power-moment-zoomies')), findsOneWidget);
    expect(find.byKey(const Key('frame-probe')), findsOneWidget);
    expect(find.textContaining('FPS'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  // ---------- slice 2: engine duel ----------

  test('adapter maps every engine event to a view event', () {
    final start = engine.newMatch(3, const engine.MatchConfig.duel());
    final state = (start as engine.EngineOk<engine.MatchState>).value;
    engine.CellPos c(int r, int col) => (row: r, col: col);
    final mr = engine.MoveResult(
      state: state,
      hashBefore: 'a',
      hashAfter: 'b',
      events: [
        engine.Swapped(
          player: engine.PlayerSlot.first,
          firstCell: c(0, 0),
          secondCell: c(0, 1),
        ),
        engine.SwapRejected(
          player: engine.PlayerSlot.first,
          firstCell: c(0, 0),
          secondCell: c(1, 0),
          reason: 'no-match',
        ),
        engine.Cleared(
          player: engine.PlayerSlot.first,
          cells: [c(0, 0), c(0, 1)],
          points: 20,
        ),
        engine.SpecialCreated(
          player: engine.PlayerSlot.first,
          kind: engine.SpecialKind.line,
          orientation: engine.LineOrientation.row,
          cell: c(2, 2),
        ),
        engine.SpecialCreated(
          player: engine.PlayerSlot.first,
          kind: engine.SpecialKind.bomb,
          orientation: null,
          cell: c(2, 3),
        ),
        engine.SpecialCreated(
          player: engine.PlayerSlot.first,
          kind: engine.SpecialKind.rainbow,
          orientation: null,
          cell: c(2, 4),
        ),
        engine.SpecialFired(
          player: engine.PlayerSlot.first,
          kind: engine.SpecialKind.bomb,
          cells: [c(3, 3)],
          points: 10,
        ),
        engine.Fell(
          player: engine.PlayerSlot.first,
          from: c(4, 4),
          to: c(5, 4),
        ),
        engine.Refilled(
          player: engine.PlayerSlot.first,
          cell: c(6, 6),
          piece: 2,
        ),
        engine.ObstacleQueued(
          player: engine.PlayerSlot.first,
          sourceRound: 1,
          count: 2,
        ),
        engine.ObstacleLanded(
          player: engine.PlayerSlot.first,
          cells: [c(0, 3)],
        ),
        engine.ObstacleBroken(
          player: engine.PlayerSlot.first,
          cells: [c(0, 4)],
        ),
        engine.PowerCharged(player: engine.PlayerSlot.first, amount: 40),
        engine.PowerFired(
          player: engine.PlayerSlot.first,
          power: engine.PowerKind.zoomies,
          cells: [c(1, 1)],
          points: 0,
        ),
        engine.PowerFired(
          player: engine.PlayerSlot.first,
          power: engine.PowerKind.shadowPounce,
          cells: [c(1, 2)],
          points: 15,
        ),
        engine.PowerFired(
          player: engine.PlayerSlot.first,
          power: engine.PowerKind.laserChase,
          cells: [c(1, 3)],
          points: 15,
        ),
        engine.Shuffled(
          player: engine.PlayerSlot.first,
          cells: [c(0, 0)],
          reason: 'no-moves',
        ),
        engine.ExtraMove(
          player: engine.PlayerSlot.first,
          round: 1,
          movesRemaining: 4,
        ),
        engine.RoundEnded(
          round: 1,
          scores: (first: 10, second: 5),
          outcome: null,
        ),
        engine.MatchEnded(
          outcome: engine.MatchOutcome.firstWins,
          scores: (first: 10, second: 5),
          finalHashes: (first: 'x', second: 'y'),
        ),
        // Opponent events never reach the human's board.
        engine.Swapped(
          player: engine.PlayerSlot.second,
          firstCell: c(0, 0),
          secondCell: c(0, 1),
        ),
        engine.Cleared(
          player: engine.PlayerSlot.second,
          cells: [c(0, 0)],
          points: 10,
        ),
      ],
    );
    final view = EngineViewAdapter(width: 7, height: 7).adaptMove(mr);
    expect(view.whereType<Swapped>(), hasLength(1));
    expect(view.whereType<SwapRejected>(), hasLength(1));
    expect(view.whereType<Cleared>(), hasLength(1));
    expect(view.whereType<SpecialCreated>(), hasLength(3));
    expect(view.whereType<SpecialFired>(), hasLength(1));
    expect(view.whereType<Fell>(), hasLength(1));
    expect(view.whereType<Refilled>(), hasLength(1));
    expect(view.whereType<ObstacleQueued>(), hasLength(1));
    expect(view.whereType<ObstacleLanded>(), hasLength(1));
    expect(view.whereType<ObstacleBroken>(), hasLength(1));
    expect(view.whereType<PowerCharged>(), hasLength(1));
    expect(view.whereType<PowerFired>(), hasLength(3));
    expect(view.whereType<Shuffled>(), hasLength(1));
    expect(view.whereType<ExtraMove>(), hasLength(1));
    expect(view.whereType<RoundEnded>(), hasLength(1));
    expect(view.whereType<MatchEnded>(), hasLength(1));
    // A non-final RoundEnded is followed by a BoardReset for the new deal.
    expect(view.whereType<BoardReset>(), hasLength(1));
    expect(
      view.whereType<SpecialCreated>().map((e) => e.kind),
      containsAll([
        SpecialKind.lineHorizontal,
        SpecialKind.bomb,
        SpecialKind.rainbow,
      ]),
    );
    expect(
      view.whereType<PowerFired>().map((e) => e.power),
      containsAll([
        PowerKind.zoomies,
        PowerKind.shadowPounce,
        PowerKind.laserChase,
      ]),
    );
    expect(view.whereType<Refilled>().single.piece.kind, 2);
    expect(view.whereType<MatchEnded>().single.outcome, MatchOutcome.firstWin);
  });

  test('real engine matches produce every special, power and obstacle', () {
    final specials = <engine.SpecialKind>{};
    final powers = <engine.PowerKind>{};
    var obstaclesQueued = false, obstaclesLanded = false;
    var matches = 0, powerPick = 0;
    for (
      var seed = 0;
      seed < 300 &&
      (specials.length < 3 ||
          powers.length < 2 ||
          !obstaclesQueued ||
          !obstaclesLanded);
      seed++
    ) {
      final start = engine.newMatch(seed, const engine.MatchConfig.duel());
      if (start is! engine.EngineOk<engine.MatchState>) continue;
      var state = start.value;
      var guard = 0;
      while (!state.isFinished && guard++ < 300) {
        final legal = engine.legalMoves(state);
        if (legal is! engine.EngineOk<List<engine.Move>>) break;
        final moves = legal.value;
        if (moves.isEmpty) break;
        // Fire powers whenever legal so charge gets spent; cycle kinds so
        // every power gets exercised, else take the first swap.
        final powerByKind = <engine.PowerKind, engine.PowerMove>{};
        for (final m in moves.whereType<engine.PowerMove>()) {
          powerByKind.putIfAbsent(m.power, () => m);
        }
        engine.Move mv;
        if (powerByKind.isNotEmpty) {
          final kinds = powerByKind.keys.toList()
            ..sort((a, b) => a.index.compareTo(b.index));
          mv = powerByKind[kinds[powerPick++ % kinds.length]]!;
        } else {
          mv = moves.first;
        }
        final res = engine.applyMove(state, mv);
        if (res is! engine.EngineOk<engine.MoveResult>) break;
        for (final e in res.value.events) {
          switch (e) {
            case engine.SpecialCreated(:final kind):
              specials.add(kind);
            case engine.PowerFired(:final power):
              powers.add(power);
            case engine.ObstacleQueued():
              obstaclesQueued = true;
            case engine.ObstacleLanded():
              obstaclesLanded = true;
            case _:
              break;
          }
        }
        state = res.value.state;
      }
      matches++;
    }
    expect(matches, greaterThan(0));
    expect(
      specials,
      containsAll([
        engine.SpecialKind.line,
        engine.SpecialKind.bomb,
        engine.SpecialKind.rainbow,
      ]),
    );
    expect(
      powers,
      containsAll([engine.PowerKind.zoomies, engine.PowerKind.shadowPounce]),
    );
    expect(obstaclesQueued, isTrue);
    expect(obstaclesLanded, isTrue);
  });

  test('move log replays to the same state hash', () {
    const config = engine.MatchConfig.duel();
    final start = engine.newMatch(99, config);
    var state = (start as engine.EngineOk<engine.MatchState>).value;
    final log = <engine.Move>[];
    var guard = 0;
    while (!state.isFinished && guard++ < 300) {
      final legal = engine.legalMoves(state);
      if (legal is! engine.EngineOk<List<engine.Move>>) break;
      final moves = legal.value;
      if (moves.isEmpty) break;
      final mv = moves.first;
      log.add(mv);
      state =
          ((engine.applyMove(
                    state,
                    mv,
                  )
                  as engine.EngineOk<engine.MoveResult>)
              .value)
          .state;
    }
    final rep = engine.replay(99, config, log);
    expect(rep, isA<engine.EngineOk<engine.ReplayResult>>());
    final rr = (rep as engine.EngineOk<engine.ReplayResult>).value;
    expect(rr.hash, engine.stateHash(state));
    expect(rr.movesApplied, log.length);
    expect(state.isFinished, isTrue);
  });

  testWidgets('engine duel plays five rounds of three moves to a result', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final p = Player(await SharedPreferences.getInstance());
    final m = ArenaMatchController(p, 0, botLevel: 1, seed: 42);
    addTearDown(m.dispose);
    // Drain events instantly so the tight loop does not wait on animations.
    m.eventSink = (_) => m.onBoardIdle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(m.phase, MatchPhase.playing);
    expect(m.isEngine, isTrue);
    expect(m.round, 1);
    expect(m.movesLeft, 3);
    var guard = 0;
    while (m.phase == MatchPhase.playing && guard++ < 80) {
      final swaps = m.legalSwaps;
      expect(swaps, isNotEmpty, reason: 'player turn with no legal swap');
      m.tryMove(swaps.first.$1, swaps.first.$2);
    }
    expect(m.phase, MatchPhase.finished);
    expect(m.result, isNotNull);
    // Five rounds of three accepted player moves minimum.
    expect(guard, greaterThanOrEqualTo(15));
  });

  testWidgets('full match against each house-cat level reaches result', (
    tester,
  ) async {
    for (final level in [0, 1, 2]) {
      SharedPreferences.setMockInitialValues({});
      final p = Player(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        MaterialApp(
          home: MatchScreen(player: p, mode: 0, botLevel: level),
        ),
      );
      final st = tester.state(find.byType(MatchScreen)) as dynamic;
      final m = st.match as ArenaMatchController;
      m.eventSink = (_) => m.onBoardIdle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      var guard = 0;
      while (m.phase == MatchPhase.playing && guard++ < 80) {
        final swaps = m.legalSwaps;
        expect(swaps, isNotEmpty);
        m.tryMove(swaps.first.$1, swaps.first.$2);
      }
      expect(m.phase, MatchPhase.finished, reason: 'level $level');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('REVANȘĂ'), findsOneWidget);
      expect(find.textContaining('BOT'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('bot is labelled on VS, match and result screens', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final p = Player(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      MaterialApp(home: MatchScreen(player: p, mode: 0, botLevel: 2)),
    );
    // VS screen: BOT tag, house-cat name and difficulty chip.
    expect(find.text('BOT'), findsWidgets);
    expect(find.text('Vulpița'), findsWidgets);
    expect(find.text('Greu'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 100));
    // Match screen: score strip carries the bot label.
    expect(find.textContaining('BOT'), findsWidgets);
    expect(find.text('Runda 1/5'), findsOneWidget);
    // Surrender to the result screen.
    await tester.tap(find.text('Renunță'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('RENUNȚĂ'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('BOT'), findsWidgets);
    expect(find.textContaining('Vulpița'), findsWidgets);
    expect(find.textContaining('5 runde'), findsOneWidget);
  });

  testWidgets('first-match tutorial guides three moves then persists', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final p = Player(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      MaterialApp(home: MatchScreen(player: p, mode: 0)),
    );
    final st = tester.state(find.byType(MatchScreen)) as dynamic;
    final m = st.match as ArenaMatchController;
    m.eventSink = (_) => m.onBoardIdle();
    await tester.pump(const Duration(seconds: 3));
    // Let the persisted tutorial flag load.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(m.tutorialActive, isTrue);
    expect(find.textContaining('Prima ta luptă'), findsOneWidget);
    expect(m.hintSwap, isNotNull);
    for (var i = 0; i < 3; i++) {
      final s = m.legalSwaps.first;
      m.tryMove(s.$1, s.$2);
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(m.tutorialActive, isFalse);
    expect(find.textContaining('Prima ta luptă'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('cpa_duel_tutorial_done'), isTrue);
  });

  testWidgets('rematch restarts the duel with a fresh seed', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final p = Player(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      MaterialApp(home: MatchScreen(player: p, mode: 0)),
    );
    final st = tester.state(find.byType(MatchScreen)) as dynamic;
    final m = st.match as ArenaMatchController;
    m.eventSink = (_) => m.onBoardIdle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(m.phase, MatchPhase.playing);
    final seedBefore = m.seed;
    await tester.tap(find.text('Renunță'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('RENUNȚĂ'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(m.phase, MatchPhase.finished);
    await tester.ensureVisible(find.text('REVANȘĂ'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('REVANȘĂ'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(m.phase, MatchPhase.searching);
    expect(m.result, isNull);
    expect(m.seed, isNot(seedBefore));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(m.phase, MatchPhase.playing);
    expect(m.round, 1);
    expect(m.movesLeft, 3);
  });
}

/// Records synthesized cue plays for assertions.
class _RecSfx implements SfxOutput {
  final plays = <({String asset, double volume, double rate})>[];

  @override
  void play(String asset, {required double volume, required double rate}) {
    plays.add((asset: asset, volume: volume, rate: rate));
  }

  @override
  Future<void> dispose() async {}
}

/// Compact row-major rendering: piece kind digit, 'X' obstacle, '.' empty.
String _grid(List<BoardCell> cells) => cells
    .map(
      (c) => c.obstacle != null
          ? 'X'
          : c.piece == null
          ? '.'
          : '${c.piece!.kind}',
    )
    .join();

const _expectedGrid =
    '3210401' // row 0: shuffled
    '2341223' // row 1: swap + refill
    '4012340' // row 2: refill
    '1234412' // row 3: fell piece lands on 25
    '341X234' // row 4: obstacle broke + refill + landed obstacle
    '0123401' // row 5
    '2340123'; // row 6
