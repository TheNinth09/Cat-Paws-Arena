import 'package:flutter/material.dart';

import 'catalog.dart';
import 'cat_avatar.dart';
import 'profile.dart';
import 'shell/house_tour.dart';
import 'ui_widgets.dart';

/// Claims a road milestone and confirms it with a toast — every claim
/// surface (road chips, room reward, sheet route) calls this so taps
/// always produce visible feedback.
void _claimWithToast(
  BuildContext context,
  Player player,
  int trophies, {
  int coins = 0,
  String? emote,
  String? gear,
}) {
  if (!player.claimRoad(
    trophies,
    coinGift: coins,
    emote: emote,
    gear: gear,
  )) {
    return;
  }
  final english = player.english;
  final parts = <String>[
    if (coins > 0) '+$coins 🐾',
    if (emote != null) _MilestoneChip.emoteLabels[emote] ?? emote,
    if (gear != null) itemName(gear),
  ];
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xff4e9c22),
      content: Text(
        parts.isEmpty
            ? (english ? 'CLAIMED!' : 'REVENDICAT!')
            : '${english ? 'CLAIMED' : 'REVENDICAT'}: ${parts.join(' + ')}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}

/// Trophy road / house tour, Match Masters / Brawl Stars style: one
/// continuous scrollable road climbed bottom-up to the Supreme Crown at
/// 100000 trophies. Between rooms sit 50 claimable milestones each
/// (small paw gifts + a few exclusive emotes); finishing a room grants
/// its accessory + coins. Each room medallion opens a detail sheet with
/// that room's own background and reward.
class HouseTourScreen extends StatefulWidget {
  const HouseTourScreen({super.key, required this.player});

  final Player player;

  @override
  State<HouseTourScreen> createState() => _HouseTourScreenState();
}

class _HouseTourScreenState extends State<HouseTourScreen> {
  final _scroll = ScrollController();

  /// Fixed node heights — required by `itemExtentBuilder` so the road
  /// stays lazy and the jump-to-current offset is exact.
  static const _chipH = 92.0;
  static const _roomH = 150.0;

  static const _icons = [
    Icons.weekend_rounded,
    Icons.meeting_room_rounded,
    Icons.kitchen_rounded,
    Icons.bed_rounded,
    Icons.toys_rounded,
    Icons.menu_book_rounded,
    Icons.ac_unit_rounded,
    Icons.wb_sunny_rounded,
    Icons.castle_rounded,
    Icons.palette_rounded,
    Icons.stairs_rounded,
    Icons.emoji_events_rounded,
    Icons.auto_awesome_rounded,
    Icons.favorite_rounded,
    Icons.fort_rounded,
    Icons.workspace_premium_rounded,
  ];

  /// Zigzag: rooms alternate left/right like the Brawl Stars road.
  static const _sides = [
    false, true, false, true, false, true, false, true, //
    false, true, false, true, false, true, false, true,
  ];

  Player get player => widget.player;
  bool get english => player.english;

  /// One laid-out road node: widget, its fixed height and the trophy
  /// goal it guards (used to find the player's current spot).
  static ({Widget child, double height, int goal}) _node(
    Widget child,
    double height,
    int goal,
  ) => (child: child, height: height, goal: goal);

  /// Builds the road bottom-up: room0, 50 milestones, room1, ... crown.
  List<({Widget child, double height, int goal})> _buildNodes(
    List<String> names,
  ) {
    final milestones = roadMilestones;
    final nodes = <({Widget child, double height, int goal})>[];
    var m = 0;
    for (var i = 0; i < houseRooms.length; i++) {
      if (i > 0) {
        // milestones belonging to this room's threshold, ascending order
        while (m < milestones.length &&
            !milestones[m].room &&
            milestones[m].trophies < houseRoomThresholds[i]) {
          final ms = milestones[m++];
          nodes.add(
            _node(
              _MilestoneChip(
                player: player,
                milestone: ms,
                current: ms.trophies == _currentGoal,
              ),
              _chipH,
              ms.trophies,
            ),
          );
        }
        // the room-completion milestone rides on the room node itself
        while (m < milestones.length &&
            milestones[m].trophies == houseRoomThresholds[i]) {
          m++;
        }
      }
      nodes.add(
        _node(
          _RoomNode(
            player: player,
            index: i,
            name: names[i],
            icon: _icons[i],
            art: houseRoomArt[i],
            rightSide: _sides[i],
          ),
          _roomH,
          houseRoomThresholds[i],
        ),
      );
    }
    return nodes;
  }

  /// The first road goal the player has not reached yet — the chip that
  /// glows as "next" and where the jump button lands.
  int get _currentGoal {
    for (final m in roadMilestones) {
      if (player.trophies < m.trophies) return m.trophies;
    }
    return roadFinalThreshold;
  }

  /// Index of the node guarding [_currentGoal] (a chip or a room).
  int _currentNode(List<({Widget child, double height, int goal})> nodes) {
    final goal = _currentGoal;
    for (var i = 0; i < nodes.length; i++) {
      if (nodes[i].goal >= goal) return i;
    }
    return nodes.length - 1;
  }

  void _jumpToCurrent(
    List<({Widget child, double height, int goal})> nodes,
  ) {
    final index = _currentNode(nodes);
    var offset = 0.0;
    for (var i = 0; i < index; i++) {
      offset += nodes[i].height;
    }
    _scroll.animateTo(
      offset,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final names = english ? houseRoomDisplayNamesEn : houseRoomDisplayNames;
    final nodes = _buildNodes(names);
    return Scaffold(
      backgroundColor: const Color(0xff2e2430),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: FloatingActionButton.extended(
          key: const ValueKey('road-jump-current'),
          heroTag: 'road-jump-current',
          backgroundColor: gold,
          foregroundColor: ink,
          icon: const Icon(Icons.pets_rounded),
          label: Text(
            english ? 'MY SPOT' : 'POZIȚIA MEA',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          onPressed: () => _jumpToCurrent(nodes),
        ),
      ),
      body: AnimatedBuilder(
        animation: player,
        builder: (context, _) => Stack(
          fit: StackFit.expand,
          children: [
            arenaImage(
              'bg_hallway',
              fit: BoxFit.cover,
              fallback: Container(color: const Color(0xff4a3542)),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x9920130e), Color(0x5520130e)],
                ),
              ),
            ),
            SafeArea(
              child: ListView.builder(
                key: const PageStorageKey('house-tour-scroll'),
                controller: _scroll,
                reverse: true,
                padding: const EdgeInsets.fromLTRB(14, 90, 14, 90),
                itemCount: nodes.length,
                itemExtentBuilder: (i, _) => nodes[i].height,
                itemBuilder: (context, i) => SizedBox(
                  height: nodes[i].height,
                  child: Center(child: nodes[i].child),
                ),
              ),
            ),
            // Floating header: back arrow + titles, no bar.
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      key: const ValueKey('house-tour-close'),
                      tooltip: english ? 'Back' : 'Înapoi',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: cream,
                        size: 28,
                        shadows: [
                          Shadow(
                            color: Color(0x99000000),
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            english ? 'TROPHY ROAD' : 'DRUMUL TROFEELOR',
                            style: const TextStyle(
                              color: cream,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                              shadows: [
                                Shadow(
                                  color: Color(0x99000000),
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              sprite('icon_trophy', size: 15),
                              const SizedBox(width: 4),
                              Text(
                                '${player.trophies} / ${houseRoomThresholds.last}',
                                style: const TextStyle(
                                  color: gold,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(
                                      color: Color(0x99000000),
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A claimable road milestone between rooms: a small tile on the path
/// showing the reward (paws or emote), the trophy threshold and its
/// state — locked / claimable (glowing) / claimed (check).
class _MilestoneChip extends StatelessWidget {
  const _MilestoneChip({
    required this.player,
    required this.milestone,
    this.current = false,
  });

  final Player player;
  final RoadMilestone milestone;

  /// True on the single next goal — drawn with a bright gold frame so
  /// the player's spot on the road is obvious at a glance.
  final bool current;

  /// Sprite art for road-exclusive emotes; anything else keeps the
  /// generic emote button icon.
  static const _emoteArt = {
    'love': 'emote_love',
    'angry': 'emote_angry',
  };

  /// Player-facing emote labels for the room-sheet route list.
  static const emoteLabels = {'love': 'DRAG', 'angry': 'GRRR'};

  @override
  Widget build(BuildContext context) {
    final reached = player.trophies >= milestone.trophies;
    final claimed = player.roadClaims.contains(milestone.trophies);
    final claimable = reached && !claimed;
    final isEmote = milestone.emote != null;
    final glow = claimable || current;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // paw trail segment above the chip
            const SizedBox(height: 8, child: CustomPaint(painter: _PawTrailPainter())),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: claimable
                    ? () => _claimWithToast(
                        context,
                        player,
                        milestone.trophies,
                        coins: milestone.coins,
                        emote: milestone.emote,
                      )
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: claimed
                          ? const [Color(0xff9a8d7d), Color(0xff6d6156)]
                          : claimable
                          ? const [Color(0xffffd75e), Color(0xffe8a01f)]
                          : const [
                              Color(0x995f4a38),
                              Color(0x993f2f26),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: glow
                          ? const Color(0xfffff3c4)
                          : const Color(0x55ffe9bd),
                      width: current ? 2.6 : (claimable ? 2 : 1.2),
                    ),
                    boxShadow: [
                      if (glow)
                        const BoxShadow(
                          color: Color(0x88ffc63c),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      const BoxShadow(
                        color: Color(0x55000000),
                        offset: Offset(0, 3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (claimed)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 20,
                        )
                      else if (isEmote)
                        sprite(
                          _emoteArt[milestone.emote] ?? 'btn_emote',
                          size: 20,
                        )
                      else
                        sprite('icon_paw_coin', size: 20),
                      const SizedBox(width: 7),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isEmote
                                ? (claimed
                                      ? 'EMOTE'
                                      : (player.english
                                            ? 'NEW EMOTE'
                                            : 'EMOTE NOU'))
                                : '+${milestone.coins}',
                            style: TextStyle(
                              color: claimed
                                  ? Colors.white
                                  : claimable
                                  ? const Color(0xff5d3a2c)
                                  : const Color(0xccbfa88f),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${milestone.trophies} 🏆',
                            style: TextStyle(
                              color: claimed
                                  ? const Color(0xccffffff)
                                  : claimable
                                  ? const Color(0x995d3a2c)
                                  : const Color(0x88bfa88f),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      if (!reached) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.lock_rounded,
                          color: Color(0x88ffffff),
                          size: 15,
                        ),
                      ],
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
}

/// Room medallion node: big circle with the room's own art, name,
/// threshold and state; tapping opens the room detail sheet. The room
/// completion reward (accessory + coins) is claimed from that sheet.
class _RoomNode extends StatelessWidget {
  const _RoomNode({
    required this.player,
    required this.index,
    required this.name,
    required this.icon,
    required this.art,
    required this.rightSide,
  });

  final Player player;
  final int index;
  final String name;
  final IconData icon;
  final String art;
  final bool rightSide;

  @override
  Widget build(BuildContext context) {
    final room = houseRooms[index];
    final threshold = room.threshold;
    final unlocked = player.trophies >= threshold;
    final isCurrent =
        houseRoomForTrophies(player.trophies).threshold == threshold;
    final gear = _roomGearLookup(threshold);
    final finished = player.roadClaims.contains(threshold);
    final state = !unlocked
        ? (player.english
              ? 'LOCKED AT $threshold TROPHIES'
              : 'BLOCATĂ LA $threshold TROFEE')
        : isCurrent
        ? (player.english ? 'CURRENT ROOM' : 'CAMERA CURENTĂ')
        : (player.english ? 'CLEARED' : 'CURĂȚATĂ');
    final texts = Column(
      crossAxisAlignment: rightSide
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${index + 1}. $name',
          maxLines: 2,
          softWrap: true,
          textAlign: rightSide ? TextAlign.end : TextAlign.start,
          style: TextStyle(
            color: unlocked ? cream : const Color(0xffb7a89a),
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            height: 1.15,
            shadows: const [
              Shadow(color: Color(0x99000000), offset: Offset(0, 1)),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            sprite('icon_trophy', size: 14),
            const SizedBox(width: 3),
            Text(
              '$threshold',
              style: const TextStyle(
                color: gold,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(color: Color(0x99000000), offset: Offset(0, 1)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          state,
          maxLines: 2,
          softWrap: true,
          textAlign: rightSide ? TextAlign.end : TextAlign.start,
          style: TextStyle(
            color: unlocked ? const Color(0xffffe0a8) : Colors.white54,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            height: 1.15,
            shadows: const [
              Shadow(color: Color(0x99000000), offset: Offset(0, 1)),
            ],
          ),
        ),
        if (gear != null && unlocked && !finished)
          Text(
            player.english ? 'REWARD INSIDE →' : 'RECOMPENSĂ →',
            style: const TextStyle(
              color: Color(0xffffd75e),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(color: Color(0x99000000), offset: Offset(0, 1)),
              ],
            ),
          ),
      ],
    );
    return Padding(
      padding: EdgeInsets.only(
        left: rightSide ? 60 : 6,
        right: rightSide ? 6 : 60,
        top: 10,
        bottom: 10,
      ),
      child: Align(
        alignment: rightSide ? Alignment.centerRight : Alignment.centerLeft,
        child: InkWell(
          borderRadius: BorderRadius.circular(60),
          onTap: () => _openRoom(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: rightSide
                ? [
                    Flexible(child: texts),
                    const SizedBox(width: 12),
                    _medallion(unlocked, isCurrent),
                  ]
                : [
                    _medallion(unlocked, isCurrent),
                    const SizedBox(width: 12),
                    Flexible(child: texts),
                  ],
          ),
        ),
      ),
    );
  }

  String? _roomGearLookup(int threshold) {
    for (final m in roadMilestones) {
      if (m.room && m.trophies == threshold) return m.gear;
    }
    return null;
  }

  void _openRoom(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RoomSheet(player: player, index: index),
    );
  }

  Widget _medallion(bool unlocked, bool isCurrent) {
    final glow = isCurrent && unlocked;
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: unlocked
              ? (isCurrent ? gold : const Color(0xffe0b070))
              : const Color(0xff6d5f55),
          width: isCurrent ? 4.5 : 3,
        ),
        boxShadow: [
          if (glow)
            const BoxShadow(
              color: Color(0xbbffc63c),
              blurRadius: 24,
              spreadRadius: 3,
            ),
          const BoxShadow(
            color: Color(0x77000000),
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
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                fallback: Container(
                  width: 96,
                  height: 96,
                  color: unlocked
                      ? const Color(0xfff0d9b0)
                      : const Color(0xff9a8d80),
                  child: Icon(icon, color: ink, size: 38),
                ),
              ),
            ),
          ),
          if (!unlocked)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xe6352b28),
                shape: BoxShape.circle,
                border: Border.all(color: cream, width: 1.4),
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: cream,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }
}

/// Room detail sheet: the room's own background on top, its cats, and
/// the room-completion reward (accessory + paws) with a claim button.
class _RoomSheet extends StatelessWidget {
  const _RoomSheet({required this.player, required this.index});

  final Player player;
  final int index;

  /// Live-rebuild on every claim so IA buttons flip to ticks instantly —
  /// the sheet used to build once and keep stale claim states.
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: player,
    builder: (context, _) => _sheet(context),
  );

  Widget _sheet(BuildContext context) {
    final english = player.english;
    final names = english ? houseRoomDisplayNamesEn : houseRoomDisplayNames;
    final room = houseRooms[index];
    final unlocked = player.trophies >= room.threshold;
    RoadMilestone? reward;
    for (final m in roadMilestones) {
      if (m.room && m.trophies == room.threshold) reward = m;
    }
    final claimed = player.roadClaims.contains(room.threshold);
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xfffff4d8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 150,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                arenaImage(
                  houseRoomArt[index],
                  fit: BoxFit.cover,
                  fallback: Container(color: const Color(0xffd9b98c)),
                ),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xaa2e1c14)],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  bottom: 10,
                  child: Text(
                    names[index],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(color: Color(0xbb000000), offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: Color(0xbb000000), offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Threshold + unlock state, right under the room name.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xff5f4a38),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          sprite('icon_trophy', size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${room.threshold}',
                            style: const TextStyle(
                              color: Color(0xffffd75e),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      unlocked
                          ? (claimed
                                ? (english ? 'REWARD CLAIMED' : 'RECOMPENSĂ LUATĂ')
                                : (english ? 'UNLOCKED' : 'DEBLOCATĂ'))
                          : player.trophies >= houseRooms[index - 1].threshold
                          ? (english ? 'IN PROGRESS' : 'ÎN PROGRES')
                          : (english ? 'LOCKED' : 'BLOCATĂ'),
                      style: TextStyle(
                        color: unlocked
                            ? const Color(0xff4e9c22)
                            : const Color(0xff8a6242),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _RoomRoute(player: player, index: index, english: english),
                const SizedBox(height: 14),
                if (reward != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xfffdf0cd),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: gold, width: 1.6),
                    ),
                    child: Row(
                      children: [
                        accessoryArt(reward.gear!, size: 40),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                english
                                    ? 'ROOM REWARD'
                                    : 'RECOMPENSA CAMEREI',
                                style: const TextStyle(
                                  color: Color(0xff8a5c3e),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                '${itemName(reward.gear!)} + ${reward.coins} 🐾',
                                style: const TextStyle(
                                  color: ink,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (unlocked && !claimed)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                _claimWithToast(
                                  context,
                                  player,
                                  room.threshold,
                                  coins: reward!.coins,
                                  gear: reward.gear,
                                );
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xff93d94f),
                                      Color(0xff4e9c22),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xff2e6b14),
                                    width: 1.4,
                                  ),
                                ),
                                child: Text(
                                  english ? 'CLAIM' : 'IA',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          Icon(
                            claimed
                                ? Icons.check_circle_rounded
                                : Icons.lock_rounded,
                            color: claimed
                                ? const Color(0xff4e9c22)
                                : const Color(0xff9a8d80),
                            size: 26,
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  reward == null
                      ? (english
                            ? 'Win duels to climb the road — the next room waits above.'
                            : 'Câștigă dueluri și urcă drumul — camera următoare te așteaptă.')
                      : unlocked
                      ? (english
                            ? 'Tap CLAIM to collect the room reward.'
                            : 'Apasă IA pentru recompensa camerei.')
                      : (english
                            ? 'Reach ${room.threshold} trophies to unlock.'
                            : 'Ajunge la ${room.threshold} trofee pentru a deschide.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xff8a6a52),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Staggered golden paw prints climbing the screen between milestones.
class _PawTrailPainter extends CustomPainter {
  const _PawTrailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xccffc63c);
    _paw(canvas, Offset(size.width * 0.5, size.height * 0.5), 5.5, paint);
  }

  void _paw(Canvas canvas, Offset c, double r, Paint paint) {
    canvas.drawOval(
      Rect.fromCenter(center: c, width: r * 1.7, height: r * 1.4),
      paint,
    );
    for (final (dx, dy) in [(-1.1, -1.0), (0.0, -1.35), (1.1, -1.0)]) {
      canvas.drawCircle(c + Offset(dx * r, dy * r), r * .48, paint);
    }
  }

  @override
  bool shouldRepaint(_PawTrailPainter oldDelegate) => false;
}

/// Mini-route inside a room sheet: every milestone between this room's
/// threshold and the next room's, listed as small detailed rewards.
class _RoomRoute extends StatelessWidget {
  const _RoomRoute({
    required this.player,
    required this.index,
    required this.english,
  });

  final Player player;
  final int index;
  final bool english;

  @override
  Widget build(BuildContext context) {
    final start = houseRooms[index].threshold;
    final end =
        index + 1 < houseRooms.length ? houseRooms[index + 1].threshold : 1 << 30;
    final stops = [
      for (final m in roadMilestones)
        if (m.trophies >= start && m.trophies < end) m,
    ];
    final last = index + 1 >= houseRooms.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          last
              ? (english
                    ? 'ROUTE TO THE SUPREME CROWN'
                    : 'TRASEUL SPRE COROANA SUPREMĂ')
              : (english
                    ? 'ROUTE TO THE NEXT ROOM'
                    : 'TRASEUL SPRE CAMERA URMĂTOARE'),
          style: const TextStyle(
            color: Color(0xff8a6242),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        // 50 stops per segment — the list scrolls inside a fixed frame.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: stops.length,
            separatorBuilder: (context, _) => Center(
              child: Container(
                width: 3,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xffd9b98c),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            itemBuilder: (context, i) => _routeStop(stops[i], context),
          ),
        ),
      ],
    );
  }

  Widget _routeStop(RoadMilestone m, BuildContext context) {
    final reached = player.trophies >= m.trophies;
    final claimed = player.roadClaims.contains(m.trophies);
    final claimable = reached && !claimed;
    final rewardText = m.gear != null
        ? '${itemName(m.gear!)} + ${m.coins} 🐾'
        : m.emote != null
        ? 'Emote „${_MilestoneChip.emoteLabels[m.emote] ?? m.emote}”'
        : '${m.coins} 🐾';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: claimed
            ? const Color(0xffe8e0d2)
            : claimable
            ? const Color(0xfffdf0cd)
            : const Color(0xfff2ead8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: claimable ? gold : const Color(0xffd9c9ac),
          width: claimable ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xff5f4a38),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '🏆${m.trophies}',
              style: const TextStyle(
                color: Color(0xffffd75e),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (m.gear != null) ...[
            accessoryArt(m.gear!, size: 24),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              rewardText,
              style: const TextStyle(
                color: ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (claimable)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _claimWithToast(
                context,
                player,
                m.trophies,
                coins: m.coins,
                emote: m.emote,
                gear: m.gear,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xff93d94f), Color(0xff4e9c22)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xff2e6b14),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  english ? 'CLAIM' : 'IA',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            )
          else
            Icon(
              claimed ? Icons.check_circle_rounded : Icons.lock_rounded,
              color: claimed
                  ? const Color(0xff4e9c22)
                  : const Color(0xff9a8d80),
              size: 20,
            ),
        ],
      ),
    );
  }
}
