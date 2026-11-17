import 'package:flutter/material.dart';

import 'profile.dart';
import 'shell/house_tour.dart';
import 'ui_widgets.dart';

/// Trophy road / house tour: a vertical illustrated map of the four house
/// rooms climbed with trophies, exactly like the ui_turul_casei reference —
/// golden paw-print path, milestone chests, room medallions (unlocked /
/// glowing active / locked padlock) and a crown + gold fish on the last
/// room. Milestones only: no bot nodes on the path. Opened from the HUD
/// trophy badge and the lobby progress strip.
class HouseTourScreen extends StatelessWidget {
  const HouseTourScreen({super.key, required this.player});

  final Player player;

  static const _icons = [
    Icons.weekend_rounded,
    Icons.meeting_room_rounded,
    Icons.kitchen_rounded,
    Icons.bed_rounded,
  ];

  /// Medallion room art, indexed like [houseRooms] (lane-1 `assets/images/`).
  static const _roomArt = [
    'bg_living_room',
    'bg_hallway',
    'bg_kitchen',
    'bg_bedroom',
  ];

  /// Mockup zigzag: rooms 1-2 sit left, rooms 3-4 sit right.
  static const _sides = [false, false, true, true];

  bool get english => player.english;

  @override
  Widget build(BuildContext context) {
    final names = english ? houseRoomDisplayNamesEn : houseRoomDisplayNames;
    final currentIndex = houseRooms.indexOf(
      houseRoomForTrophies(player.trophies),
    );
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
                    for (var i = houseRooms.length - 1; i >= 0; i--) ...[
                      _RoomNode(
                        player: player,
                        index: i,
                        name: names[i],
                        icon: _icons[i],
                        art: _roomArt[i],
                        isCurrent: i == currentIndex,
                        rightSide: _sides[i],
                      ),
                      if (i > 0)
                        _MilestoneConnector(
                          reached: player.trophies >= houseRooms[i].threshold,
                        ),
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
          tooltip: english ? 'Back' : 'Înapoi',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, color: cream, size: 26),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                english ? 'HOUSE TOUR' : 'TURUL CASEI',
                style: const TextStyle(
                  color: cream,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  shadows: [
                    Shadow(color: Color(0x66000000), offset: Offset(0, 2)),
                  ],
                ),
              ),
              Text(
                english
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

/// One milestone on the map: a round room medallion (art inside, padlock
/// when locked, golden glow when it is the current room) plus the room
/// name and trophy threshold. The top room carries crown + gold fish.
class _RoomNode extends StatelessWidget {
  const _RoomNode({
    required this.player,
    required this.index,
    required this.name,
    required this.icon,
    required this.art,
    required this.isCurrent,
    required this.rightSide,
  });

  final Player player;
  final int index;
  final String name;
  final IconData icon;
  final String art;
  final bool isCurrent, rightSide;

  @override
  Widget build(BuildContext context) {
    final room = houseRooms[index];
    final unlocked = player.trophies >= room.threshold;
    final cleared = index + 1 < houseRooms.length
        ? player.trophies >= houseRooms[index + 1].threshold
        : player.trophies >= houseRoomThresholds.last;
    final state = !unlocked
        ? (player.english
              ? 'LOCKED AT ${room.threshold} TROPHIES'
              : 'BLOCATĂ LA ${room.threshold} TROFEE')
        : isCurrent
        ? (player.english ? 'CURRENT ROOM' : 'CAMERA CURENTĂ')
        : cleared
        ? (player.english ? 'CLEARED' : 'CURĂȚATĂ')
        : (player.english ? 'UNLOCKED' : 'DESCHISĂ');
    final texts = Column(
      crossAxisAlignment: rightSide
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${index + 1}. $name',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: rightSide ? TextAlign.end : TextAlign.start,
          style: TextStyle(
            color: unlocked ? cream : const Color(0xffb7a89a),
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            shadows: const [
              Shadow(color: Color(0x77000000), offset: Offset(0, 1)),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            sprite('icon_trophy', size: 13),
            const SizedBox(width: 3),
            Text(
              '(${room.threshold})',
              style: const TextStyle(
                color: gold,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          state,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: unlocked ? const Color(0xffffe0a8) : Colors.white54,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
    return Padding(
      padding: EdgeInsets.only(
        left: rightSide ? 60 : 6,
        right: rightSide ? 6 : 60,
        top: 4,
        bottom: 4,
      ),
      child: Align(
        alignment: rightSide ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: rightSide
              ? [
                  Flexible(child: texts),
                  const SizedBox(width: 12),
                  _medallion(unlocked),
                ]
              : [
                  _medallion(unlocked),
                  const SizedBox(width: 12),
                  Flexible(child: texts),
                ],
        ),
      ),
    );
  }

  Widget _medallion(bool unlocked) {
    final glow = isCurrent && unlocked;
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: unlocked ? (isCurrent ? gold : const Color(0xffe0b070)) : const Color(0xff6d5f55),
          width: isCurrent ? 4 : 3,
        ),
        boxShadow: [
          if (glow)
            const BoxShadow(
              color: Color(0xbbffc63c),
              blurRadius: 22,
              spreadRadius: 3,
            ),
          const BoxShadow(
            color: Color(0x66000000),
            offset: Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipOval(
            child: ColorFiltered(
              colorFilter: unlocked
                  ? const ColorFilter.mode(
                      Colors.transparent,
                      BlendMode.multiply,
                    )
                  : const ColorFilter.mode(
                      Color(0xff9a8d80),
                      BlendMode.saturation,
                    ),
              child: arenaImage(
                art,
                width: 88,
                height: 88,
                fit: BoxFit.cover,
                fallback: Container(
                  width: 88,
                  height: 88,
                  color: unlocked
                      ? const Color(0xfff0d9b0)
                      : const Color(0xff9a8d80),
                  child: Icon(icon, color: ink, size: 36),
                ),
              ),
            ),
          ),
          if (!unlocked)
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xe6352b28),
                shape: BoxShape.circle,
                border: Border.all(color: cream, width: 1.4),
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: cream,
                size: 19,
              ),
            ),
          // The top room carries the crown + gold fish trophy.
          if (index == houseRooms.length - 1) ...[
            const Positioned(
              top: -2,
              child: Icon(
                Icons.emoji_events_rounded,
                color: Color(0xffffd75e),
                size: 26,
              ),
            ),
            Positioned(
              right: -6,
              bottom: 2,
              child: arenaImage(
                'trophy_gold_fish',
                width: 40,
                height: 40,
                fallback: sprite('icon_golden_fish', size: 40),
              ),
            ),
          ],
          // Tzuki sits beside the current room like in the reference.
          if (glow)
            Positioned(
              left: -10,
              bottom: -4,
              child: arenaImage(
                'cat_tzuki',
                width: 42,
                height: 42,
                fit: BoxFit.contain,
                fallback: const Icon(Icons.pets, color: cream, size: 26),
              ),
            ),
        ],
      ),
    );
  }
}

/// Golden paw-print trail + milestone chest between two rooms. The chest
/// glows once the player has actually reached the next threshold.
class _MilestoneConnector extends StatelessWidget {
  const _MilestoneConnector({required this.reached});
  final bool reached;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 74,
    child: Stack(
      alignment: Alignment.center,
      children: [
        const Positioned.fill(
          child: CustomPaint(painter: _PawTrailPainter()),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: reached ? 1 : .55,
              child: arenaImage(
                'milestone_chest',
                width: 44,
                height: 44,
                fallback: sprite('icon_chest', size: 44),
              ),
            ),
            Text(
              'MILESTONE',
              style: TextStyle(
                color: reached ? gold : Colors.white54,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
                shadows: const [
                  Shadow(color: Color(0x88000000), offset: Offset(0, 1)),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Staggered golden paw prints climbing the screen between milestones.
class _PawTrailPainter extends CustomPainter {
  const _PawTrailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xccffc63c);
    const n = 3;
    for (var i = 0; i < n; i++) {
      final t = (i + 0.5) / n;
      final x = size.width * (0.5 + (i.isEven ? -0.09 : 0.09));
      final y = size.height * (1 - t);
      _paw(canvas, Offset(x, y), 7.5, paint);
    }
  }

  void _paw(Canvas canvas, Offset c, double r, Paint paint) {
    canvas.drawOval(Rect.fromCenter(center: c, width: r * 1.7, height: r * 1.4), paint);
    for (final (dx, dy) in [(-1.1, -1.0), (0.0, -1.35), (1.1, -1.0)]) {
      canvas.drawCircle(c + Offset(dx * r, dy * r), r * .48, paint);
    }
  }

  @override
  bool shouldRepaint(_PawTrailPainter oldDelegate) => false;
}
