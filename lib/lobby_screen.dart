import 'dart:math';

import 'package:flutter/material.dart';

import 'app_dialogs.dart';
import 'cat_avatar.dart';
import 'catalog.dart';
import 'profile.dart';
import 'shell/friend_room.dart';
import 'shell/house_tour.dart';
import 'ui_widgets.dart';

/// Room background art per house-tour room (lane-1 `assets/images/`). The
/// procedural [RoomBackground] painter is the fallback until the bundle
/// carries the PNGs.
const _roomBackgrounds = [
  'bg_living_room',
  'bg_main_hall',
  'bg_kitchen',
  'bg_bedroom',
];

const _goldGradient = LinearGradient(
  colors: [Color(0xfffff3c4), gold, Color(0xffe8a92e)],
);

/// Picks the house-cat opponent for a LUPTĂ press: a random cat from every
/// room the player has unlocked (threshold <= trophies). Returns null only
/// when no room is unlocked, which cannot happen because room one starts at
/// 0 trophies.
HouseCat? pickBattleCat(Player player, [int? seed]) {
  final unlocked = <HouseCat>[
    for (final room in houseRooms)
      if (player.trophies >= room.threshold) ...room.cats,
  ];
  if (unlocked.isEmpty) return null;
  final random = seed == null ? Random() : Random(seed);
  return unlocked[random.nextInt(unlocked.length)];
}

class LobbyScreen extends StatelessWidget {
  const LobbyScreen({
    super.key,
    required this.player,
    required this.onBattle,
    required this.onRoad,
    required this.onShop,
  });
  final Player player;
  final void Function(HouseCat? cat) onBattle;
  final VoidCallback onRoad;

  /// SARCINI → daily reward row jumps to the shop tab.
  final VoidCallback onShop;

  String get _bgAsset =>
      _roomBackgrounds[player.tier.clamp(0, _roomBackgrounds.length - 1)];

  bool get english => player.english;

  void _offline(BuildContext context) {
    Navigator.of(context).pop();
    onBattle(pickBattleCat(player));
  }

  void _online(BuildContext context) {
    Navigator.of(context).pop();
    showFriendRoom(context, english: english, player: player);
  }

