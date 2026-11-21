import 'package:flutter/material.dart';

import '../ui_widgets.dart' show arenaImage;

/// Top HUD for the simultaneous 60-second Frenzy duel: the central
/// countdown (last seconds trigger ZOOMIES FEVER x2), the live
/// tug-of-war territory bar between the player (gold, left) and the
/// opponent (blue, right), and the incoming sabotage box counters.
class FrenzyTugOfWarHud extends StatelessWidget {
  final String playerName;
  final Widget playerAvatar;
  final int playerScore;
  final int playerSabotageIncoming;
  final Widget? playerEmote;

  final String opponentName;
  final Widget opponentAvatar;
  final int opponentScore;
  final int opponentSabotageIncoming;
  final Widget? opponentEmote;

  final int secondsRemaining; // 60 down to 0
  final bool isFeverMode;
  final VoidCallback onSettingsTap;
  final VoidCallback? onOpponentTap;

  const FrenzyTugOfWarHud({
    super.key,
    required this.playerName,
    required this.playerAvatar,
    required this.playerScore,
    this.playerSabotageIncoming = 0,
    this.playerEmote,
    required this.opponentName,
    required this.opponentAvatar,
    required this.opponentScore,
    this.opponentSabotageIncoming = 0,
    this.opponentEmote,
    required this.secondsRemaining,
    required this.isFeverMode,
    required this.onSettingsTap,
    this.onOpponentTap,
  });

  @override
  Widget build(BuildContext context) {
    final total = (playerScore + opponentScore).clamp(1, 9999999);
    // Territory ratio: 0.5 at 0-0, clamped so both sides stay visible.
    final rawRatio =
        (playerScore == 0 && opponentScore == 0) ? 0.5 : (playerScore / total);
    final playerRatio = rawRatio.clamp(0.15, 0.85);

    final mm = (secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final ss = (secondsRemaining % 60).toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _FrenzyAvatarBadge(
                name: playerName,
                avatar: playerAvatar,
                ringColor: const Color(0xFFFFCA28),
                sabotageBoxes: playerSabotageIncoming,
                isLeft: true,
                emote: playerEmote,
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isFeverMode
                              ? const [Color(0xFFFF6F00), Color(0xFFD50000)]
                              : const [Color(0xFF4E2A12), Color(0xFF2B1508)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isFeverMode
                              ? const Color(0xFFFFF59D)
                              : const Color(0xFFFFD54F),
                          width: 2.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isFeverMode
                                ? const Color(0xFFFF6D00).withValues(alpha: 0.7)
                                : Colors.black.withValues(alpha: 0.45),
                            blurRadius: isFeverMode ? 12 : 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isFeverMode
                                ? Icons.local_fire_department_rounded
                                : Icons.timer_rounded,
                            size: 18,
                            color: const Color(0xFFFFF176),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$mm:$ss',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          if (isFeverMode) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD54F),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'x2',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF4E1A00),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isFeverMode)
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Text(
                          'ZOOMIES FEVER x2!',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            color: Color(0xFFFFE082),
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: onOpponentTap,
                    child: _FrenzyAvatarBadge(
                      name: opponentName,
                      avatar: opponentAvatar,
                      ringColor: const Color(0xFF42A5F5),
                      sabotageBoxes: opponentSabotageIncoming,
                      isLeft: false,
                      emote: opponentEmote,
                    ),
                  ),
                  Positioned(
                    top: -4,
                    right: -4,
                    child: GestureDetector(
                      key: const Key('battle-settings'),
                      onTap: onSettingsTap,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFFFD54F), Color(0xFFE69A28)],
                          ),
                          border: Border.all(
                              color: const Color(0xFF3E220F), width: 2),
                        ),
                        child: const Icon(
                          Icons.settings_rounded,
                          size: 16,
                          color: Color(0xFF3E220F),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF231107),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isFeverMode
                    ? const Color(0xFFFFAB00)
                    : const Color(0xFFD4A24C),
                width: 2.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11.5),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF42A5F5), Color(0xFF1565C0)],
                      ),
                    ),
                  ),
                  AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    widthFactor: playerRatio,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFFFD54F), Color(0xFFEF6C00)],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 15, color: Colors.white),
                            const SizedBox(width: 3),
                            Text(
                              '$playerScore',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 3),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$opponentScore',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 3),
                                ],
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(Icons.star_rounded,
                                size: 15, color: Colors.white),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FrenzyAvatarBadge extends StatelessWidget {
  final String name;
  final Widget avatar;
  final Color ringColor;
  final int sabotageBoxes;
  final bool isLeft;
  final Widget? emote;

  const _FrenzyAvatarBadge({
    required this.name,
    required this.avatar,
    required this.ringColor,
    required this.sabotageBoxes,
    required this.isLeft,
    this.emote,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ringColor, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: ringColor.withValues(alpha: 0.55),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: ClipOval(child: avatar),
            ),
            if (emote != null)
              Positioned(
                top: -18,
                left: isLeft ? 40 : null,
                right: isLeft ? null : 40,
                child: emote!,
              ),
            if (sabotageBoxes > 0)
              Positioned(
                bottom: -2,
                right: isLeft ? -8 : null,
                left: isLeft ? null : -8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4E2A12),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: const Color(0xFFFFB74D), width: 1.4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      arenaImage('tile_box', width: 12, height: 12),
                      const SizedBox(width: 2),
                      Text(
                        'x$sabotageBoxes',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 64,
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ),
      ],
    );
  }
}
