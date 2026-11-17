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
  'bg_hallway',
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
  });
  final Player player;
  final void Function(HouseCat? cat) onBattle;
  final VoidCallback onRoad;

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
                  Expanded(child: Center(child: _catScene(context))),
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
                                  ? (english
                                        ? 'ALL ROOMS'
                                        : 'TOATE CAMERELE')
                                  : (english
                                        ? 'NEXT: ${houseRoomDisplayNamesEn[index + 1]} @ ${next.threshold}'
                                        : 'URM.: ${houseRoomDisplayNames[index + 1]} LA ${next.threshold}'),
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

  /// The player's cat sitting on its cushion in the middle of the room.
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
          height: height + 46,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                bottom: 0,
                child: arenaImage(
                  'cat_cushion',
                  width: min(320, MediaQuery.sizeOf(context).width * .8),
                  fit: BoxFit.contain,
                  fallback: CustomPaint(
                    size: Size(
                      min(320, MediaQuery.sizeOf(context).width * .8),
                      64,
                    ),
                    painter: const _RugPainter(),
                  ),
                ),
              ),
              Positioned(
                bottom: 26,
                child: catAsset == null
                    ? CatCharacter(player, height: height)
                    : arenaImage(
                        catAsset,
                        height: height,
                        fit: BoxFit.contain,
                        fallback: CatCharacter(player, height: height),
                      ),
              ),
            ],
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
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
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
        SizedBox(
          width: double.infinity,
          child: ArenaButton(
            key: const ValueKey('lobby-fight'),
            text: english ? 'BATTLE' : 'LUPTĂ',
            onPressed: () => _modeChooser(context),
            spriteName: 'btn_play_paw',
          ),
        ),
        const SizedBox(height: 6),
        _hubRow(context),
      ],
    ),
  );

  /// Compact hub entries on the main screen: friend room, local
  /// leaderboard and the Google link inside settings. Small dark chips so
  /// the scene keeps breathing.
  Widget _hubRow(BuildContext context) {
    Widget chip(String label, IconData icon, VoidCallback tap, {String? key_}) {
      return Material(
        color: const Color(0x9926131e),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          key: key_ == null ? null : ValueKey(key_),
          onTap: tap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: gold, size: 15),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(
                    color: cream,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .6,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Center(
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: [
          chip(
            english ? 'FRIENDS' : 'PRIETENI',
            Icons.people_alt_rounded,
            () => showFriendRoom(context, english: english, player: player),
            key_: 'hub-friends',
          ),
          chip(
            english ? 'LEADERBOARD' : 'CLASAMENT',
            Icons.leaderboard_rounded,
            () => showLeaderboard(context, english: english, player: player),
            key_: 'hub-ranks',
          ),
          chip(
            english ? 'LINK ACCOUNT' : 'CONECTARE CONT',
            Icons.account_circle_rounded,
            () => showSettings(context, player),
            key_: 'hub-account',
          ),
        ],
      ),
    );
  }
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
        for (final cat in room.cats) (name: cat.name, trophies: cat.trophies, you: false),
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

/// Oval cushion/rug the cat sits on: wooden rim, woven centre and a
/// stitched edge — procedural fallback for `cat_cushion.png`.
class _RugPainter extends CustomPainter {
  const _RugPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint();
    paint.color = const Color(0xff7c4a34);
    canvas.drawOval(rect.deflate(3), paint);
    paint.color = const Color(0xffb5654a);
    canvas.drawOval(rect.deflate(9), paint);
    paint.color = const Color(0xffd9a05f);
    canvas.drawOval(rect.deflate(15), paint);
    paint
      ..color = const Color(0x88a86a3c)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawOval(rect.deflate(21), paint);
    paint.style = PaintingStyle.fill;
    // Woven diamond motif.
    paint.color = const Color(0x66a86a3c);
    for (var i = 0; i < 5; i++) {
      final cx = size.width * (.2 + i * .15);
      final cy = size.height * .5;
      canvas.drawPath(
        Path()
          ..moveTo(cx, cy - 7)
          ..lineTo(cx + 6, cy)
          ..lineTo(cx, cy + 7)
          ..lineTo(cx - 6, cy)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RugPainter oldDelegate) => false;
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
