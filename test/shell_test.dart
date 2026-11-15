import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:cat_paws_arena/main.dart';
import 'package:cat_paws_arena/profile.dart';
import 'package:cat_paws_arena/ui_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'artwork_test_support.dart';

void main() {
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

  testWidgets('profile edits close safely and preserve the player name', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final p = Player(await SharedPreferences.getInstance());
    await tester.pumpWidget(MaterialApp(home: Home(player: p)));
    await tester.tap(
      find.descendant(of: find.byType(PlayerHud), matching: find.text('Alex')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          )
          .first,
      'Mimi',
    );
    await tester.tap(find.text('SALVEAZĂ'));
    await tester.pumpAndSettle();
    expect(p.name, 'Mimi');
    expect(tester.takeException(), isNull);
  });

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
    final bottoms = [
      for (final price in ['8.99 LEI', '22.99 LEI', '44.99 LEI'])
        tester
            .getBottomLeft(
              find.ancestor(
                of: find.text(price),
                matching: find.byType(ArenaButton),
              ),
            )
            .dy,
    ];
    expect(bottoms[1], closeTo(bottoms[0], 0.1));
    expect(bottoms[2], closeTo(bottoms[0], 0.1));
    await tester.tap(find.text('8.99 LEI'));
    await tester.pumpAndSettle();
    expect(find.text('Google Play Billing'), findsOneWidget);
    expect(p.coins, 700);
    expect(tester.takeException(), isNull);
  });
}
