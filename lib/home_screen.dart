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
import 'shell/friend_room.dart';
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
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => HouseTourScreen(player: p)));
  }

  /// Avatar / name tap → the dedicated profile page (was a dialog).
  void openProfile() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => ProfileScreen(player: p)));
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

  /// Dedicated full-bleed art per tab — crossfaded on every switch.
  static const _pageBgs = [
    'bg_shop', // MAGAZIN
    'bg_cats', // PISICI
    'bg_battle_lobby', // LUPTĂ
    'bg_team', // ECHIPĂ
    'bg_events', // EVENIMENTE
  ];

  /// Hamburger menu entries — the hub shortcuts plus settings, styled like
  /// the reference dropdown menus. Every entry opens a real surface.
  static const _menuItems = [
    (
      id: 'daily',
      ro: 'Recompensa zilnică',
      en: 'Daily reward',
      asset: 'paws_daily_5',
    ),
    (id: 'friends', ro: 'Prieteni', en: 'Friends', asset: 'icon_friends'),
    (
      id: 'ranks',
      ro: 'Clasament',
      en: 'Leaderboard',
      asset: 'icon_leaderboard',
    ),
    (id: 'news', ro: 'Noutăți', en: 'News', asset: 'icon_events'),
    (id: 'support', ro: 'Suport', en: 'Support', asset: null),
    (id: 'account', ro: 'Cont', en: 'Account', asset: 'icon_cloud_account'),
    (id: 'settings', ro: 'Setări', en: 'Settings', asset: null),
  ];

  void menuAction(String id) {
    Navigator.pop(context);
    switch (id) {
      case 'daily':
        select(0);
      case 'friends':
        showFriendRoom(context, english: p.english, player: p);
      case 'ranks':
        showLeaderboard(context, english: p.english, player: p);
      case 'news':
        showAppDialog(
          context,
          p.english ? 'News' : 'Noutăți',
          Text(
            'Versiunea $appVersion • Cinci tab-uri, un singur mod de joc și identitate One Ear Games.',
          ),
        );
      case 'support':
        unavailable(p.english ? 'Support' : 'Suport');
      case 'account':
        showAccount(context, p);
      case 'settings':
        showSettings(context, p);
    }
  }

  /// One glossy row inside the floating menu panel: icon tile, label,
  /// chevron — plus a real red badge for the claimable daily reward.
  Widget _menuTile(
    String id,
    String label,
    String? asset, {
    bool badge = false,
  }) {
    const fallbacks = {
      'daily': Icons.card_giftcard_rounded,
      'friends': Icons.people_alt_rounded,
      'ranks': Icons.leaderboard_rounded,
      'news': Icons.newspaper_rounded,
      'support': Icons.support_agent_rounded,
      'account': Icons.account_circle_rounded,
      'settings': Icons.settings_rounded,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => menuAction(id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xdd8a5c3e), Color(0xdd5d3a2c)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x55ffe9bd), width: 1.2),
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0x553c241a),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: asset != null
                          ? arenaImage(
                              asset,
                              fit: BoxFit.contain,
                              fallback: Icon(
                                fallbacks[id],
                                color: gold,
                                size: 19,
                              ),
                            )
                          : Icon(fallbacks[id], color: gold, size: 20),
                    ),
                    if (badge)
                      Positioned(
                        right: -3,
                        top: -3,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xffe2433a),
                            shape: BoxShape.circle,
                            border: Border.all(color: cream, width: 1.4),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: cream,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: gold, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: p,
    builder: (context, _) => Scaffold(
      key: scaffold,
      // Floating dropdown panel under the hamburger — the reference menus
      // are compact rounded cards, not a full-height drawer.
      endDrawer: Drawer(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(30, 8, 8, 8),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xfff8e7bd), Color(0xfff0d49b)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: gold, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x6620130e),
                      offset: Offset(0, 6),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6, top: 4),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.pop(context),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Color(0xff8a5a3b),
                            ),
                          ),
                        ),
                      ),
                    ),
                    for (final item in _menuItems)
                      _menuTile(
                        item.id,
                        p.english ? item.en : item.ro,
                        item.asset,
                        badge: item.id == 'daily' && p.dailyReady,
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      // Full-bleed page art climbs under the status bar; only the four
      // floating HUD elements sit inside the safe area on top of it.
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(
                key: ValueKey('bg-$tab'),
                child: arenaImage(
                  _pageBgs[tab],
                  fit: BoxFit.cover,
                  fallback: RoomBackground(
                    tier: p.tier,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Column(
                  children: [
                    PlayerHud(
                      avatar: playerAvatarArt(p, size: 46),
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
                            onShop: () => select(0),
                          ),
                          TeamScreen(player: p, onUnavailable: unavailable),
                          EventsScreen(player: p, onUnavailable: unavailable),
                        ],
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
        ],
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
