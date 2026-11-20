import 'package:flutter/material.dart';

import '../ui_widgets.dart';

/// Top battle HUD from the duel mockup: the player's portrait column on
/// the left (name, ringed avatar, score plate, round dots), the turn
/// banner + clock + progress in the centre, the opponent's column on the
/// right with the sabotage badge, and the small settings gear.
class BattleTopHud extends StatelessWidget {
  const BattleTopHud({
    super.key,
    required this.playerAvatar,
    required this.playerName,
    required this.playerScore,
    required this.playerActive,
    required this.roundsUsed,
    required this.roundsTotal,
    required this.opponentAvatar,
    required this.opponentName,
    required this.opponentScore,
    required this.opponentActive,
    required this.opponentIncoming,
    required this.banner,
    required this.seconds,
    required this.clockProgress,
    required this.round,
    required this.pulse,
    this.playerIncoming = 0,
    this.playerEmote,
    this.opponentEmote,
    this.onOpponentTap,
    this.onSettingsTap,
  });

  final Widget playerAvatar;
  final String playerName;
  final int playerScore;

  /// Gold pulsing ring while this side holds the turn.
  final bool playerActive;

  /// Completed + in-progress rounds for the round dots (0..roundsTotal).
  final int roundsUsed;
  final int roundsTotal;

  final Widget opponentAvatar;
  final String opponentName;
  final int opponentScore;
  final bool opponentActive;

  /// Sabotage boxes queued against the opponent (the `x2` badge).
  final int opponentIncoming;

  /// 'TURA TA' or 'TURA LUI [NAME]'.
  final String banner;
  final int seconds;

  /// 0..1 remaining on the turn clock.
  final double clockProgress;
  final int round;

  /// Shared pulse driving the active-ring glow.
  final Animation<double> pulse;

  /// Sabotage boxes queued against the player (mirrored badge).
  final int playerIncoming;

  /// Optional emote sticker floating under each portrait column.
  final Widget? playerEmote;
  final Widget? opponentEmote;

