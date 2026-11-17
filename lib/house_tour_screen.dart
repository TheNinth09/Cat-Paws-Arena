import 'package:flutter/material.dart';

import 'cat_avatar.dart';
import 'profile.dart';
import 'shell/house_tour.dart';
import 'ui_widgets.dart';

/// Trophy road / house tour: a vertical illustrated map of the four house
/// rooms climbed with trophies. Unlocked rooms show their resident house
/// cats (labelled BOT); locked rooms show a padlock. Replaces the old
/// trophy-road dialog — opened from the HUD trophy badge and the lobby
/// progress strip.
class HouseTourScreen extends StatelessWidget {
  const HouseTourScreen({
    super.key,
    required this.player,
    this.onBattle,
  });

  final Player player;

  /// Called when the player picks a house cat on an unlocked room; the host
  /// routes it through the VS screen into the duel. Null renders the map
  /// read-only.
  final void Function(HouseCat cat)? onBattle;

  static const _icons = [
    Icons.weekend_rounded,
    Icons.meeting_room_rounded,
    Icons.kitchen_rounded,
    Icons.bed_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final names = player.english
        ? houseRoomDisplayNamesEn
        : houseRoomDisplayNames;
    final currentIndex = houseRooms.indexOf(houseRoomForTrophies(player.trophies));
    return Scaffold(
      backgroundColor: const Color(0xff3a2a33),
      body: SafeArea(
        child: RoomBackground(
          tier: player.tier,
          dim: true,
          child: Column(
            children: [
              _header(context),
              Expanded(
                child: ListView(
                  key: const PageStorageKey('house-tour-scroll'),
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                  children: [
                    for (var i = 0; i < houseRooms.length; i++) ...[
                      _RoomNode(
                        player: player,
                        index: i,
                        name: names[i],
                        icon: _icons[i],
                        isCurrent: i == currentIndex,
                        onBattle: onBattle,
                      ),
                      if (i < houseRooms.length - 1)
                        const _PathConnector(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
    child: Row(
      children: [
        IconButton(
          key: const ValueKey('house-tour-close'),
          tooltip: player.english ? 'Back' : 'Înapoi',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, color: cream, size: 26),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                player.english ? 'HOUSE TOUR' : 'TURUL CASEI',
                style: const TextStyle(
                  color: cream,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  shadows: [Shadow(color: Color(0x66000000), offset: Offset(0, 2))],
                ),
              ),
              Text(
                player.english
                    ? 'TROPHY ROAD • ${player.trophies} trophies'
                    : 'DRUMUL TROFEELOR • ${player.trophies} trofee',
                style: const TextStyle(
                  color: Color(0xffe8c9a0),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 48),
      ],
    ),
  );
}

/// One room node: medallion (locked padlock / gold / glowing current),
/// display name, trophy threshold and — for unlocked rooms — the resident
/// house cats as tappable BOT chips.
class _RoomNode extends StatelessWidget {
  const _RoomNode({
    required this.player,
    required this.index,
    required this.name,
    required this.icon,
    required this.isCurrent,
    required this.onBattle,
  });

  final Player player;
  final int index;
  final String name;
  final IconData icon;
  final bool isCurrent;
  final void Function(HouseCat cat)? onBattle;

  @override
  Widget build(BuildContext context) {
    final room = houseRooms[index];
    final unlocked = player.trophies >= room.threshold;
    final cleared = index + 1 < houseRooms.length
        ? player.trophies >= houseRooms[index + 1].threshold
        : player.trophies >= houseRoomThresholds.last;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: unlocked
              ? const [Color(0xfffff3d2), Color(0xfff6d9a0), Color(0xffe8b877)]
              : const [Color(0xffd8cfc4), Color(0xffc4b8ac), Color(0xffa99a8d)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent ? gold : ink,
          width: isCurrent ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrent
                ? const Color(0x88ffc63c)
                : const Color(0x553c241a),
            offset: const Offset(0, 4),
            blurRadius: isCurrent ? 16 : 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _medallion(unlocked),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}. $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unlocked
                          ? (isCurrent
                                ? (player.english
                                      ? 'CURRENT ROOM'
                                      : 'CAMERA CURENTĂ')
                                : (cleared
                                      ? (player.english
                                            ? 'CLEARED'
                                            : 'CURĂȚATĂ')
                                      : (player.english
                                            ? 'UNLOCKED'
                                            : 'DESCHISĂ')))
                          : (player.english
                                ? 'LOCKED AT ${room.threshold} TROPHIES'
                                : 'BLOCATĂ LA ${room.threshold} TROFEE'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: unlocked ? const Color(0xff7a4a32) : ink,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (index == houseRooms.length - 1) ...[
                const Icon(Icons.emoji_events, color: Color(0xffb8860b), size: 30),
                const SizedBox(width: 4),
                arenaImage(
                  'trophy_gold_fish',
                  width: 34,
                  height: 34,
                  fallback: sprite('icon_golden_fish', size: 34),
                ),
              ],
            ],
          ),
          if (unlocked) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cat in room.cats)
                  _HouseCatChip(
                    player: player,
                    cat: cat,
                    enabled: onBattle != null,
                    onTap: () => onBattle?.call(cat),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _medallion(bool unlocked) {
    final glow = isCurrent;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: unlocked
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xfffff3c4), gold, Color(0xffe8a92e)],
              )
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xffb7ab9e), Color(0xff8d8177)],
              ),
        border: Border.all(color: ink, width: 2.5),
        boxShadow: [
          if (glow)
            const BoxShadow(
              color: Color(0x99ffc63c),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          const BoxShadow(
            color: Color(0x5561312d),
            offset: Offset(0, 3),
            blurRadius: 4,
          ),
        ],
      ),
      child: unlocked
          ? (isCurrent
                ? arenaImage(
                    'cat_tzuki',
                    width: 52,
                    height: 52,
                    fit: BoxFit.contain,
                    fallback: Icon(icon, color: ink, size: 30),
                  )
                : Icon(icon, color: ink, size: 30))
          : const Icon(Icons.lock_rounded, color: Color(0xff4a3f38), size: 30),
    );
  }
}

/// House-cat chip on an unlocked room: avatar + name + level, labelled BOT.
/// Tapping it starts a duel against that cat when [onBattle] is wired.
class _HouseCatChip extends StatelessWidget {
  const _HouseCatChip({
    required this.player,
    required this.cat,
    required this.enabled,
    required this.onTap,
  });

  final Player player;
  final HouseCat cat;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0x66ffffff),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ink, width: 1.4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CatAvatar(houseCatPlayer(player.prefs, cat), size: 34),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cat.name,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Nv ${cat.level} • BOT',
                  style: const TextStyle(
                    color: Color(0xff8a5a3b),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Vertical connector between two rooms: golden paw prints climbing the
/// path with the milestone chest sitting on it.
class _PathConnector extends StatelessWidget {
  const _PathConnector();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 58,
    child: Stack(
      alignment: Alignment.center,
      children: [
        const Positioned.fill(
          child: CustomPaint(painter: _PawTrailPainter()),
        ),
        arenaImage(
          'milestone_chest',
          width: 40,
          height: 40,
          fallback: sprite('icon_chest', size: 40),
        ),
      ],
    ),
  );
}

/// Golden paw prints stacked along a vertical trail.
class _PawTrailPainter extends CustomPainter {
  const _PawTrailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xccffc63c);
    const prints = 3;
    for (var i = 0; i < prints; i++) {
      final t = (i + 1) / (prints + 1);
      final cx = size.width * (i.isEven ? .38 : .62);
      final cy = size.height * t;
      final sway = i.isEven ? -6.0 : 6.0;
      // Main pad.
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: 14, height: 11),
        paint,
      );
      // Toes.
      for (var toe = -1; toe <= 1; toe++) {
        canvas.drawCircle(
          Offset(cx + toe * 6.5 + sway * .3, cy - 8),
          3.1,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PawTrailPainter oldDelegate) => false;
}
