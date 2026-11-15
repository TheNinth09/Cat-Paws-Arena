import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:cat_paws_arena/events_screen.dart';
import 'package:cat_paws_arena/main.dart';
import 'package:cat_paws_arena/profile.dart';
import 'package:cat_paws_arena/shell/app_info.dart';
import 'package:cat_paws_arena/team_screen.dart';
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
          ..cat = 'Custom'
          ..english = true;
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
        for (final tab in [0, 1, 2]) {
          expect(find.byKey(ValueKey('nav-$tab')), findsOneWidget);
        }
        expect(find.byKey(const ValueKey('nav-3')), findsNothing);
        expect(find.byKey(const ValueKey('nav-4')), findsNothing);
        expect(find.text('SHOP'), findsOneWidget);
        expect(find.text('CATS'), findsOneWidget);
        expect(find.text('BATTLE'), findsOneWidget);
        for (final tab in [0, 1, 2]) {
          await tester.tap(find.byKey(ValueKey('nav-$tab')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'tab $tab');
          expect(find.byType(PlayerHud), findsOneWidget);
          expect(find.byType(ArenaBottomBar), findsOneWidget);
          expect(find.byType(TeamScreen), findsNothing);
          expect(find.byType(EventsScreen), findsNothing);
          expect(
            find.textContaining('Paws & Claws', findRichText: true),
            findsNothing,
          );
          expectCleanArtwork(tester);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('menu keeps only settings, support and whats new', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final p = Player(await SharedPreferences.getInstance())..english = true;
    await tester.pumpWidget(MaterialApp(home: Home(player: p)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Meniu'));
    await tester.pumpAndSettle();
    expect(find.text(studioName), findsOneWidget);
    expect(find.text('Setări'), findsOneWidget);
    expect(find.text('Suport'), findsOneWidget);
    expect(find.text('Noutăți'), findsOneWidget);
    for (final removed in [
      'Google Play / Facebook Cloud Sync',
      'Prieteni',
      'Clasamente',
    ]) {
      expect(find.text(removed), findsNothing);
    }
    await tester.tap(find.text('Noutăți'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Versiunea $appVersion'), findsOneWidget);
    await tester.tap(find.text('ÎNCHIDE'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('splash shows One Ear Games and the shared version', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: StudioSplash()));
    await tester.pump();
    expect(find.text(studioName), findsOneWidget);
    expect(find.text('v$appVersion'), findsOneWidget);
    expect(
      find.textContaining('Paws & Claws', findRichText: true),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('trophy road hides parked team event and mode surfaces', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final p = Player(await SharedPreferences.getInstance())
      ..trophies = 321
      ..english = true;
    await tester.pumpWidget(MaterialApp(home: Home(player: p)));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(PlayerHud), matching: find.text('321')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Turul Casei'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Holul Principal'),
      ),
      findsOneWidget,
    );
    for (final parked in [
      'Echipă',
      'Evenimente',
      'Speed Rush',
      'Survival',
      'Ranked',
    ]) {
      expect(find.text(parked), findsNothing);
    }
    await tester.tap(find.text('ÎNCHIDE'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

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