  final VoidCallback? onOpponentTap;
  final VoidCallback? onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final urgent = seconds <= 4;
    final yourTurn = playerActive;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _side(
                avatar: playerAvatar,
                name: playerName,
                score: playerScore,
                active: playerActive,
                activeColor: gold,
                passiveRing: const Color(0xff8fa8bd),
                boxes: playerIncoming,
                dots: true,
                emote: playerEmote,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TurnBanner(text: banner, yours: yourTurn),
                    const SizedBox(height: 2),
                    Text(
                      '${seconds}s',
                      style: TextStyle(
                        color: urgent ? const Color(0xffff6b5e) : cream,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                        shadows: const [
                          Shadow(color: ink, offset: Offset(0, 2), blurRadius: 4),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: clockProgress.clamp(0.0, 1.0),
                              minHeight: 7,
                              backgroundColor: const Color(0x883a2418),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                urgent
                                    ? const Color(0xffff6b5e)
                                    : yourTurn
                                    ? gold
                                    : const Color(0xff7ec8ff),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _RoundBadge(round: round, total: roundsTotal),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _side(
                avatar: opponentAvatar,
                name: opponentName,
                score: opponentScore,
                active: opponentActive,
                activeColor: const Color(0xff7ec8ff),
                passiveRing: const Color(0xff8fa8bd),
                boxes: opponentIncoming,
                dots: false,
                emote: opponentEmote,
                onTap: onOpponentTap,
              ),
            ],
          ),
        ),
        if (onSettingsTap != null)
          Positioned(
            top: -4,
            right: 0,
            child: _GearButton(
              key: const Key('battle-settings'),
              onTap: onSettingsTap!,
            ),
          ),
      ],
    );
  }

  /// One portrait column: name over the ringed avatar, score plate under
  /// it, then either the round dots (player) or the sabotage badge.
  Widget _side({
    required Widget avatar,
    required String name,
    required int score,
    required bool active,
    required Color activeColor,
    required Color passiveRing,
    required int boxes,
    required bool dots,
    Widget? emote,
    VoidCallback? onTap,
  }) {
    // Fixed-width side column: long names ellipsis instead of pushing
    // the centre clock off-screen (320 px layouts included).
    final column = SizedBox(
      width: 88,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: active ? activeColor : cream,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            shadows: const [
              Shadow(color: ink, offset: Offset(0, 1), blurRadius: 3),
            ],
          ),
        ),
        const SizedBox(height: 2),
        AnimatedBuilder(
          animation: pulse,
          builder: (context, _) {
            final ring = active ? activeColor : passiveRing;
            return Transform.scale(
              scale: active ? 1 + 0.05 * pulse.value : 1.0,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xff2e1d12),
                  border: Border.all(color: ring, width: active ? 3.2 : 2.4),
                  boxShadow: [
                    BoxShadow(
                      color: ring.withValues(
                        alpha: active ? 0.45 + 0.3 * pulse.value : 0.25,
                      ),
                      blurRadius: active ? 12 + 6 * pulse.value : 6,
                    ),
                  ],
                ),
                child: ClipOval(child: SizedBox(width: 52, height: 52, child: avatar)),
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        _ScorePlate(score: score, boxes: boxes),
        const SizedBox(height: 3),
        SizedBox(
          height: 8,
          child: dots
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < roundsTotal; i++)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < roundsUsed
                              ? gold
                              : const Color(0x99442318),
                          border: Border.all(
                            color: i < roundsUsed
                                ? const Color(0xffffe9a8)
                                : const Color(0xcc6b4636),
                            width: 0.8,
                          ),
                        ),
                      ),
                  ],
                )
              : null,
        ),
        ],
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        onTap == null
            ? column
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: column,
              ),
        if (emote != null)
          Positioned(
            left: -8,
            right: -8,
            bottom: -34,
            child: IgnorePointer(child: Center(child: emote)),
          ),
      ],
    );
  }
}

/// Brown plaque holding the turn banner text.
class _TurnBanner extends StatelessWidget {
  const _TurnBanner({required this.text, required this.yours});
  final String text;
  final bool yours;

  @override
  Widget build(BuildContext context) {
    final edge = yours ? gold : const Color(0xff9fd4ff);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff7a5238), Color(0xff503124)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: edge, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: edge.withValues(alpha: 0.35),
            blurRadius: 8,
          ),
          const BoxShadow(
            color: Color(0x55000000),
            offset: Offset(0, 3),
            blurRadius: 4,
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          style: TextStyle(
            color: edge,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
            shadows: const [Shadow(color: ink, offset: Offset(0, 1))],
          ),
        ),
      ),
    );
  }
}

/// Small dark circle showing the current round (`1/3`).
class _RoundBadge extends StatelessWidget {
  const _RoundBadge({required this.round, required this.total});
  final int round;
  final int total;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xcc2e1d12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xccffc63c), width: 1),
    ),
    child: Text(
      '$round/$total',
      style: const TextStyle(
        color: gold,
        fontSize: 10.5,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

/// Wooden score plate; stacks a small box `xN` sabotage badge when the
/// duel queued obstacles against this side.
class _ScorePlate extends StatelessWidget {
  const _ScorePlate({required this.score, required this.boxes});
  final int score;
  final int boxes;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 74),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xff6b4636), Color(0xff4a2e20)],
      ),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: const Color(0xccffc63c), width: 1.1),
      boxShadow: const [
        BoxShadow(
          color: Color(0x55000000),
          offset: Offset(0, 2),
          blurRadius: 4,
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.star, color: gold, size: 13),
        const SizedBox(width: 3),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$score',
              style: const TextStyle(
                color: gold,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        if (boxes > 0) ...[
          const SizedBox(width: 4),
          arenaImage(
            'tile_box',
            width: 15,
            height: 15,
            fallback: sprite('obs_cardboard_box', size: 15),
          ),
          Text(
            'x$boxes',
            style: const TextStyle(
              color: cream,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ],
    ),
  );
}

/// The small gold gear floating at the top-right of the HUD.
class _GearButton extends StatelessWidget {
  const _GearButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TactilePress(
    onTap: onTap,
    child: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xffffd97a), Color(0xffd8962e)],
        ),
        border: Border.all(color: const Color(0xff6b3a12), width: 1.6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            offset: Offset(0, 3),
            blurRadius: 5,
          ),
        ],
      ),
      child: const Icon(Icons.settings, color: Color(0xff5a3010), size: 21),
    ),
  );
}

