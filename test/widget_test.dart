import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:cat_paws_arena/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cat_paws_arena/arena.dart';
import 'package:cat_paws_arena/profile.dart';
import 'package:cat_paws_arena/ui_widgets.dart';

void main() {
  void expectCleanArtwork(WidgetTester tester) {
    final assets = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .whereType<AssetImage>()
        .map((image) => image.assetName);
    expect(
      assets.where(
        (name) =>
            name.startsWith('assets/ui_') ||
            name.contains('loading_screen_clean'),
      ),
      isEmpty,
    );
  }

  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('clean adaptive navigation $size scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final p = Player(await SharedPreferences.getInstance())
          ..name = 'AlexandruNumeFoarteLung'
          ..trophies = 1500
          ..coins = 123456789
          ..cat = 'Custom';
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Home(player: p),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final tab in [0, 1, 3, 4, 2]) {
          await tester.tap(find.byKey(ValueKey('nav-$tab')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'tab $tab');
          expect(find.byType(PlayerHud), findsOneWidget);
          expect(find.byType(ArenaBottomBar), findsOneWidget);
          expectCleanArtwork(tester);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  testWidgets('shop reward and IAP cards are real interactive widgets', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final p = Player(await SharedPreferences.getInstance());
    await tester.pumpWidget(MaterialApp(home: Home(player: p)));
    await tester.tap(find.byKey(const ValueKey('nav-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+200 Lăbuțe'));
    await tester.pumpAndSettle();
    expect(p.coins, 700);
    await tester.scrollUntilVisible(
      find.text('8.99 LEI'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('8.99 LEI')),
      alignment: 0.3,
    );
    await tester.pumpAndSettle();
    expect(find.text('8.99 LEI').hitTestable(), findsOneWidget);
    await tester.tap(find.text('8.99 LEI'));
    await tester.pumpAndSettle();
    expect(find.text('Google Play Billing'), findsOneWidget);
    expect(p.coins, 700);
    expect(tester.takeException(), isNull);
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
  test('bot moves resolve cascades and recover blocked boards', () {
    final board = MatchBoard(seed: 17);
    for (var turn = 0; turn < 150; turn++) {
      if (turn % 3 == 0) board.obstacle();
      board.autoMove();
      expect(board.matches(), isEmpty);
      expect(board.hasMove, true);
      expect(board.cells.contains(-2), false);
      expect(board.charge, inInclusiveRange(0, 100));
    }
    expect(board.score, greaterThan(0));
  });
  test('boards start without matches and always have a legal move', () {
    for (var seed = 0; seed < 200; seed++) {
      final board = MatchBoard(seed: seed);
      expect(board.cells.length, 49);
      expect(board.matches(), isEmpty);
      expect(board.hasMove, isTrue);
    }
  });
  test('nonadjacent and nonmatching swaps do not mutate the board', () {
    final board = MatchBoard(seed: 7);
    final before = List<int>.from(board.cells);
    expect(board.swap(6, 7), isFalse);
    expect(board.swap(-1, 0), isFalse);
    expect(board.cells, before);
  });
  test('line detection, cascades, charge and four-match attacks', () {
    final board = MatchBoard(seed: 1);
    board.cells.setRange(0, 4, [2, 2, 2, 2]);
    final found = board.matches();
    expect(found.containsAll([0, 1, 2, 3]), isTrue);
    board.clear(found, 2);
    expect(board.score, found.length * 20);
    expect(board.charge, greaterThan(0));
    expect(board.attacks, 1);
    board.fall();
    expect(board.cells.contains(-2), isFalse);
  });
  test('obstacles clear next to a match', () {
    final board = MatchBoard(seed: 3);
    board.cells.setRange(0, 4, [1, 1, 1, -1]);
    board.clear({0, 1, 2}, 1);
    expect(board.cells[3], -2);
  });
  test('rewards, daily limits, purchases, tiers and persistence', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final p = Player(prefs);
    expect(p.claimDaily(), true);
    expect(p.claimDaily(), false);
    expect(p.coins, 700);
    expect(p.buy('hat', 300), true);
    expect(p.buy('hat', 300), false);
    expect(p.buy('expensive', 999), false);
    p.result(-1);
    expect(p.trophies, 0);
    p.trophies = 290;
    p.result(1);
    expect(p.tier, 1);
    expect(p.trophies, 320);
    expect(p.coins, 550);
    p.result(0);
    expect(p.trophies, 320);
    await p.save();
    final restored = Player(prefs);
    expect(restored.coins, p.coins);
    expect(restored.owned, contains('hat'));
    expect(restored.daily, p.today);
  });
}
