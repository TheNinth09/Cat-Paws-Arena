import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cat_paws_arena/main.dart';
import 'package:cat_paws_arena/board_game.dart';
import 'package:cat_paws_arena/duel_audio.dart';
import 'package:cat_paws_arena/duel_events.dart';
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
        reason: SwapRejectReason.noMatch,
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
        reason: SwapRejectReason.noMatch,
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
      const ExtraMove(player: PlayerSlot.first, round: 0, movesRemaining: 3),
      const RoundEnded(
        round: 0,
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
        .where((p) => p.asset == 'audio/sfx_pop.wav')
        .map((p) => p.rate)
        .toList();
    expect(pops, hasLength(3));
    expect(pops[0], closeTo(1.12, 1e-9));
    expect(pops[1], closeTo(1.24, 1e-9));
    expect(pops[2], closeTo(1.12, 1e-9));
    final specials = out.plays
        .where((p) => p.asset == 'audio/sfx_special.wav')
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
        const RoundEnded(round: 0, scores: (first: 5, second: 3)),
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
        reason: SwapRejectReason.blocked,
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
