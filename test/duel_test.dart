import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cat_paws_arena/main.dart';
import 'package:cat_paws_arena/board_game.dart';
import 'package:cat_paws_arena/duel_events.dart';
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
            !name.startsWith('assets/fonts/'),
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
