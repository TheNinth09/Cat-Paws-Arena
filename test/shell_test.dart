import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:cat_paws_arena/events_screen.dart';
import 'package:cat_paws_arena/house_tour_screen.dart';
import 'package:cat_paws_arena/lobby_screen.dart';
import 'package:cat_paws_arena/main.dart';
import 'package:cat_paws_arena/match_controller.dart';
import 'package:cat_paws_arena/online/cloud_profile.dart';
import 'package:cat_paws_arena/online/fake_backend.dart';
import 'package:cat_paws_arena/online/online_account.dart';
import 'package:cat_paws_arena/online/online_backend.dart';
import 'package:cat_paws_arena/online/rooms.dart';
import 'package:cat_paws_arena/profile.dart';
import 'package:cat_paws_arena/profile_screen.dart';
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

class _FriendRoomFailureCloud extends FakeCloud {
  String? failingDeleteCode;
  int deleteAttempts = 0;

  @override
  Future<void> deleteRoom(String code) async {
    if (code == failingDeleteCode) {
      deleteAttempts++;
      throw StateError('delete failed');
    }
    await super.deleteRoom(code);
  }

  @override
  Stream<MatchLink> watchJoin(RoomRecord room) =>
      Stream<MatchLink>.error(StateError('watch failed'));
}

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
    final field = find.byKey(const Key('parentGateAnswer'));
    final gate = find.ancestor(of: field, matching: find.byType(AlertDialog));
    final question = tester
        .widgetList<Text>(
          find.descendant(of: gate, matching: find.byType(Text)),
        )
        .map((text) => text.data ?? '')
        .firstWhere((data) => data.contains('×'), orElse: () => '');
    final match = RegExp(r'(\d+)\s*×\s*(\d+)').firstMatch(question)!;
    final answer = (int.parse(match.group(1)!) * int.parse(match.group(2)!))
        .toString();
    await tester.enterText(field, answer);
    await tester.pump();
    await tester.tap(find.descendant(of: gate, matching: find.text('OK')));
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
        for (final tab in [0, 1, 2, 3, 4]) {
          expect(find.byKey(ValueKey('nav-$tab')), findsOneWidget);
        }
        final bar = find.byType(ArenaBottomBar);
        for (final label in ['SHOP', 'CATS', 'BATTLE', 'TEAM', 'EVENTS']) {
          expect(
            find.descendant(of: bar, matching: find.text(label)),
            findsOneWidget,
          );
        }
        for (final tab in [0, 1, 2, 3, 4]) {
          await tester.tap(find.byKey(ValueKey('nav-$tab')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'tab $tab');
          expect(find.byType(PlayerHud), findsOneWidget);
          expect(find.byType(ArenaBottomBar), findsOneWidget);
          expect(
            find.textContaining('Paws & Claws', findRichText: true),
            findsNothing,
          );
          expectCleanArtwork(tester);
        }
        await tester.tap(find.byKey(const ValueKey('nav-3')));
        await tester.pumpAndSettle();
        expect(find.byType(TeamScreen), findsOneWidget);
        expect(find.text('ECHIPĂ'), findsOneWidget);
        expect(find.textContaining('coming soon'), findsWidgets);
        await tester.tap(find.byKey(const ValueKey('nav-4')));
        await tester.pumpAndSettle();
        expect(find.byType(EventsScreen), findsOneWidget);
        expect(find.text('EVENIMINTE'), findsOneWidget);
        expect(find.textContaining('Coming soon'), findsWidgets);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('menu shows the full hub entry list', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final p = Player(await SharedPreferences.getInstance())..english = true;
    await tester.pumpWidget(MaterialApp(home: Home(player: p)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Meniu'));
    await tester.pumpAndSettle();
    // The studio/game header was removed — the list starts directly.
    for (final item in [
      'Daily reward',
      'Friends',
      'Leaderboard',
      'News',
      'Support',
      'Account',
      'Settings',
    ]) {
      expect(find.text(item), findsOneWidget);
    }
    await tester.tap(find.text('News'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Versiunea $appVersion'), findsOneWidget);
    await tester.tap(find.text('ÎNCHIDE'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('studio intro shows branding art then reaches the game splash', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final p = Player(await SharedPreferences.getInstance());
    await tester.pumpWidget(MaterialApp(home: StudioIntro(player: p)));
    await tester.pump();
    expect(
      find.image(const AssetImage('assets/images/studio_logo.png')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(Boot), findsOneWidget);
    expect(
      find.textContaining('Paws & Claws', findRichText: true),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('house tour hides parked team event and mode surfaces', (
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
    expect(find.byType(HouseTourScreen), findsOneWidget);
    expect(find.text('HOUSE TOUR'), findsOneWidget);
    expect(find.text('2. MAIN HALL'), findsOneWidget);
    for (final parked in [
      'Echipă',
      'Evenimente',
      'Speed Rush',
      'Survival',
      'Ranked',
    ]) {
      expect(find.text(parked), findsNothing);
    }
    await tester.pageBack();
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
    // The avatar opens the profile page; the name editor lives behind the
    // EDITEAZĂ NUMELE entry there.
    expect(find.byType(ProfileScreen), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('EDITEAZĂ NUMELE'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ProfileScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('EDITEAZĂ NUMELE'));
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

  testWidgets(
    'shop restores offers, daily reward, paw packs and honest LEI prices',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final p = Player(await SharedPreferences.getInstance());
      await tester.pumpWidget(MaterialApp(home: Home(player: p)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-0')));
      await tester.pumpAndSettle();
      final shop = find.byType(ShopScreen);
      final scrollable = find
          .descendant(of: shop, matching: find.byType(Scrollable))
          .first;
      expect(
        find.descendant(of: shop, matching: find.text('ZONA DE OFERTE')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: shop, matching: find.text('RECOMPENSĂ ZILNICĂ')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: shop, matching: find.text('DAILY DEAL')),
        findsOneWidget,
      );
      // The daily gift on main is +5 paws every 6 hours.
      await tester.tap(find.text('+5 Lăbuțe'));
      await tester.pumpAndSettle();
      expect(p.coins, 505);
      for (final removed in [
        'ACCESORII & PUTERI',
        'The Midnight Zoomies',
        'Shadow Pounce',
        'Laser Chase',
        'Google Play Billing',
      ]) {
        expect(
          find.descendant(of: shop, matching: find.text(removed)),
          findsNothing,
        );
      }
      await tester.scrollUntilVisible(
        find.text('PACHETE LĂBUȚE'),
        300,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('coin-bundle-grid')), findsOneWidget);
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
      for (final badge in ['CEL MAI POPULAR', 'BEST VALUE']) {
        expect(find.text(badge), findsOneWidget);
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
      await Scrollable.ensureVisible(
        tester.element(find.text('8.99 LEI')),
        alignment: 0.3,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('8.99 LEI'));
      await tester.pumpAndSettle();
      expect(
        find.text('Achizițiile nu sunt disponibile încă.'),
        findsOneWidget,
      );
      expect(p.coins, 505);
      await closeDialogContaining(
        tester,
        'Achizițiile nu sunt disponibile încă.',
      );
      await tester.scrollUntilVisible(
        find.text('17.99 LEI'),
        300,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('17.99 LEI'));
      await tester.pumpAndSettle();
      expect(
        find.text('Achizițiile nu sunt disponibile încă.'),
        findsOneWidget,
      );
      expect(p.coins, 505);
      expect(p.owned, isEmpty);
      await closeDialogContaining(
        tester,
        'Achizițiile nu sunt disponibile încă.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('house tour map opens from the lobby progress strip', (
    tester,
  ) async {
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
    // Airy lobby: one LUPTĂ button, hub chips, no secondary cards/bot list.
    expect(find.text('MODE: 1v1 ARENA'), findsOneWidget);
    expect(find.byKey(const ValueKey('lobby-fight')), findsOneWidget);
    expect(find.text('ONLINE ROOM'), findsNothing);
    expect(find.text('CAMERĂ ONLINE'), findsNothing);
    for (final hub in ['hub-ranks', 'hub-quests']) {
      expect(find.byKey(ValueKey(hub)), findsOneWidget);
    }
    expect(find.text('CADOU ZILNIC'), findsNothing);
    expect(find.text('Alege o pisică-bot din casă'), findsNothing);
    expect(find.byKey(const ValueKey('trophy-progress')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('trophy-progress')));
    await tester.pumpAndSettle();
    expect(find.byType(HouseTourScreen), findsOneWidget);
    expect(find.text('HOUSE TOUR'), findsOneWidget);
    for (final name in [
      '1. LIVING ROOM',
      '2. MAIN HALL',
      '3. KITCHEN',
      '4. BEDROOM',
    ]) {
      expect(find.text(name), findsOneWidget);
    }
    // The path carries milestones only — no bot entries anywhere.
    for (final cat in [
      'Puf',
      'Misu',
      'Toto',
      'Nori',
      'Kiko',
      'Biscuit',
      'Marmalade',
    ]) {
      expect(find.text(cat), findsNothing);
    }
    expect(find.text('MILESTONE'), findsNWidgets(3));
    expect(find.text('LOCKED AT 800 TROPHIES'), findsOneWidget);
    expect(find.text('LOCKED AT 1500 TROPHIES'), findsOneWidget);
    expect(find.text('CURRENT ROOM'), findsOneWidget);
    expect(find.text('CLEARED'), findsOneWidget);
    expect(houseRoomForTrophies(299).name, 'Living');
    expect(houseRoomForTrophies(300).name, 'Hall');
    // Room titles render untruncated in Romanian too (no ellipsis).
    p.english = false;
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trophy-progress')));
    await tester.pumpAndSettle();
    for (final name in [
      '2. HOLUL PRINCIPAL',
      '3. BUCATARIA',
      '4. DORMITORUL',
    ]) {
      expect(find.text(name), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('lobby fight opens the VS screen then the duel', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final p = Player(await SharedPreferences.getInstance());
    await tester.pumpWidget(MaterialApp(home: Home(player: p)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('lobby-fight')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lobby-fight')));
    await tester.pumpAndSettle();
    // LUPTĂ opens the mode chooser first: offline house cats or friend room.
    expect(find.text('ALEGE MODUL'), findsOneWidget);
    expect(find.byKey(const ValueKey('mode-offline')), findsOneWidget);
    expect(find.byKey(const ValueKey('mode-online')), findsOneWidget);
    expect(find.text('CONTRA PISICILOR CASEI'), findsOneWidget);
    expect(find.text('CAMERĂ DE PRIETEN'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mode-offline')));
    // One pre-match page now: the duel's own searching scene ("Se caută
    // adversarul..."), no separate "preparing the arena" step.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(MatchScreen), findsOneWidget);
    expect(find.text('CAT PAWS ARENA'), findsOneWidget);
    expect(find.text('MIZELE MECIULUI'), findsOneWidget);
    expect(find.text('+30'), findsOneWidget);
    expect(find.text('VICTORIE'), findsOneWidget);
    expect(find.text('EGAL'), findsOneWidget);
    expect(find.text('-25'), findsOneWidget);
    expect(find.text('INFRANGERE'), findsOneWidget);
    expect(find.text('Se caută adversarul...'), findsOneWidget);
    expect(find.text('ANTRENAMENT OFFLINE'), findsWidgets);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Se caută adversarul...'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('searching cancel returns to the lobby', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final p = Player(await SharedPreferences.getInstance());
    await tester.pumpWidget(MaterialApp(home: Home(player: p)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('lobby-fight')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lobby-fight')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mode-offline')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(MatchScreen), findsOneWidget);
    // Cancelling the search leaves immediately — no duel started, so no
    // confirmation dialog and no penalty.
    await tester.tap(find.byKey(const ValueKey('match-cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(MatchScreen), findsNothing);
    expect(find.text('MOD: 1v1 ARENA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('avatar tap opens the dedicated profile screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final p = Player(await SharedPreferences.getInstance())
      ..trophies = 300
      ..coins = 1234
      ..owned = {'acc_pirate_bandana'};
    await tester.pumpWidget(MaterialApp(home: Home(player: p)));
    await tester.pumpAndSettle();
    // Avatar + name area in the HUD opens the profile page.
    await tester.tap(
      find.descendant(of: find.byType(PlayerHud), matching: find.text('Alex')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('PROFILUL MEU'), findsOneWidget);
    expect(find.text('TROFEE'), findsOneWidget);
    expect(find.text('LĂBUȚE'), findsOneWidget);
    expect(find.text('COSMETICE'), findsOneWidget);
    expect(find.text('1234'), findsOneWidget);
    // Organised sections — the placeholder rows were cleaned up; the
    // real content sections stay labelled and scroll into view.
    final profileScroll = find
        .descendant(
          of: find.byType(ProfileScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    for (final section in ['EMOTE-URI', 'ACCESORII']) {
      await tester.scrollUntilVisible(
        find.text(section),
        150,
        scrollable: profileScroll,
      );
      expect(find.text(section), findsOneWidget);
    }
    // Emote preset chips are real; owned accessory is marked ECHIPAT/DEȚINUT.
    expect(find.text('SALUT'), findsOneWidget);
    expect(find.text('NEDEȚINUT'), findsWidgets);
    // Name edit + account link stay reachable from the profile.
    await tester.scrollUntilVisible(
      find.text('EDITEAZĂ NUMELE'),
      200,
      scrollable: profileScroll,
    );
    expect(find.text('EDITEAZĂ NUMELE'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('profile-account')),
      150,
      scrollable: profileScroll,
    );
    expect(find.byKey(const ValueKey('profile-account')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaderboard hub shows a real local tab and honest global', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final p = Player(await SharedPreferences.getInstance())
      ..trophies = 300
      ..english = false;
    await tester.pumpWidget(MaterialApp(home: Home(player: p)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hub-ranks')));
    await tester.pumpAndSettle();
    expect(find.text('CLASAMENT'), findsWidgets);
    // LOCAL tab: the real house cats + the player's own row.
    expect(find.textContaining('TU'), findsOneWidget);
    expect(find.textContaining('BOT'), findsWidgets);
    expect(find.text('1'), findsWidgets);
    // GLOBAL tab is honest: coming soon, no fake strangers ranking.
    await tester.tap(find.byKey(const ValueKey('ranks-global')));
    await tester.pumpAndSettle();
    expect(find.textContaining('În curând'), findsOneWidget);
    expect(find.text('Puf'), findsNothing);
    await closeDialogContaining(tester, 'CLASAMENT');
    expect(tester.takeException(), isNull);
  });

  testWidgets('match return never resurfaces the house tour or profile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final p = Player(await SharedPreferences.getInstance());
    await tester.pumpWidget(MaterialApp(home: Home(player: p)));
    await tester.pumpAndSettle();
    // The tour is still mounted on the stack when the duel starts (e.g. an
    // online duel arriving while a page was open). On ACASĂ the lobby must
    // be on top — a leftover translucent page must never resurface.
    await tester.tap(find.byKey(const ValueKey('trophy-progress')));
    await tester.pumpAndSettle();
    expect(find.byType(HouseTourScreen), findsOneWidget);
    // Same entry point as the mode chooser: the lobby's onBattle callback.
    // The covered lobby is offstage, so the finder must include it.
    tester
        .widget<LobbyScreen>(find.byType(LobbyScreen, skipOffstage: false))
        .onBattle(null);
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(MatchScreen), findsOneWidget);
    // Drive the engine duel to a result quickly (same harness as duel_test).
    final m =
        (tester.state(find.byType(MatchScreen)) as dynamic).match
            as ArenaMatchController;
    m.botMoveDelay = Duration.zero;
    m.eventSink = (_) => m.onBoardIdle();
    // searching → playing is paced by a short intro timer.
    var intro = 0;
    while (m.phase == MatchPhase.searching && intro++ < 120) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    var guard = 0;
    while (m.phase == MatchPhase.playing && guard++ < 600) {
      m.debugEndActiveTurn();
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(m.phase, MatchPhase.finished, reason: 'match did not finish');
    // The result screen animates continuously — advance fixed frames.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.text('ACASĂ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(HouseTourScreen), findsNothing);
    expect(find.byType(MatchScreen), findsNothing);
    expect(find.text('MOD: 1v1 ARENA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('pickBattleCat only offers unlocked house cats', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final p = Player(prefs)..trophies = 0;
    const living = {'Puf', 'Misu', 'Toto'};
    for (var i = 0; i < 12; i++) {
      expect(living, contains(pickBattleCat(p, i)!.name));
    }
    expect(pickBattleCat(p, 7), pickBattleCat(p, 7));
    p.trophies = 350;
    final names = {for (var i = 0; i < 40; i++) pickBattleCat(p, i)!.name};
    expect(names, containsAll(['Puf', 'Nori', 'Kiko']));
    expect(names, isNot(contains('Marmalade')));
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
      'Restore with Google',
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
    expect(find.text('Restore with Google'), findsOneWidget);
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
    await tester.ensureVisible(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('parentGateOk')), findsOneWidget);
    await tester.tap(find.text('Renunță'));
    await tester.pumpAndSettle();
    expect(account.user, isNull);
    expect(p.trophies, 840);
    await tester.ensureVisible(find.text('Delete account'));
    await tester.pumpAndSettle();
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

  testWidgets('lobby friend room creates and joins online codes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final cloud = FakeCloud();
    final account = OnlineAccount(FakeAuth(cloud), cloud);
    final rooms = RoomService(cloud);
    final hostRoom = await rooms.createRoom('host-uid');
    OnlinePlay.services = OnlinePlayServices(
      account: account,
      rooms: rooms,
      googleCredential: () async => null,
    );
    addTearDown(() => OnlinePlay.services = null);
    final p = Player(await SharedPreferences.getInstance());
    await tester.pumpWidget(MaterialApp(home: Home(player: p)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Meniu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prieteni'));
    await tester.pumpAndSettle();
    expect(find.text('Cameră de prieten'), findsOneWidget);
    expect(find.text('CREEAZĂ CAMERĂ'), findsOneWidget);
    expect(find.text('ALĂTURĂ-TE'), findsOneWidget);
    expect(find.textContaining('ONLINE'), findsWidgets);
    expect(find.textContaining('BOT'), findsWidgets);
    await tester.tap(find.text('CREEAZĂ CAMERĂ'));
    await tester.pumpAndSettle();
    expect(account.user, isNotNull);
    expect(cloud.rooms, hasLength(2));
    final created = cloud.rooms.values.firstWhere(
      (room) => room.hostUid != 'host-uid',
    );
    expect(find.text(created.code), findsOneWidget);
    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), hostRoom.code);
    await tester.pump();
    await tester.ensureVisible(find.text('ALĂTURĂ-TE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ALĂTURĂ-TE'));
    await tester.pumpAndSettle();
    expect(cloud.rooms, hasLength(1));
    expect(find.textContaining('a fost găsită'), findsOneWidget);
    await closeDialogContaining(tester, 'Cameră de prieten');
    expect(tester.takeException(), isNull);
  });

  testWidgets('friend room keeps previous code when cancel fails', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final cloud = _FriendRoomFailureCloud();
    final account = OnlineAccount(FakeAuth(cloud), cloud);
    OnlinePlay.services = OnlinePlayServices(
      account: account,
      rooms: RoomService(cloud),
      googleCredential: () async => null,
    );
    addTearDown(() => OnlinePlay.services = null);
    final p = Player(await SharedPreferences.getInstance());
    await tester.pumpWidget(MaterialApp(home: Home(player: p)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    // Online mode in the fight chooser reuses the same friend-room flow.
    await tester.tap(find.byKey(const ValueKey('lobby-fight')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mode-online')));
    await tester.pumpAndSettle();
    expect(find.text('Cameră de prieten'), findsOneWidget);
    await tester.tap(find.text('CREEAZĂ CAMERĂ'));
    await tester.pumpAndSettle();
    expect(cloud.rooms, hasLength(1));
    final firstCode = cloud.rooms.keys.single;
    cloud.failingDeleteCode = firstCode;
    await tester.tap(find.text('CREEAZĂ CAMERĂ'));
    await tester.pumpAndSettle();
    expect(cloud.deleteAttempts, 1);
    expect(cloud.rooms.keys.single, firstCode);
    expect(find.text(firstCode), findsOneWidget);
    expect(
      find.text('Camera anterioară nu a putut fi anulată. Încearcă din nou.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings restores cloud profile with Google', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final cloud = FakeCloud();
    final auth = FakeAuth(cloud);
    final account = OnlineAccount(auth, cloud);
    await account.start();
    await auth.linkGoogle(const GoogleCredential('google-test'));
    final source = Player(await SharedPreferences.getInstance())
      ..name = 'CloudCat'
      ..trophies = 777
      ..coins = 1234
      ..cat = 'Bubble'
      ..owned = {'bow'}
      ..claims = {300}
      ..english = true;
    await account.save(CloudProfile.fromPlayer(source));
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
    final p = Player(await SharedPreferences.getInstance())..name = 'Local';
    await tester.pumpWidget(MaterialApp(home: Home(player: p)));
    await tester.pumpAndSettle();
    await openSettings(tester);
    await tester.ensureVisible(find.text('Restore with Google'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore with Google'));
    await tester.pumpAndSettle();
    await passParentGate(tester);
    expect(credentialCalls, 1);
    expect(p.name, 'Local');
    expect(p.trophies, 777);
    expect(p.coins, 1234);
    expect(p.cat, 'Bubble');
    expect(p.owned, contains('bow'));
    expect(find.text('Profilul cloud a fost restaurat.'), findsOneWidget);
    await closeDialogContaining(tester, 'Profilul cloud a fost restaurat.');
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings retries Google-linked delete after recent login', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final cloud = FakeCloud();
    final auth = FakeAuth(cloud);
    final account = OnlineAccount(auth, cloud);
    OnlinePlay.services = OnlinePlayServices(
      account: account,
      rooms: RoomService(cloud),
      googleCredential: () async => const GoogleCredential('google-test'),
    );
    addTearDown(() => OnlinePlay.services = null);
    await account.start();
    await auth.linkGoogle(const GoogleCredential('google-test'));
    auth.requireRecentLogin = true;
    final p = Player(await SharedPreferences.getInstance())
      ..name = 'Local'
      ..trophies = 10
      ..coins = 20;
    await p.save();
    await tester.pumpWidget(MaterialApp(home: Home(player: p)));
    await tester.pumpAndSettle();
    await openSettings(tester);
    await tester.ensureVisible(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await passParentGate(tester);
    expect(find.text('Șterge contul?'), findsOneWidget);
    await tester.tap(find.text('ȘTERGE CONTUL'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('parentGateOk')), findsOneWidget);
    await passParentGate(tester);
    expect(auth.requireRecentLogin, isFalse);
    expect(account.user, isNull);
    expect(cloud.users, isEmpty);
    expect(p.trophies, 0);
    expect(
      find.text('Contul și datele locale au fost șterse.'),
      findsOneWidget,
    );
    await closeDialogContaining(tester, 'Cont șters');
    expect(tester.takeException(), isNull);
  });
}
