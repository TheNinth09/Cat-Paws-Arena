import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arena_engine/arena_engine.dart' as engine;
import 'package:arena_engine/src/board.dart' as board;
import 'package:cat_paws_arena/board_game.dart';
import 'package:cat_paws_arena/duel_audio.dart';
import 'package:cat_paws_arena/duel_events.dart';
import 'package:cat_paws_arena/engine_events.dart';
import 'package:cat_paws_arena/match_controller.dart';
import 'package:cat_paws_arena/match_screen.dart';
import 'package:cat_paws_arena/online/emotes.dart';
import 'package:cat_paws_arena/online/fake_backend.dart';
import 'package:cat_paws_arena/online/match_store.dart';
import 'package:cat_paws_arena/online/match_sync.dart';
import 'package:cat_paws_arena/online/rooms.dart';
import 'package:cat_paws_arena/profile.dart';
import 'package:cat_paws_arena/shell/house_tour.dart';
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
            !name.startsWith('assets/images/') &&
            !name.startsWith('assets/fonts/') &&
            !name.startsWith('assets/audio/'),
      ),
      isEmpty,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Image(image: AssetImage('assets/images/studio_logo.png')),
          ),
        ),
      ),
    );
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
    // Simplified defeat: only the trophy change — no chest, no score strip.
    expect(find.text('-25 Trofee'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName.contains('icon_chest'),
      ),
      findsNothing,
    );
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
        sourceTurn: 0,
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
      const TurnEnded(
        turn: 1,
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
        .where((p) => p.asset == 'audio/sfx_match.wav')
        .map((p) => p.rate)
        .toList();
    expect(pops, hasLength(2));
    expect(pops[0], closeTo(1.12, 1e-9));
    expect(pops[1], closeTo(1.12, 1e-9));
    // The second clear in the chain plays the combo cue instead.
    final combos = out.plays
        .where((p) => p.asset == 'audio/sfx_combo_2.wav')
        .map((p) => p.rate)
        .toList();
    expect(combos, hasLength(1));
    expect(combos.single, closeTo(1.24, 1e-9));
    // A horizontal line special maps to the rocket cue.
    final specials = out.plays
        .where((p) => p.asset == 'audio/sfx_rocket.wav')
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
        const ObstacleQueued(player: PlayerSlot.first, sourceTurn: 0, count: 2),
        const PowerCharged(player: PlayerSlot.first, amount: 100),
        const TurnEnded(turn: 1, scores: (first: 5, second: 3)),
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
    expect(find.text('2 cutii următoare!'), findsOneWidget);
    // The charge banner was removed — the meter bar communicates it.
    expect(find.text('PUTERE MAXIMĂ!'), findsNothing);
    expect(find.text('Tura 1  •  5 – 3'), findsOneWidget);
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
        engine.SpecialCreated(
          player: engine.PlayerSlot.first,
          kind: engine.SpecialKind.copter,
          orientation: null,
          cell: c(1, 1),
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
          sourceTurn: 1,
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
        engine.TurnEnded(
          turn: 1,
          scores: (first: 10, second: 5),
          outcome: null,
        ),
        engine.MatchEnded(
          outcome: engine.MatchOutcome.firstWins,
          scores: (first: 10, second: 5),
          finalHashes: (first: 'x', second: 'y'),
        ),
        // Opponent board events animate on the shared board too.
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
    expect(view.whereType<Swapped>(), hasLength(2));
    expect(view.whereType<SwapRejected>(), hasLength(1));
    expect(view.whereType<Cleared>(), hasLength(2));
    expect(view.whereType<SpecialCreated>(), hasLength(4));
    expect(view.whereType<SpecialFired>(), hasLength(1));
    expect(view.whereType<Fell>(), hasLength(1));
    expect(view.whereType<Refilled>(), hasLength(1));
    expect(view.whereType<ObstacleQueued>(), hasLength(1));
    expect(view.whereType<ObstacleLanded>(), hasLength(1));
    expect(view.whereType<ObstacleBroken>(), hasLength(1));
    expect(view.whereType<PowerCharged>(), hasLength(1));
    expect(view.whereType<PowerFired>(), hasLength(3));
    expect(view.whereType<Shuffled>(), hasLength(1));
    expect(view.whereType<TurnEnded>(), hasLength(1));
    expect(view.whereType<MatchEnded>(), hasLength(1));
    // Timed turns keep persistent boards: no reset event is emitted.
    expect(view.whereType<BoardReset>(), isEmpty);
    expect(
      view.whereType<SpecialCreated>().map((e) => e.kind),
      containsAll([
        SpecialKind.lineHorizontal,
        SpecialKind.bomb,
        SpecialKind.copter,
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
    var obstaclesQueued = false,
        obstaclesLanded = false,
        obstaclesBroken = false;
    var matches = 0;
    // Rotate the loadout per seed so every configured power fires.
    final dedicated = <engine.ArenaBot>[
      const engine.PowerBot(),
      engine.RandomBot(99),
      const engine.GreedyBot(),
    ];
    for (
      var seed = 0;
      seed < 600 &&
          (specials.length < engine.SpecialKind.values.length ||
              powers.length < engine.PowerKind.values.length ||
              !obstaclesQueued ||
              !obstaclesLanded ||
              !obstaclesBroken);
      seed++
    ) {
      final config = engine.MatchConfig(
        firstPower: engine.PowerKind.values[seed % 3],
        secondPower: engine.PowerKind.values[(seed * 7 + 1) % 3],
      );
      final start = engine.newMatch(seed, config);
      if (start is! engine.EngineOk<engine.MatchState>) continue;
      var state = start.value;
      final botA = dedicated[seed % dedicated.length];
      final botB = engine.RandomBot(seed * 31 + 7);
      var guard = 0;
      while (!state.isFinished && guard++ < 400) {
        final bot = state.activePlayer == engine.PlayerSlot.first ? botA : botB;
        final mv = bot.chooseMove(state);
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
            case engine.ObstacleBroken():
              obstaclesBroken = true;
            case _:
              break;
          }
        }
        state = res.value.state;
      }
      matches++;
    }
    expect(matches, greaterThan(0));
    expect(specials, containsAll(engine.SpecialKind.values));
    expect(powers, containsAll(engine.PowerKind.values));
    expect(obstaclesQueued, isTrue);
    expect(obstaclesLanded, isTrue);
    expect(obstaclesBroken, isTrue);
  });

  test('move log replays to the same state hash', () {
    const config = engine.MatchConfig.duel();
    final start = engine.newMatch(99, config);
    var state = (start as engine.EngineOk<engine.MatchState>).value;
    final log = <engine.Move>[];
    var guard = 0, swapsInTurn = 0;
    while (!state.isFinished && guard++ < 300) {
      final legal = engine.legalMoves(state);
      if (legal is! engine.EngineOk<List<engine.Move>>) break;
      final swaps = [
        for (final m in legal.value)
          if (m is engine.SwapMove) m,
      ];
      // A few swaps per turn, then an explicit EndTurnMove — the timed-
      // turn model only hands the turn over through the move log.
      final mv = (swaps.isNotEmpty && swapsInTurn < 4)
          ? swaps.first as engine.Move
          : const engine.EndTurnMove();
      log.add(mv);
      swapsInTurn = mv is engine.EndTurnMove ? 0 : swapsInTurn + 1;
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

  /// Plays a local engine duel to the result: up to [swapsPerTurn] swaps
  /// per turn, then ends the turn programmatically; the house bot paces
  /// itself on a zero delay.
  Future<void> driveLocalMatch(
    WidgetTester tester,
    ArenaMatchController m, {
    int swapsPerTurn = 4,
  }) async {
    m.botMoveDelay = Duration.zero;
    var guard = 0, swaps = 0;
    while (m.phase == MatchPhase.playing && guard++ < 900) {
      if (m.playerTurn) {
        final legal = m.legalSwaps;
        if (swaps < swapsPerTurn && legal.isNotEmpty && m.acceptingInput) {
          m.tryMove(legal.first.$1, legal.first.$2);
          swaps++;
        } else {
          m.endTurn();
          swaps = 0;
        }
      } else {
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pump(const Duration(milliseconds: 5));
    }
    expect(m.phase, MatchPhase.finished, reason: 'match did not finish');
  }

  testWidgets('engine duel plays three timed turns per player to a result', (
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
    expect(m.turn, 1);
    expect(m.playerTurn, isTrue);
    expect(m.turnSecondsLeft, greaterThan(0));
    expect(m.turnSecondsLeft, lessThanOrEqualTo(15));
    expect(m.playerTurnsLeft, 3);
    expect(m.botTurnsLeft, 3);
    // End the first turn early: the turn flips to the bot.
    m.endTurn();
    await tester.pump(const Duration(milliseconds: 50));
    expect(m.turn, 2);
    expect(m.playerTurn, isFalse);
    // Drive the rest of the match to a scored result.
    await driveLocalMatch(tester, m);
    expect(m.result, isNotNull);
    // Three turns each = six turn boundaries minimum.
    expect(m.turn, greaterThanOrEqualTo(5));
  });

  testWidgets('battle UI shows the turn clock and has no GATA button', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final p = Player(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      MaterialApp(home: MatchScreen(player: p, mode: 0, botLevel: 0)),
    );
    final st = tester.state(find.byType(MatchScreen)) as dynamic;
    final m = st.match as ArenaMatchController;
    m.eventSink = (_) => m.onBoardIdle();
    m.botMoveDelay = const Duration(seconds: 10);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(m.phase, MatchPhase.playing);
    // No end-early control: the 30 s timer owns turn boundaries.
    expect(find.text('GATA'), findsNothing);
    // Turn indicator + seconds are visible in the HUD.
    expect(find.textContaining('Tura 1/'), findsWidgets);
    expect(find.textContaining('s'), findsWidgets);
    expect(find.textContaining('RÂNDUL TĂU'), findsOneWidget);
    m.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('tapping the opponent portrait shows their details', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final p = Player(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      MaterialApp(home: MatchScreen(player: p, mode: 0, botLevel: 0)),
    );
    final st = tester.state(find.byType(MatchScreen)) as dynamic;
    final m = st.match as ArenaMatchController;
    m.eventSink = (_) => m.onBoardIdle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(m.phase, MatchPhase.playing);
    // No BOT tag beside the name anymore — tapping the portrait plate
    // (the name text sits inside its gesture area) opens the details.
    await tester.tap(find.text('Pisi Fundal').first);
    await tester.pump(const Duration(milliseconds: 300));
    // The popup shows match-provided details only: BOT label + trophies.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('trofee'), findsWidgets);
    expect(find.text('BOT'), findsWidgets);
    m.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('turn clock auto-ends an idle turn', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final p = Player(await SharedPreferences.getInstance());
    final m = ArenaMatchController(p, 0, botLevel: 0, seed: 7);
    addTearDown(m.dispose);
    m.eventSink = (_) => m.onBoardIdle();
    // Slow bot pacing keeps the turn on the bot after the auto-end.
    m.botMoveDelay = const Duration(seconds: 10);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(m.phase, MatchPhase.playing);
    expect(m.turn, 1);
    // Let the 15-second clock run out without input.
    await tester.pump(const Duration(seconds: 16));
    await tester.pump(const Duration(milliseconds: 50));
    // The turn ended by itself and play moved to the bot.
    expect(m.turn, 2);
    expect(m.playerTurn, isFalse);
    // Dispose inline: the pending-timer invariant runs before teardown.
    m.dispose();
  });

  testWidgets('power meter caps at 100 and tapping it fires the power', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    // Drive real matches until the player's meter fills; the first seed
    // that reaches 100% proves cap + tap-to-fire end to end.
    var fired = false;
    for (var seed = 0; seed < 30 && !fired; seed++) {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final p = Player(prefs)..power = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MatchScreen(player: p, mode: 0, botLevel: 0, seed: seed),
        ),
      );
      final st = tester.state(find.byType(MatchScreen)) as dynamic;
      final m = st.match as ArenaMatchController;
      m.eventSink = (_) => m.onBoardIdle();
      m.botMoveDelay = Duration.zero;
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      var guard = 0, swaps = 0, tapped = false;
      while (m.phase == MatchPhase.playing && guard++ < 900 && !fired) {
        if (m.playerTurn) {
          expect(
            m.playerCharge,
            lessThanOrEqualTo(100),
            reason: 'meter exceeded the 100% cap',
          );
          if (!tapped && m.playerCharge >= 100) {
            tapped = true;
            await tester.tap(find.byKey(const Key('power-meter')));
            await tester.pump(const Duration(milliseconds: 80));
            // A successful fire drains the meter back below full.
            if (m.playerCharge < 100) fired = true;
          }
          final legal = m.legalSwaps;
          if (swaps < 4 && legal.isNotEmpty && m.acceptingInput) {
            m.tryMove(legal.first.$1, legal.first.$2);
            swaps++;
          } else {
            m.endTurn();
            swaps = 0;
          }
        } else {
          await tester.pump(const Duration(milliseconds: 10));
        }
        await tester.pump(const Duration(milliseconds: 5));
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
    expect(fired, isTrue, reason: 'no seed filled the meter to 100%');
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
      await driveLocalMatch(tester, m);
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
    // VS screen: the offline-practice pill labels the bot, the card
    // carries only the cat's name and the difficulty chip.
    expect(find.text('ANTRENAMENT OFFLINE'), findsWidgets);
    expect(find.text('Vulpița'), findsWidgets);
    expect(find.text('Greu'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 100));
    // Match screen: the portrait header keeps the name clean — the bot
    // label lives on the details popup (tap the opponent name).
    expect(find.textContaining('BOT'), findsNothing);
    expect(find.textContaining('Tura 1'), findsWidgets);
    await tester.tap(find.text('Vulpița').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('BOT'), findsWidgets);
    await tester.tapAt(Offset.zero);
    await tester.pump(const Duration(milliseconds: 300));
    // Surrender to the result screen.
    await tester.tap(find.text('Renunță'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('RENUNȚĂ'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('BOT'), findsWidgets);
    expect(find.textContaining('Vulpița'), findsWidgets);
    expect(find.textContaining('3 turnuri'), findsOneWidget);
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

  testWidgets('house-cat opponent replaces the rotating bot', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final p = Player(await SharedPreferences.getInstance());
    const cat = HouseCat(
      id: 'living-misu',
      name: 'Misu',
      room: 0,
      level: 7,
      trophies: 45,
      fur: 1,
      eyes: 1,
      ears: 0,
      pattern: 0,
    );
    await tester.pumpWidget(
      MaterialApp(home: MatchScreen(player: p, mode: 0, opponent: cat)),
    );
    final st = tester.state(find.byType(MatchScreen)) as dynamic;
    final m = st.match as ArenaMatchController;
    expect(m.opponent, isNotNull);
    expect(m.botName, 'Misu');
    expect(m.botTrophies, 45);
    expect(m.botLevel, 1); // level 7 -> medium bucket
    // VS screen: cat name, offline-practice label, no difficulty chips.
    expect(find.text('Misu'), findsWidgets);
    expect(find.text('ANTRENAMENT OFFLINE'), findsWidgets);
    expect(find.text('Greu'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 100));
    // Match screen keeps the opponent labelled — the name plate is
    // clean; the BOT tag is on the details popup, not beside the name.
    expect(find.textContaining('Misu'), findsWidgets);
    expect(find.textContaining('BOT'), findsNothing);
    await tester.tap(find.text('Misu').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('BOT'), findsWidgets);
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
    expect(m.turn, 1);
    expect(m.playerTurn, isTrue);
  });

  // --- online friend duel (lane-5 MatchSession over FakeCloud) -----------

  /// Creates a room, joins it and opens both match sessions — the same
  /// path lane 4's lobby will use with `OnlineServices`.
  Future<(FakeCloud, MatchSession, MatchSession, String)> startOnlineMatch([
    int seed = 7,
  ]) async {
    final cloud = FakeCloud(random: Random(seed));
    final rooms = RoomService(cloud, random: Random(seed));
    final room = await rooms.createRoom('host');
    final joined = await rooms.joinRoom(room.code, 'guest');
    return (
      cloud,
      await MatchSession.open(cloud, joined.matchId, 'host'),
      await MatchSession.open(cloud, joined.matchId, 'guest'),
      joined.matchId,
    );
  }

  OnlineDuel onlineDuel(
    MatchSession session,
    FakeCloud cloud,
    String uid,
    String opponentName,
  ) => OnlineDuel(
    session: session,
    cloud: cloud,
    uid: uid,
    opponent: OnlineOpponentInfo(
      name: opponentName,
      trophies: 100,
      cat: 'Custom',
    ),
  );

  /// Drives both clients until finished: whoever can move plays up to four
  /// swaps then ends the turn; stream deliveries are flushed with pumps.
  Future<void> playOnlineMatch(
    WidgetTester tester,
    ArenaMatchController a,
    ArenaMatchController b,
  ) async {
    var guard = 0, stalls = 0;
    var aSwaps = 0, bSwaps = 0, aTurn = -1, bTurn = -1;
    while ((a.phase == MatchPhase.playing ||
            b.phase == MatchPhase.playing) &&
        guard++ < 900) {
      if (a.turn != aTurn) {
        aTurn = a.turn;
        aSwaps = 0;
      }
      if (b.turn != bTurn) {
        bTurn = b.turn;
        bSwaps = 0;
      }
      if (a.playerTurn && aSwaps < 4) {
        stalls = 0;
        final s = a.legalSwaps.first;
        a.tryMove(s.$1, s.$2);
        aSwaps++;
      } else if (b.playerTurn && bSwaps < 4) {
        stalls = 0;
        final s = b.legalSwaps.first;
        b.tryMove(s.$1, s.$2);
        bSwaps++;
      } else if (a.playerTurn) {
        stalls = 0;
        a.endTurn();
      } else if (b.playerTurn) {
        stalls = 0;
        b.endTurn();
      } else {
        stalls++;
        expect(
          stalls,
          lessThan(120),
          reason: 'deadlock: neither client can move',
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 5));
    }
    // Let finals propagate through watchMatch and rewards settle.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('online duel: two clients converge on hash, score and rewards', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final pA = Player(prefs)..name = 'Andrei';
    final pB = Player(prefs)..name = 'Maria';
    final (cloud, host, guest, _) = await startOnlineMatch(11);
    final mA = ArenaMatchController(
      pA,
      0,
      online: onlineDuel(host, cloud, 'host', 'Maria'),
    );
    final mB = ArenaMatchController(
      pB,
      0,
      online: onlineDuel(guest, cloud, 'guest', 'Andrei'),
    );
    addTearDown(mA.dispose);
    addTearDown(mB.dispose);
    mA.eventSink = (_) => mA.onBoardIdle();
    mB.eventSink = (_) => mB.onBoardIdle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump();
    expect(mA.phase, MatchPhase.playing);
    expect(mB.phase, MatchPhase.playing);
    expect(mA.isOnline, isTrue);
    expect(mA.botName, 'Maria');
    expect(mB.botName, 'Andrei');
    expect(mA.botLevelName, 'Prieten');

    await playOnlineMatch(tester, mA, mB);

    expect(mA.phase, MatchPhase.finished);
    expect(mB.phase, MatchPhase.finished);
    expect(mA.abortReason, isNull);
    expect(mB.abortReason, isNull);
    expect(mA.isFlagged, isFalse);
    expect(mB.isFlagged, isFalse);
    // Both clients replayed the same log to the same state.
    expect(mA.stateHashForTest, isNotNull);
    expect(mA.stateHashForTest, mB.stateHashForTest);
    expect(mA.playerScore, mB.botScore);
    expect(mA.botScore, mB.playerScore);
    expect(mA.result, isNotNull);
    expect(mB.result, isNotNull);
    expect(mA.result, -mB.result!);
    // Both finals agreed and nobody flagged: rewards were awarded.
    expect(mA.rewardsCounted, isTrue);
    expect(mB.rewardsCounted, isTrue);
    final expected = switch (mA.result) {
      1 => 30,
      -1 => 0, // loss floors trophies at 0
      _ => 0,
    };
    expect(pA.trophies, expected);
  });

  testWidgets('tampered online move flags the duel and awards nothing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final pA = Player(prefs)..name = 'Andrei';
    final pB = Player(prefs)..name = 'Maria';
    final trophiesBeforeA = pA.trophies, coinsBeforeA = pA.coins;
    final trophiesBeforeB = pB.trophies, coinsBeforeB = pB.coins;
    final (cloud, host, guest, matchId) = await startOnlineMatch(12);
    final mA = ArenaMatchController(
      pA,
      0,
      online: onlineDuel(host, cloud, 'host', 'Maria'),
    );
    final mB = ArenaMatchController(
      pB,
      0,
      online: onlineDuel(guest, cloud, 'guest', 'Andrei'),
    );
    addTearDown(mA.dispose);
    addTearDown(mB.dispose);
    mA.eventSink = (_) => mA.onBoardIdle();
    mB.eventSink = (_) => mB.onBoardIdle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump();

    // Host opens the match with one clean move.
    var guard = 0;
    while (!mA.acceptingInput && guard++ < 200) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    final swap = mA.legalSwaps.first;
    mA.tryMove(swap.$1, swap.$2);
    guard = 0;
    while ((host.movesApplied < 1 || guest.movesApplied < 1) &&
        guard++ < 200) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(host.movesApplied, 1);
    expect(guest.movesApplied, 1);

    // Forge the guest's next log entry: a legal move with a bogus hash.
    final legal = engine.legalMoves(guest.state);
    expect(legal, isA<engine.EngineOk<List<engine.Move>>>());
    final move = (legal as engine.EngineOk<List<engine.Move>>).value.first;
    await cloud.appendMove(
      matchId,
      MoveRecord(
        index: 1,
        uid: 'guest',
        slot: engine.PlayerSlot.second,
        move: move.toJson(),
        hashAfter: '0000000000000000',
        next: engine.PlayerSlot.first,
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(mA.phase, MatchPhase.finished);
    expect(mA.isFlagged, isTrue);
    expect(mA.rewardsCounted, isFalse);
    expect(pA.trophies, trophiesBeforeA);
    expect(pA.coins, coinsBeforeA);
    // The guest's session flags the same entry symmetrically.
    expect(mB.isFlagged, isTrue);
    expect(mB.rewardsCounted, isFalse);
    expect(pB.trophies, trophiesBeforeB);
    expect(pB.coins, coinsBeforeB);
  });

  testWidgets('online emotes reach only the opponent', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final pA = Player(prefs)..name = 'Andrei';
    final pB = Player(prefs)..name = 'Maria';
    final (cloud, host, guest, _) = await startOnlineMatch(13);
    final mA = ArenaMatchController(
      pA,
      0,
      online: onlineDuel(host, cloud, 'host', 'Maria'),
    );
    final mB = ArenaMatchController(
      pB,
      0,
      online: onlineDuel(guest, cloud, 'guest', 'Andrei'),
    );
    addTearDown(mA.dispose);
    addTearDown(mB.dispose);
    final gotByB = <Emote>[];
    final gotByA = <Emote>[];
    final subB = mB.opponentEmotes.listen(gotByB.add);
    final subA = mA.opponentEmotes.listen(gotByA.add);
    addTearDown(() => subB.cancel());
    addTearDown(() => subA.cancel());
    await tester.pump();

    mA.sendEmote(Emote.purr);
    mB.sendEmote(Emote.goodGame);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(gotByB, [Emote.purr]);
    expect(gotByA, [Emote.goodGame]);
    // Dispose inside the body: pending versus/poll timers must not leak
    // past the test's invariant check.
    mA.dispose();
    mB.dispose();
  });

  testWidgets('online VS shows the friend and surrender awards nothing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final p = Player(prefs)..name = 'Andrei';
    final trophiesBefore = p.trophies, coinsBefore = p.coins;
    final (cloud, host, _, _) = await startOnlineMatch(14);
    // Only this client's session is needed for the VS/result flow; the
    // screen builds its own controller around the same OnlineDuel.
    final duel = onlineDuel(host, cloud, 'host', 'Maria');
    await tester.pumpWidget(
      MaterialApp(home: MatchScreen(player: p, mode: 0, online: duel)),
    );
    final st = tester.state(find.byType(MatchScreen)) as dynamic;
    final m = st.match as ArenaMatchController;
    // VS screen: friend labels, opponent name, no BOT or difficulty chips.
    expect(find.text('PRIETEN ONLINE'), findsOneWidget);
    expect(find.text('PRIETEN'), findsWidgets);
    expect(find.text('Maria'), findsWidgets);
    expect(find.textContaining('Prieten'), findsWidgets);
    expect(find.text('BOT'), findsNothing);
    expect(find.text('Greu'), findsNothing);
    expect(find.text('Mediu'), findsNothing);
    expect(find.text('Ușor'), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 100));
    expect(m.phase, MatchPhase.playing);
    expect(find.textContaining('BOT'), findsNothing);

    // Surrender: the match is voided, no rewards, no rematch button.
    await tester.tap(find.text('Renunță'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('RENUNȚĂ'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(m.phase, MatchPhase.finished);
    expect(m.abortReason, OnlineAbort.surrendered);
    expect(find.text('MECI ÎNTRERUPT'), findsOneWidget);
    expect(find.textContaining('Fără trofee'), findsWidgets);
    expect(find.text('REVANȘĂ'), findsNothing);
    expect(p.trophies, trophiesBefore);
    expect(p.coins, coinsBefore);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  // ---------- shared-board rapid-duel rules (3 × 15 s) ----------

  group('shared-board rapid duel rules', () {
    engine.MatchState stateWithCells(
      List<int> cells, {
      engine.PlayerSlot active = engine.PlayerSlot.first,
    }) {
      const w = 7, h = 7;
      final board = engine.BoardState(
        w,
        h,
        List<int>.of(cells),
        List<int>.filled(w, 0),
      );
      return engine.MatchState.create(
        seed: 11,
        config: const engine.MatchConfig.duel(),
        turn: 1,
        activePlayer: active,
        turnsRemaining: const [3, 3],
        turnMoves: 0,
        scores: const [0, 0],
        boards: [board, board],
        pendingObstacles: const [[], []],
        powerCharge: const [0, 0],
        rngState: const [1, 1],
      );
    }

    List<int> checker() => [
      for (var r = 0; r < 7; r++)
        for (var c = 0; c < 7; c++) (r + c) % 2,
    ];

    engine.CellPos pos(int i) => (row: i ~/ 7, col: i % 7);

    test('duel config is three 15-second turns per player', () {
      const cfg = engine.MatchConfig.duel();
      expect(cfg.turnsPerPlayer, 3);
      expect(cfg.turnSeconds, 15);
    });

    test('both slots share one board: each move lands on both views', () {
      // Swap (9,10): the 0 landing on cell 9 completes a row-3 of 0s.
      final cells = checker();
      cells[7] = 0;
      cells[8] = 0;
      cells[9] = 2;
      cells[10] = 0;
      cells[11] = 0;
      final st = stateWithCells(cells);
      final res = engine.applyMove(
        st,
        engine.SwapMove(firstCell: pos(9), secondCell: pos(10)),
      );
      expect(res, isA<engine.EngineOk<engine.MoveResult>>());
      final next = (res as engine.EngineOk<engine.MoveResult>).value.state;
      // The shared board: both slots' board snapshots are identical.
      expect(next.boards[0].cells, next.boards[1].cells);
    });

    test('tapping a special does not detonate it', () {
      final cells = checker();
      cells[24] = board.kCopter; // kCopter in the centre
      final st = stateWithCells(cells);
      final res = engine.applyMove(
        st,
        engine.SwapMove(firstCell: pos(24), secondCell: pos(24)),
      );
      expect(res, isA<engine.EngineFailure<engine.MoveResult>>());
      expect(st.boardOf(engine.PlayerSlot.first).cells[24], board.kCopter);
    });

    test('a special fires when swapped onto a piece of its colour', () {
      final cells = checker();
      cells[24] = board.kCopter; // colour-0 copter
      cells[25] = 0; // matching colour piece next to it
      final st = stateWithCells(cells);
      final res = engine.applyMove(
        st,
        engine.SwapMove(firstCell: pos(24), secondCell: pos(25)),
      );
      expect(res, isA<engine.EngineOk<engine.MoveResult>>());
      final out = (res as engine.EngineOk<engine.MoveResult>).value;
      expect(
        out.events.whereType<engine.SpecialFired>().isNotEmpty,
        isTrue,
        reason: 'a same-colour swap must fire the special',
      );
      expect(out.state.scores[0], greaterThan(0));
    });

    test('special + off-colour swap without a match is rejected', () {
      final cells = checker();
      cells[0] = board.kBomb; // colour-0 bomb next to a colour-1 piece
      final st = stateWithCells(cells);
      final res = engine.applyMove(
        st,
        engine.SwapMove(firstCell: pos(0), secondCell: pos(1)),
      );
      final out = (res as engine.EngineOk<engine.MoveResult>).value;
      expect(out.events.single, isA<engine.SwapRejected>());
      expect(out.hashAfter, out.hashBefore);
    });

    test('rocket + rocket combo clears a full cross', () {
      final cells = checker();
      cells[16] = board.kLineRow;
      cells[17] = board.kLineColumn;
      final st = stateWithCells(cells);
      final res = engine.applyMove(
        st,
        engine.SwapMove(firstCell: pos(16), secondCell: pos(17)),
      );
      final out = (res as engine.EngineOk<engine.MoveResult>).value;
      final fired = out.events.whereType<engine.SpecialFired>().toList();
      expect(fired, isNotEmpty);
      // Cross at the second cell: full row 2 + full column 3 = 13 cells.
      expect(fired.first.cells.length, greaterThanOrEqualTo(13));
      expect(out.state.scores[0], greaterThanOrEqualTo(130));
    });

    test('rainbow + rainbow clears the whole board', () {
      final cells = checker();
      cells[24] = board.kRainbow;
      cells[25] = board.kRainbow;
      final st = stateWithCells(cells);
      final res = engine.applyMove(
        st,
        engine.SwapMove(firstCell: pos(24), secondCell: pos(25)),
      );
      final out = (res as engine.EngineOk<engine.MoveResult>).value;
      final fired = out.events.whereType<engine.SpecialFired>().toList();
      expect(fired, isNotEmpty);
      expect(fired.first.cells.length, greaterThanOrEqualTo(49));
    });

    test('a 2x2 square creates a copter', () {
      final cells = checker();
      // Craft a clean 2x2 of 0s at r2-3 × c2-3 via swap(24,31).
      cells[10] = 2; // break c3 run above the square
      cells[16] = 0;
      cells[17] = 0;
      cells[18] = 2;
      cells[22] = 2; // break r3 run left of the square
      cells[23] = 0;
      cells[24] = 2; // placeholder that swaps out for the donor 0
      cells[25] = 2;
      cells[30] = 2; // break the c2 run below the square
      cells[31] = 0; // donor: the 0 lands on cell 24, closing the square
      final st = stateWithCells(cells);
      final res = engine.applyMove(
        st,
        engine.SwapMove(firstCell: pos(24), secondCell: pos(31)),
      );
      final out = (res as engine.EngineOk<engine.MoveResult>).value;
      expect(
        out.events
            .whereType<engine.SpecialCreated>()
            .any((e) => e.kind == engine.SpecialKind.copter),
        isTrue,
        reason: 'a 2x2 square must create the mouse copter',
      );
    });

    test('firing a special queues sabotage boxes for the opponent', () {
      final cells = checker();
      cells[24] = board.kBomb; // colour-0 bomb
      cells[25] = 0; // matching colour piece fires it
      final st = stateWithCells(cells);
      final res = engine.applyMove(
        st,
        engine.SwapMove(firstCell: pos(24), secondCell: pos(25)),
      );
      final out = (res as engine.EngineOk<engine.MoveResult>).value;
      final queued = out.events.whereType<engine.ObstacleQueued>().toList();
      expect(queued, isNotEmpty);
      expect(queued.first.player, engine.PlayerSlot.second);
      expect(queued.first.count, inInclusiveRange(1, 2));
    });
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