/// Bottom action bar from the duel mockup: the 3D power button (~70%)
/// carrying the equipped power icon, its charge bar and the ACTIVEAZĂ!
/// call at 100%, beside the 3D turquoise EMOTE button (~30%). Both sit
/// strictly below the 7×7 grid.
class BattleBottomActionBar extends StatelessWidget {
  const BattleBottomActionBar({
    super.key,
    required this.powerIcon,
    required this.powerFallback,
    required this.powerLabel,
    required this.charge,
    required this.canFire,
    required this.onPower,
    required this.onEmote,
    required this.pulse,
  });

  /// `power_*` image name from `assets/images/`.
  final String powerIcon;
  final Widget powerFallback;
  final String powerLabel;
  final int charge;

  /// Full meter + player's turn + input open.
  final bool canFire;
  final VoidCallback onPower;
  final VoidCallback onEmote;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final full = charge >= 100;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 2),
      child: Row(
        children: [
          Expanded(
            flex: 70,
            child: TactilePress(
              onTap: canFire ? onPower : () {},
              haptics: canFire,
              child: AnimatedBuilder(
                animation: pulse,
                builder: (context, _) => Container(
                  key: const Key('power-meter'),
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: full
                          ? const [Color(0xffffd97a), Color(0xffe08a1e)]
                          : const [Color(0xff8a5a2e), Color(0xff5c3a20)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: full ? const Color(0xfffff3c4) : const Color(0xff3a2412),
                      width: full ? 2 : 1.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: full
                            ? const Color(0xffffc63c).withValues(
                                alpha: 0.35 + 0.3 * pulse.value,
                              )
                            : const Color(0x55000000),
                        blurRadius: full ? 12 + 8 * pulse.value : 6,
                        spreadRadius: full ? 1 : 0,
                      ),
                      const BoxShadow(
                        color: Color(0x883a1c08),
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 6),
                      Transform.scale(
                        scale: full ? 1.12 + 0.06 * pulse.value : 1.0,
                        child: arenaImage(
                          powerIcon,
                          width: 46,
                          height: 46,
                          fallback: SizedBox(
                            width: 46,
                            height: 46,
                            child: powerFallback,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                full ? 'ACTIVEAZĂ!' : '$powerLabel $charge%',
                                maxLines: 1,
                                style: TextStyle(
                                  color: full ? const Color(0xff5a2408) : gold,
                                  fontSize: full ? 17 : 13.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  shadows: [
                                    Shadow(
                                      color: full
                                          ? const Color(0x66ffffff)
                                          : const Color(0xaa000000),
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: LinearProgressIndicator(
                                value: (charge / 100).clamp(0.0, 1.0),
                                minHeight: 8,
                                backgroundColor: const Color(0x553a1c08),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  full ? const Color(0xfffff3c4) : const Color(0xff7ed957),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            flex: 30,
            child: TactilePress(
              onTap: onEmote,
              child: Container(
                key: const Key('emote-button'),
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xff6fd8ec), Color(0xff2f9ec9)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xffd9f4ff), width: 1.6),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x88104866),
                      offset: Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Color(0x4400cfff),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble, color: Colors.white, size: 20),
                    SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'EMOTE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            shadows: [
                              Shadow(color: Color(0x88104866), offset: Offset(0, 1)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
