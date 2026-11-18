import 'dart:math';

import 'package:flutter/material.dart';

import 'app_dialogs.dart';
import 'cat_avatar.dart';
import 'cats_screen.dart';
import 'events_screen.dart';
import 'house_tour_screen.dart';
import 'lobby_screen.dart';
import 'match_screen.dart';
import 'profile.dart';
import 'profile_screen.dart';
import 'shell/app_info.dart';
import 'shell/house_tour.dart';
import 'shop_screen.dart';
import 'team_screen.dart';
import 'ui_widgets.dart';
import 'vs_screen.dart';

class Home extends StatefulWidget {
  const Home({super.key, required this.player});
  final Player player;
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final scaffold = GlobalKey<ScaffoldState>();
  final pages = PageController(initialPage: 2);
  final _trophyBadgeKey = GlobalKey();
  final _coinBadgeKey = GlobalKey();
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

  /// Trophy badge / lobby progress strip → the house-tour map.
  void openHouseTour() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HouseTourScreen(player: p),
      ),
    );
  }

  /// Avatar / name tap → the dedicated profile page (was a dialog).
  void openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ProfileScreen(player: p)),
    );
  }

  /// LUPTĂ (or a house cat picked on the tour) → VS screen → duel. Any
  /// pushed routes left on the stack (house tour, profile, dialogs) are
  /// removed, so returning from the match always lands on the lobby root —
  /// never on a stray translucent page.
  void startBattle(HouseCat? cat) {
    final trophiesBefore = p.trophies;
    final coinsBefore = p.coins;
    Navigator.of(context)
        .pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (vsContext) => VsScreen(
              player: p,
              opponent: VsOpponent.houseCat(p, cat),
              matchScreen: MatchScreen(player: p, mode: 0, opponent: cat),
            ),
          ),
          (route) => route.isFirst,
        )
        .then((_) {
          if (p.trophies > trophiesBefore || p.coins > coinsBefore) {
            _victoryFly();
          }
        });
  }

  /// Small celebration on a rewarded match return: a trophy and a paw coin
  /// fly from mid-screen to the HUD badges (pure overlay, no libraries).
  void _victoryFly() {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _VictoryFlight(
        trophyTarget: _badgeOffset(_trophyBadgeKey),
        coinTarget: _badgeOffset(_coinBadgeKey),
        onDone: entry.remove,
      ),
    );
    overlay.insert(entry);
  }

  static Offset? _badgeOffset(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) + box.size.center(Offset.zero);
  }

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
                  avatar: AvatarAvatar(
                    AvatarSpec.fromJsonString(p.avatarSpec),
                    size: 46,
                  ),
                  name: p.name,
                  trophies: p.trophies,
                  coins: p.coins,
                  trophyBadgeKey: _trophyBadgeKey,
                  coinBadgeKey: _coinBadgeKey,
                  onProfile: openProfile,
                  onRoad: openHouseTour,
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
                          onBattle: startBattle,
                          onRoad: openHouseTour,
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
                  shopBadge: p.dailyReady,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Victory celebration overlay: a trophy and a paw coin arc from the
/// screen centre into the HUD badges, then fade out. Pure overlay +
/// AnimationController — no external libraries.
class _VictoryFlight extends StatefulWidget {
  const _VictoryFlight({
    required this.trophyTarget,
    required this.coinTarget,
    required this.onDone,
  });

  /// Badge centres in global coordinates; null = fly to the top bar area.
  final Offset? trophyTarget, coinTarget;
  final VoidCallback onDone;

  @override
  State<_VictoryFlight> createState() => _VictoryFlightState();
}

class _VictoryFlightState extends State<_VictoryFlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final from = Offset(size.width / 2, size.height * .55);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          children: [
            _flyer(
              sprite('icon_trophy', size: 34),
              from,
              widget.trophyTarget ?? Offset(size.width * .38, 40),
              0,
            ),
            _flyer(
              sprite('icon_paw_coin', size: 30),
              from + const Offset(30, 14),
              widget.coinTarget ?? Offset(size.width * .62, 40),
              .18,
            ),
          ],
        ),
      ),
    );
  }

  /// One sprite arcing upward to its target with a fade-out tail.
  Widget _flyer(Widget child, Offset from, Offset to, double delay) {
    final t = ((_c.value - delay) / (1 - delay)).clamp(0.0, 1.0);
    final eased = Curves.easeInOut.transform(t);
    final arc = sin(eased * pi) * 90; // parabolic hop upward
    final pos = Offset.lerp(from, to, eased)! - Offset(0, arc);
    final opacity = t < .82 ? 1.0 : (1 - t) / .18;
    return Positioned(
      left: pos.dx - 17,
      top: pos.dy - 17,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.scale(scale: 1.25 - .45 * eased, child: child),
      ),
    );
  }
}