  /// LUPTĂ → mode chooser: offline practice against the labelled house
  /// cats, or the six-character friend room. One calm dialog, no cards.
  void _modeChooser(BuildContext context) => showAppDialog(
    context,
    english ? 'CHOOSE MODE' : 'ALEGE MODUL',
    _ModeChooser(
      english: english,
      onOffline: () => _offline(context),
      onOnline: () => _online(context),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Compact when the *page viewport* (not the full screen) is short or
        // text is scaled up — the scene and controls then scroll instead of
        // overflowing.
        final compact = constraints.maxHeight < 620 || textScale > 1.3;
        final content = compact
            ? ListView(
                key: const PageStorageKey('lobby-scroll'),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                children: [
                  _progressStrip(),
                  const SizedBox(height: 4),
                  _catScene(context, compact: true),
                  const SizedBox(height: 6),
                  _controls(context),
                ],
              )
            : Column(
                children: [
                  _progressStrip(),
                  // Foreground: the cat stands at floor level,
                  // not floating mid-room.
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: _catScene(context),
                    ),
                  ),
                  _controls(context),
                ],
              );
        return Stack(
          fit: StackFit.expand,
          children: [
            arenaImage(
              _bgAsset,
              fit: BoxFit.cover,
              fallback: RoomBackground(
                tier: player.tier,
                child: const SizedBox.expand(),
              ),
            ),
            // Legibility scrim so text and buttons stay readable over the art.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x5520130e),
                    Color(0x0020130e),
                    Color(0x6620130e),
                  ],
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
            content,
          ],
        );
      },
    );
  }

  /// Slim trophy progress strip: current/next threshold, a thumbnail of the
  /// room being unlocked and the milestone chest. Taps open the house tour.
  Widget _progressStrip() {
    final current = houseRoomForTrophies(player.trophies);
    final index = houseRooms.indexOf(current);
    final next = index + 1 < houseRooms.length ? houseRooms[index + 1] : null;
    final start = current.threshold;
    final end = next?.threshold ?? current.threshold;
    final ratio = next == null
        ? 1.0
        : ((player.trophies - start) / (end - start)).clamp(0.0, 1.0);
    final thumb = next == null
        ? _roomBackgrounds[index]
        : _roomBackgrounds[index + 1];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('trophy-progress'),
          onTap: onRoad,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xff8a6242), Color(0xff6b4634)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: gold, width: 1.6),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  offset: Offset(0, 3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: arenaImage(
                      thumb,
                      fit: BoxFit.cover,
                      fallback: Container(
                        color: const Color(0xff5d3a2c),
                        child: const Icon(
                          Icons.home_rounded,
                          color: gold,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${player.trophies} / $end',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: cream,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(
                                    color: Color(0x66000000),
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              next == null
                                  ? (english ? 'ALL ROOMS' : 'TOATE CAMERELE')
                                  : english
                                  ? 'NEXT: ${houseRoomDisplayNamesEn[index + 1]} @ ${next.threshold} • ~${((next.threshold - player.trophies) / 30).ceil()} W'
                                  : 'URM.: ${houseRoomDisplayNames[index + 1]} LA ${next.threshold} • ~${((next.threshold - player.trophies) / 30).ceil()} VIC.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xffe8c9a0),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xff432c33),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: ink, width: 1.2),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: ratio,
                            heightFactor: 1,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: _goldGradient,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                arenaImage(
                  'milestone_chest',
                  width: 34,
                  height: 34,
                  fallback: sprite('icon_chest', size: 34),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The player's cat standing in the middle of the room.
  Widget _catScene(BuildContext context, {bool compact = false}) {
    final height = compact ? 170.0 : 205.0;
    final catAsset = switch (player.cat) {
      'Tzuki' => 'cat_tzuki',
      'Bubble' => 'cat_bubble',
      _ => null,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height + 8,
          child: catAsset == null
              ? CatCharacter(player, height: height)
              : arenaImage(
                  catAsset,
                  height: height,
                  fit: BoxFit.contain,
                  fallback: CatCharacter(player, height: height),
                ),
        ),
        const SizedBox(height: 2),
        label(player.cat, size: 24),
        _PowerPill(
          powerNames[player.cat == 'Tzuki'
              ? 0
              : player.cat == 'Bubble'
              ? 1
              : player.power],
        ),
      ],
    );
  }

  Widget _controls(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          // Small decorative badge: clamp text scaling so the label can
          // never overflow the pill at 1.5x on narrow screens.
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(
                min(MediaQuery.textScalerOf(context).scale(16) / 16, 1.15),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xcc1d3f7a),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: gold, width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sports_esports, color: gold, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    english ? 'MODE: 1v1 ARENA' : 'MOD: 1v1 ARENA',
                    style: const TextStyle(
                      color: cream,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Royal-Kingdom-style row: round hub buttons flanking the big PLAY.
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _RoundHubButton(
              label: english ? 'LEADERBOARD' : 'CLASAMENT',
              iconAsset: 'icon_leaderboard',
              fallback: Icons.leaderboard_rounded,
              onTap: () =>
                  showLeaderboard(context, english: english, player: player),
              key_: const ValueKey('hub-ranks'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PlayButton(
                text: english ? 'PLAY' : 'LUPTĂ',
                onTap: () => _modeChooser(context),
              ),
            ),
            const SizedBox(width: 10),
            _RoundHubButton(
              label: english ? 'TASKS' : 'SARCINI',
              iconAsset: 'icon_achievements',
              fallback: Icons.flag_rounded,
              onTap: () => _quests(context),
              key_: const ValueKey('hub-quests'),
            ),
          ],
        ),
      ],
    ),
  );

  /// SARCINI — the real objectives list: the daily reward (jumps to the
  /// shop), the next house-tour milestone (jumps to the tour map) and the
  /// honest milestone-chest counter. No invented task system.
  void _quests(BuildContext context) {
    final current = houseRoomForTrophies(player.trophies);
    final index = houseRooms.indexOf(current);
    final next = index + 1 < houseRooms.length ? houseRooms[index + 1] : null;
    final chests = houseRooms
        .where((room) => player.claims.contains(room.threshold))
        .length;
    showAppDialog(
      context,
      english ? 'TASKS' : 'SARCINI',
      Builder(
        builder: (dialogContext) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _QuestRow(
              iconAsset: 'paws_daily_5',
              fallback: Icons.card_giftcard_rounded,
              title: english ? 'DAILY REWARD' : 'RECOMPENSA ZILNICĂ',
              subtitle: player.dailyReady
                  ? (english ? 'Ready to claim' : 'Disponibilă acum')
                  : (english ? 'Come back later' : 'Revino mai târziu'),
              action: english ? 'OPEN' : 'DESCHIDE',
              onTap: () {
                Navigator.pop(dialogContext);
                onShop();
              },
            ),
            _QuestRow(
              iconAsset: 'milestone_chest',
              fallback: Icons.flag_rounded,
              title: english ? 'NEXT MILESTONE' : 'URMĂTORUL PRAG',
              subtitle: next == null
                  ? (english
                        ? 'All rooms unlocked'
                        : 'Toate camerele deblocate')
                  : english
                  ? '${houseRoomDisplayNamesEn[index + 1]} at ${next.threshold} trophies'
                  : '${houseRoomDisplayNames[index + 1]} la ${next.threshold} trofee',
              action: english ? 'VIEW' : 'VEZI',
              onTap: () {
                Navigator.pop(dialogContext);
                onRoad();
              },
            ),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xfffff9e8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xffe0c294), width: 1.2),
              ),
              child: Row(
                children: [
                  arenaImage(
                    'icon_chest',
                    width: 30,
                    height: 30,
                    fallback: const Icon(
                      Icons.inventory_2_rounded,
                      color: Color(0xff8a6242),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      english
                          ? 'MILESTONE CHESTS: $chests/${houseRooms.length}'
                          : 'CUFERE DE PRAG: $chests/${houseRooms.length}',
                      style: const TextStyle(
                        color: ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round glossy hub button flanking the LUPTĂ button — circle with bundled
/// art plus a tiny label underneath, like the reference home screens.
class _RoundHubButton extends StatelessWidget {
  const _RoundHubButton({
    required this.label,
    required this.iconAsset,
    required this.fallback,
    required this.onTap,
    required this.key_,
  });
  final String label, iconAsset;
  final IconData fallback;
  final VoidCallback onTap;
  final Key key_;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Material(
        color: Colors.transparent,
        child: InkWell(
          key: key_,
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 54,
            height: 54,
            padding: const EdgeInsets.all(9),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xdd8a5c3e), Color(0xdd5d3a2c)],
              ),
              border: Border.fromBorderSide(BorderSide(color: gold, width: 2)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x66000000),
                  offset: Offset(0, 3),
                  blurRadius: 6,
                ),
              ],
            ),
            foregroundDecoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x45ffffff), Color(0x00ffffff)],
                stops: [0, 0.45],
              ),
            ),
            child: arenaImage(
              iconAsset,
              fit: BoxFit.contain,
              fallback: Icon(fallback, color: gold, size: 26),
            ),
          ),
        ),
      ),
      const SizedBox(height: 2),
      SizedBox(
        width: 66,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
              color: cream,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: .4,
              shadows: [Shadow(color: Color(0xcc20130e), offset: Offset(0, 1))],
            ),
          ),
        ),
      ),
    ],
  );
}

