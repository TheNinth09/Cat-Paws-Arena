import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cat_paws_arena/events_screen.dart';
import 'package:cat_paws_arena/catalog.dart';
import 'package:cat_paws_arena/profile.dart';
import 'package:cat_paws_arena/shop_screen.dart';
import 'package:cat_paws_arena/team_screen.dart';

Future<Player> _player(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  return Player(prefs);
}

void main() {
  testWidgets(
    'shop shows offer zone, daily reward, paw packs and honest prices',
    (tester) async {
      final player = await _player(tester);
      final messages = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShopScreen(
              player: player,
              onUnavailable: (_) {},
              onMessage: (title, message) => messages.add('$title: $message'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final shop = find.byType(ShopScreen);
      expect(
        find.descendant(of: shop, matching: find.text('ZONA DE OFERTE')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: shop, matching: find.text('RECOMPENSĂ ZILNICĂ')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: shop, matching: find.text('GRATIS')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: shop,
          matching: find.text('Cadou gratuit (la 6 ore)'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: shop, matching: find.text('DAILY DEAL')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: shop, matching: find.text('PACHET SPECIAL')),
        findsWidgets,
      );

      await tester.tap(find.text('+5 Lăbuțe'));
      await tester.pumpAndSettle();
      expect(player.coins, 505);

      final scrollable = find
          .descendant(of: shop, matching: find.byType(Scrollable))
          .first;
      await tester.scrollUntilVisible(
        find.text('PACHETE LĂBUȚE'),
        300,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      for (final price in [
        '8.99 LEI',
        '22.99 LEI',
        '44.99 LEI',
        '89.99 LEI',
        '134.99 LEI',
        '224.99 LEI',
      ]) {
        expect(find.text(price), findsOneWidget);
      }
      expect(find.text('CEL MAI POPULAR'), findsOneWidget);
      expect(find.text('BEST VALUE'), findsOneWidget);
      expect(
        find.descendant(
          of: shop,
          matching: find.textContaining(RegExp(r'\b\d{1,2}:\d{2}\b')),
        ),
        findsNothing,
      );

      await tester.tap(find.text('8.99 LEI'));
      await tester.pumpAndSettle();
      expect(
        messages,
        contains('Pachete Lăbuțe: Achizițiile nu sunt disponibile încă.'),
      );
      expect(player.coins, 505);
    },
  );

  testWidgets('paw-priced accessories spend earned coins and mark owned', (
    tester,
  ) async {
    final player = await _player(tester)..coins = 3000;
    final messages = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShopScreen(
            player: player,
            onUnavailable: (_) {},
            onMessage: (title, message) => messages.add('$title: $message'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final shop = find.byType(ShopScreen);
    final scrollable = find
        .descendant(of: shop, matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(
      find.text('8,500'),
      400,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();

    expect(find.text('2,500'), findsWidgets);
    expect(find.text('8,500'), findsOneWidget);
    expect(find.text('-15%'), findsOneWidget);
    expect(
      find.descendant(
        of: shop,
        matching: find.textContaining(RegExp(r'\b\d{1,2}:\d{2}\b')),
      ),
      findsNothing,
    );

    await tester.tap(find.text('2,500').first);
    await tester.pumpAndSettle();
    expect(player.coins, 500);
    expect(player.owned.contains('acc_pirate_bandana'), isTrue);
    expect(find.text('DEȚINUT'), findsOneWidget);

    await tester.tap(find.text('2,500').first);
    await tester.pumpAndSettle();
    expect(player.coins, 500);
    expect(
      messages,
      contains(
        'Magazin: Nu ai destule lăbuțe încă — le câștigi din meciuri și din recompensa zilnică.',
      ),
    );
  });

  testWidgets('team screen keeps social layout parked and honest', (
    tester,
  ) async {
    final player = await _player(tester)
      ..english = true
      ..trophies = teamUnlockTrophies;
    final unavailable = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeamScreen(player: player, onUnavailable: unavailable.add),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TEAM: ROYAL CATS'), findsOneWidget);
    expect(find.text('TEAMS ARRIVE SOON'), findsOneWidget);
    expect(find.text('PREVIEW'), findsOneWidget);
    // No fabricated chat bubbles, trade cards or member counts.
    expect(find.text('TRADE REQUEST'), findsNothing);
    expect(find.textContaining(RegExp(r'\d+\s*/\s*30')), findsNothing);
  });

  testWidgets('events toggle shows parked global and private choices', (
    tester,
  ) async {
    final player = await _player(tester)
      ..english = true
      ..trophies = eventsUnlockTrophies;
    final unavailable = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventsScreen(player: player, onUnavailable: unavailable.add),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GLOBAL'), findsOneWidget);
    expect(find.text('PRIVATE'), findsOneWidget);
    expect(find.text('GLOBAL WEEKEND TOURNAMENT'), findsOneWidget);
    expect(find.textContaining('Coming soon'), findsWidgets);
    // No live countdown — tournaments are parked.
    expect(find.textContaining(RegExp(r'\d+[Zz]\s*\d+[Hh]')), findsNothing);

    await tester.tap(find.text('PRIVATE'));
    await tester.pumpAndSettle();
    expect(find.text('PRIVATE EVENTS'), findsOneWidget);
    expect(find.text('CREATE EVENT'), findsOneWidget);
    expect(find.text('JOIN WITH CODE'), findsOneWidget);

    await tester.tap(find.text('CREATE'));
    await tester.pumpAndSettle();
    expect(unavailable, contains('Creating private events'));
  });
}
