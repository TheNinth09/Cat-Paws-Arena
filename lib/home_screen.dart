import 'package:flutter/material.dart';

import 'app_dialogs.dart';
import 'cat_avatar.dart';
import 'cats_screen.dart';
import 'events_screen.dart';
import 'lobby_screen.dart';
import 'match_screen.dart';
import 'profile.dart';
import 'shell/app_info.dart';
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
  int tab = 2;
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
  void menu(String item) {
    Navigator.pop(context);
    switch (item) {
      case 'Setări':
        showSettings(context, p);
      case 'Noutăți':
        showAppDialog(
          context,
          item,
          Text(
            'Versiunea $appVersion • Cinci tab-uri, un singur mod de joc și identitate One Ear Games.',
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
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0x3320130e), width: 1),
                  ),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.pets, size: 42, color: ink),
                    SizedBox(height: 8),
                    Text(
                      studioName,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                    Text(
                      appName,
                      style: TextStyle(
                        color: Color(0xff8a5a3b),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              for (final item in ['Setări', 'Suport', 'Noutăți'])
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
                          onBattle: (cat) {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => MatchScreen(
                                  player: p,
                                  mode: 0,
                                  opponent: cat,
                                ),
                              ),
                            );
                          },
                          onRoad: () => showTrophyRoad(context, p),
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