/// One row in the SARCINI dialog: icon tile, title + honest status, and a
/// small green action pill that navigates to the real surface.
class _QuestRow extends StatelessWidget {
  const _QuestRow({
    required this.iconAsset,
    required this.fallback,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onTap,
  });
  final String iconAsset, title, subtitle, action;
  final IconData fallback;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xfffff9e8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xffe0c294), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xff8a6242), Color(0xff6b4634)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: gold, width: 1.2),
                ),
                child: arenaImage(
                  iconAsset,
                  fit: BoxFit.contain,
                  fallback: Icon(fallback, color: gold, size: 22),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xff8a6242),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xff93d94f), Color(0xff4e9c22)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.4),
                ),
                child: Text(
                  action,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Hero PLAY/LUPTĂ button — big, glossy, gold with the paw sprite, styled
/// after the main call-to-action in the reference home screens.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      key: const ValueKey('lobby-fight'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 66,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xfffff6b8),
              Color(0xffffe08a),
              gold,
              Color(0xffeda52c),
              Color(0xffdf931f),
            ],
            stops: [0, .38, .62, .82, 1],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: ink, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x8851312d),
              offset: Offset(0, 5),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            sprite('tile_paw', size: 32),
            const SizedBox(width: 10),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                    shadows: [
                      Shadow(color: Color(0x66ffffff), offset: Offset(0, 2)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Mode chooser shown by the LUPTĂ button: offline against the house cats
/// (honest BOT label) or the existing six-character friend room.
class _ModeChooser extends StatelessWidget {
  const _ModeChooser({
    required this.english,
    required this.onOffline,
    required this.onOnline,
  });
  final bool english;
  final VoidCallback onOffline, onOnline;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ArenaButton(
        key: const ValueKey('mode-offline'),
        text: english ? 'VS HOUSE CATS' : 'CONTRA PISICILOR CASEI',
        green: true,
        onPressed: onOffline,
      ),
      _hint(
        english
            ? 'Offline practice — opponents are always labelled BOT.'
            : 'Antrenament offline — adversarii sunt mereu marcați BOT.',
      ),
      ArenaButton(
        key: const ValueKey('mode-online'),
        text: english ? 'FRIEND ROOM' : 'CAMERĂ DE PRIETEN',
        secondary: true,
        onPressed: onOnline,
      ),
      _hint(
        english
            ? 'Six-character room code — ONLINE duel when the service is configured.'
            : 'Cod de șase caractere — duel ONLINE când serviciul este configurat.',
      ),
    ],
  );

  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xff8a6242),
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
    ),
  );
}

