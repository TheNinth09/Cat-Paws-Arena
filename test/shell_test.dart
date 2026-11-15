import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:cat_paws_arena/events_screen.dart';
import 'package:cat_paws_arena/main.dart';
import 'package:cat_paws_arena/online/fake_backend.dart';
import 'package:cat_paws_arena/online/online_account.dart';
import 'package:cat_paws_arena/online/online_backend.dart';
import 'package:cat_paws_arena/online/rooms.dart';
import 'package:cat_paws_arena/profile.dart';
import 'package:cat_paws_arena/shop_screen.dart';
import 'package:cat_paws_arena/shell/app_info.dart';
import 'package:cat_paws_arena/shell/daily_board.dart';
import 'package:cat_paws_arena/shell/economy.dart';
import 'package:cat_paws_arena/shell/house_tour.dart';
import 'package:cat_paws_arena/shell/online_play.dart';
import 'package:cat_paws_arena/shell/reward_calendar.dart';
import 'package:cat_paws_arena/team_screen.dart';
import 'package:cat_paws_arena/ui_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'artwork_test_support.dart';

void main() {
  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Meniu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Setări'));
    await tester.pumpAndSettle();
  }

  Future<void> closeDialogContaining(WidgetTester tester, String text) async {
    final dialog = find.ancestor(
      of: find.text(text),
      matching: find.byType(AlertDialog),
    );
    await tester.tap(
      find.descendant(of: dialog, matching: find.text('ÎNCHIDE')).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> passParentGate(WidgetTester tester) async {
    final gate = find.ancestor(
      of: find.text('Verificare părinte'),
      matching: find.byType(AlertDialog),
    );
    await tester.enterText(
      find.descendant(of: gate, matching: find.byType(TextField)),
      '12',
    );
    await tester.pump();
    await tester.tap(find.text('CONFIRMĂ'));
    await tester.pumpAndSettle();
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

  testWidgets('shop sells only cosmetic LEI bundles with no countdown', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final p = Player(await SharedPreferences.getInstance());
    await tester.pumpWidget(MaterialApp(home: Home(player: p)));
    await tester.tap(find.byKey(const ValueKey('nav-0')));
    await tester.pumpAndSettle();
    final shop = find.byType(ShopScreen);
    await tester.tap(find.text('+200 Lăbuțe'));
    await tester.pumpAndSettle();
    expect(p.coins, 700);
    for (final removed in [
      'DAILY DEAL',
      'PACHETE LĂBUȚE',
      'ACCESORII & PUTERI',
      'The Midnight Zoomies',
      'Shadow Pounce',
      'Laser Chase',
      '650 Lăbuțe',
      'Google Play Billing',
    ]) {
      expect(
        find.descendant(of: shop, matching: find.text(removed)),
        findsNothing,
      );
    }
    for (final price in ['14.99 LEI', '17.99 LEI']) {
      await tester.scrollUntilVisible(
        find.text(price),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text(price)),
        alignment: 0.3,
      );
      await tester.pumpAndSettle();
      expect(find.text(price).hitTestable(), findsOneWidget);
    }
    for (final pressure in ['EXPIRĂ', 'LIMITATĂ', 'COUNTDOWN']) {
      expect(
        find.descendant(of: shop, matching: find.textContaining(pressure)),
        findsNothing,
      );
    }
    expect(
      find.descendant(
        of: shop,
        matching: find.textContaining(RegExp(r'\b\d{1,2}:\d{2}\b')),
      ),
      findsNothing,
    );
    await tester.tap(find.text('14.99 LEI'));
    await tester.pumpAndSettle();
    expect(find.text('Achizițiile nu sunt disponibile încă.'), findsOneWidget);
    expect(p.coins, 700);
    expect(tester.takeException(), isNull);
  });

  testWidgets('house tour opens room two at 300 trophies', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final p = Player(await SharedPreferences.getInstance())
      ..trophies = 300
      ..english = true;
    await tester.pumpWidget(MaterialApp(home: Home(player: p)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    expect(find.text('Turul casei • Hall'), findsOneWidget);
    for (final name in ['Nori', 'Kiko', 'Biscuit']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(houseRoomForTrophies(299).name, 'Living');
    expect(houseRoomForTrophies(300).name, 'Hall');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'daily board seed is stable per UTC day and best score persists',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final day = DateTime.utc(2026, 3, 4, 23, 30);
      final sameDay = DateTime.utc(2026, 3, 4, 1, 5);
      final nextDay = DateTime.utc(2026, 3, 5, 0, 5);
      expect(DailyBoardStore.seedFor(day), DailyBoardStore.seedFor(sameDay));
      expect(
        DailyBoardStore.seedFor(day),
        isNot(DailyBoardStore.seedFor(nextDay)),
      );
      final store = DailyBoardStore(prefs);
      expect(await store.recordScore(7, day), 7);
      expect(store.bestScore(day), 7);
      expect(await store.recordScore(4, day), 7);
      expect(store.bestScore(nextDay), 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reward calendar resets after a missed day and never pays twice',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final p = Player(await SharedPreferences.getInstance());
      final calendar = RewardCalendar(p);
      final day1 = DateTime.utc(2026, 4, 1, 12);
      final day2 = DateTime.utc(2026, 4, 2, 12);
      final day4 = DateTime.utc(2026, 4, 4, 12);
      expect(calendar.claim(day1), RewardCalendar.rewards[0]);
      expect(calendar.claim(day1), isNull);
      expect(calendar.claim(day2), RewardCalendar.rewards[1]);
      expect(calendar.claim(day4), RewardCalendar.rewards[0]);
      expect(tester.takeException(), isNull);
    },
  );

  test('economy table takes at least 30 days for launch cosmetics', () {
    expect(launchCosmetics, isNotEmpty);
    expect(expectedEarnedPawsPerDay, greaterThan(0));
    expect(daysToEarnEveryLaunchCosmetic, greaterThanOrEqualTo(30));
  });

  testWidgets('settings keeps online entries unavailable until configured', (
    tester,
  ) async {
    OnlinePlay.services = null;
    SharedPreferences.setMockInitialValues({});
    final p = Player(await SharedPreferences.getInstance());
    await tester.pumpWidget(MaterialApp(home: Home(player: p)));
    await tester.pumpAndSettle();
    await openSettings(tester);
    expect(find.text('Joc online'), findsOneWidget);
    expect(find.text('Indisponibil'), findsOneWidget);
    for (final hidden in [
      'Link Google account',
      'Delete account',
      'Join room',
      'Cod cameră',
    ]) {
      expect(find.text(hidden), findsNothing);
    }
    await tester.tap(find.text('ÎNCHIDE'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings links Google account behind parent gate', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final cloud = FakeCloud();
    final account = OnlineAccount(FakeAuth(cloud), cloud);
    var credentialCalls = 0;
    OnlinePlay.services = OnlinePlayServices(
      account: account,
      rooms: RoomService(cloud),
      googleCredential: () async {
        credentialCalls++;
        return const GoogleCredential('google-test');
      },
    );
    addTearDown(() => OnlinePlay.services = null);
    final p = Player(await SharedPreferences.getInstance());
    await tester.pumpWidget(MaterialApp(home: Home(player: p)));
    await tester.pumpAndSettle();
    await openSettings(tester);
    expect(find.text('Link Google account'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
    expect(find.text('Join room'), findsOneWidget);
    expect(find.text('Cod cameră'), findsOneWidget);
    await tester.tap(find.text('Link Google account'));
    await tester.pumpAndSettle();
    await passParentGate(tester);
    expect(credentialCalls, 1);
    expect(account.user?.googleLinked, isTrue);
    expect(
      find.text('Contul Google a fost conectat la acest dispozitiv.'),
      findsOneWidget,
    );
    await closeDialogContaining(tester, 'Cont Google');
    expect(find.text('Google conectat'), findsOneWidget);
    await tester.tap(find.text('ÎNCHIDE'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings deletes account behind parent gate and confirm', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final cloud = FakeCloud();
    final account = OnlineAccount(FakeAuth(cloud), cloud);
    OnlinePlay.services = OnlinePlayServices(
      account: account,
      rooms: RoomService(cloud),
      googleCredential: () async => null,
    );
    addTearDown(() => OnlinePlay.services = null);
    final p = Player(await SharedPreferences.getInstance())
      ..name = 'Local'
      ..trophies = 840
      ..coins = 1210
      ..cat = 'Custom'
      ..owned = {'bow'}
      ..claims = {300}
      ..photo =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
    await p.save();
    await tester.pumpWidget(MaterialApp(home: Home(player: p)));
    await tester.pumpAndSettle();
    await openSettings(tester);
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Verificare părinte'), findsOneWidget);
    await tester.tap(find.text('ANULEAZĂ'));
    await tester.pumpAndSettle();
    expect(account.user, isNull);
    expect(p.trophies, 840);
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await passParentGate(tester);
    expect(find.text('Șterge contul?'), findsOneWidget);
    expect(account.user, isNull);
    await tester.tap(find.text('ȘTERGE CONTUL'));
    await tester.pumpAndSettle();
    expect(account.user, isNull);
    expect(cloud.users, isEmpty);
    expect(cloud.profiles, isEmpty);
    expect(p.name, 'Alex');
    expect(p.trophies, 0);
    expect(p.coins, 500);
    expect(p.cat, 'Tzuki');
    expect(p.owned, isEmpty);
    expect(p.claims, isEmpty);
    expect(p.photo, isNull);
    expect(
      find.text('Contul și datele locale au fost șterse.'),
      findsOneWidget,
    );
    await closeDialogContaining(tester, 'Cont șters');
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings joins a room with typed code variants', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final cloud = FakeCloud();
    final account = OnlineAccount(FakeAuth(cloud), cloud);
    final rooms = RoomService(cloud);
    OnlinePlay.services = OnlinePlayServices(
      account: account,
      rooms: rooms,
      googleCredential: () async => null,
    );
    addTearDown(() => OnlinePlay.services = null);
    final hostRoom = await rooms.createRoom('host-uid');
    final p = Player(await SharedPreferences.getInstance());
    await tester.pumpWidget(MaterialApp(home: Home(player: p)));
    await tester.pumpAndSettle();
    await openSettings(tester);
    final typed =
        '${hostRoom.code.substring(0, 3).toLowerCase()}-${hostRoom.code.substring(3).toLowerCase()}';
    await tester.enterText(find.byType(TextField), typed);
    await tester.pump();
    await tester.ensureVisible(find.text('Join room'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join room'));
    await tester.pumpAndSettle();
    expect(account.user, isNotNull);
    expect(cloud.rooms, isEmpty);
    expect(find.text('Camera ${hostRoom.code} a fost găsită.'), findsOneWidget);
    await closeDialogContaining(
      tester,
      'Camera ${hostRoom.code} a fost găsită.',
    );
    expect(tester.takeException(), isNull);
  });
}
