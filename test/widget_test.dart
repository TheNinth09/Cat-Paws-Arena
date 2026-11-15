import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:cat_paws_arena/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cat_paws_arena/arena.dart';
import 'package:cat_paws_arena/profile.dart';

void main() {
  testWidgets('portrait home and all five navigation tabs render', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final p = Player(await SharedPreferences.getInstance());
    await tester.pumpWidget(MaterialApp(home: Home(player: p)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final title in [
      'MAGAZIN',
      'PISICI',
      'ECHIPĂ',
      'EVENIMENTE',
      'LUPTĂ',
    ]) {
      await tester.tap(find.text(title).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: title);
    }
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