/// Local leaderboard dialog: the LOCAL tab ranks the player against the
/// house cats by trophies (all values are real); the GLOBAL tab is plainly
/// labelled as not available yet — there is no ranked strangers feature.
Future<void> showLeaderboard(
  BuildContext context, {
  required bool english,
  required Player player,
}) => showAppDialog(
  context,
  english ? 'LEADERBOARD' : 'CLASAMENT',
  _LeaderboardPanel(english: english, player: player),
);

class _LeaderboardPanel extends StatefulWidget {
  const _LeaderboardPanel({required this.english, required this.player});
  final bool english;
  final Player player;

  @override
  State<_LeaderboardPanel> createState() => _LeaderboardPanelState();
}

class _LeaderboardPanelState extends State<_LeaderboardPanel> {
  bool global = false;

  bool get english => widget.english;
  Player get p => widget.player;

  @override
  Widget build(BuildContext context) {
    final entries = <({String name, int trophies, bool you})>[
      for (final room in houseRooms)
        for (final cat in room.cats)
          (name: cat.name, trophies: cat.trophies, you: false),
      (name: p.name, trophies: p.trophies, you: true),
    ]..sort((a, b) => b.trophies.compareTo(a.trophies));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _tab(
                english ? 'LOCAL' : 'LOCAL',
                selected: !global,
                onTap: () => setState(() => global = false),
                key_: 'ranks-local',
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _tab(
                english ? 'GLOBAL' : 'GLOBAL',
                selected: global,
                onTap: () => setState(() => global = true),
                key_: 'ranks-global',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (global)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.public_off_rounded,
                  color: Color(0xff8a6242),
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  english
                      ? 'Coming soon — there is no ranked play against strangers, so the global board is not live yet.'
                      : 'În curând — nu există clasament contra străinilor, așa că panoul global nu este încă activ.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xff8a6242),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          )
        else
          // Plain column: AlertDialog measures intrinsic dimensions, which
          // a scrollable viewport cannot provide.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < entries.length; i++) _row(i + 1, entries[i]),
            ],
          ),
      ],
    );
  }

  Widget _tab(
    String text, {
    required bool selected,
    required VoidCallback onTap,
    String? key_,
  }) => Material(
    color: selected ? gold : const Color(0xfffffbec),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      key: key_ == null ? null : ValueKey(key_),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? ink : const Color(0xff8a6242),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ),
    ),
  );

  Widget _row(int rank, ({String name, int trophies, bool you}) e) {
    final medal = switch (rank) {
      1 => const Color(0xffe8a92e),
      2 => const Color(0xffb9c0c8),
      3 => const Color(0xffc98f5a),
      _ => const Color(0xfffffbec),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: e.you ? const Color(0xffffe9bd) : const Color(0xfffffbec),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: e.you ? gold : const Color(0xffd9b98c),
          width: e.you ? 1.8 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: medal,
              border: Border.all(color: ink, width: 1.2),
            ),
            child: Text(
              '$rank',
              style: const TextStyle(
                color: ink,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              e.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ink,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            e.you ? (english ? 'YOU' : 'TU') : 'BOT',
            style: TextStyle(
              color: e.you ? const Color(0xffb0791f) : const Color(0xff8a6a52),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          sprite('icon_trophy', size: 15),
          const SizedBox(width: 3),
          Text(
            '${e.trophies}',
            style: const TextStyle(
              color: ink,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PowerPill extends StatelessWidget {
  const _PowerPill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    constraints: const BoxConstraints(maxWidth: 380),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xff7a4a32), Color(0xff5d3a2c)],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: gold, width: 1.5),
      boxShadow: const [
        BoxShadow(color: Color(0x5545312d), offset: Offset(0, 3)),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.bolt, color: gold, size: 18),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: cream,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}
