import 'package:flutter/material.dart';

import 'app_dialogs.dart';
import 'cat_avatar.dart';
import 'catalog.dart';
import 'cats_screen.dart';
import 'events_screen.dart';
import 'lobby_screen.dart';
import 'match_screen.dart';
import 'profile.dart';
import 'shop_screen.dart';
import 'team_screen.dart';
import 'ui_widgets.dart';

class Home extends StatefulWidget {
  const Home({super.key, required this.player});
  final Player player;
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final scaffold = GlobalKey<ScaffoldState>();
  final pages = PageController(initialPage: 2);
  int tab = 2, mode = 0;
  Player get p => widget.player;
  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  void select(int index) {
    setState(() => tab = index);
    pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void unavailable(String feature) => showUnavailable(context, feature);
  void chooseMode() => showAppDialog(
    context,
    'Mod de joc',
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < modeNames.length; i++)
          ArenaButton(
            text:
                '${modeNames[i]}${i > p.tier ? ' • ${modeThresholds[i]} trofee' : ''}',
            onPressed: i <= p.tier
                ? () {
                    setState(() => mode = i);
                    Navigator.pop(context);
                  }
                : null,
          ),
      ],
    ),
  );
  void menu(String item) {
    Navigator.pop(context);
    switch (item) {
      case 'Setări':
        showSettings(context, p);
      case 'Noutăți':
        showAppDialog(
          context,
          item,
          const Text(
            'Versiunea 1.0.2 • Ecrane construite din widgets, magazin în grilă, avatar vectorial și navigare adaptivă.',
          ),
        );
      case 'Clasamente':
        showAppDialog(
          context,
          item,
          DefaultTabController(
            length: 2,
            child: SizedBox(
              height: 180,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Global'),
                      Tab(text: 'Local'),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Clasamentele online nu sunt conectate.\n${p.name}: ${p.trophies} trofee',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      default:
        unavailable(item);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: p,
    builder: (context, _) => Scaffold(
      key: scaffold,
      endDrawer: Drawer(
        backgroundColor: cream,
        child: SafeArea(
          child: ListView(
            children: [
              const DrawerHeader(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.pets, size: 42, color: ink),
                    SizedBox(height: 10),
                    Text(
                      'PAWS & CLAWS',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
              ),
              for (final item in [
                'Google Play / Facebook Cloud Sync',
                'Prieteni',
                'Setări',
                'Suport',
                'Noutăți',
                'Clasamente',
              ])
                ListTile(
                  title: Text(item),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => menu(item),
                ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              children: [
                PlayerHud(
                  avatar: CatAvatar(p, size: 46),
                  name: p.name,
                  trophies: p.trophies,
                  coins: p.coins,
                  onProfile: () => showPlayerProfile(context, p),
                  onRoad: () => showTrophyRoad(context, p),
                  onShop: () => select(0),
                  onMenu: () => scaffold.currentState!.openEndDrawer(),
                ),
                Expanded(
                  child: RoomBackground(
                    tier: p.tier,
                    child: PageView(
                      controller: pages,
                      onPageChanged: (index) => setState(() => tab = index),
                      children: [
                        ShopScreen(
                          player: p,
                          onUnavailable: unavailable,
                          onMessage: (title, message) =>
                              showAppDialog(context, title, Text(message)),
                        ),
                        CatsScreen(player: p, onShop: () => select(0)),
                        LobbyScreen(
                          player: p,
                          mode: mode,
                          onMode: chooseMode,
                          onRoad: () => showTrophyRoad(context, p),
                          onBattle: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  MatchScreen(player: p, mode: mode),
                            ),
                          ),
                        ),
                        TeamScreen(player: p, onUnavailable: unavailable),
                        EventsScreen(player: p, onUnavailable: unavailable),
                      ],
                    ),
                  ),
                ),
                ArenaBottomBar(
                  selected: tab,
                  onSelected: select,
                  english: p.english,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
