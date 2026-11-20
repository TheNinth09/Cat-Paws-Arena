import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cat_avatar.dart';
import 'profile.dart';
import 'ui_widgets.dart';

/// Full-body art for a cat on the VS/search scene; falls back to the
/// procedural avatar when the cat has no drawn art.
Widget duelCatArt(Player p, {double size = 118}) {
  return catPortrait(p.cat, size: size);
}

/// The single matchmaking/search page — shown by the [MatchScreen]
/// searching phase for both house-cat duels and online friend duels.
/// Room artwork, cartoon logo, two tall fighter cards, wooden stakes
/// board, animated status and one cancel action.
class MatchupScene extends StatelessWidget {
  const MatchupScene({
    super.key,
    required this.english,
    required this.modeText,
    required this.playerName,
    required this.playerTrophies,
    required this.playerBadge,
    required this.playerPortrait,
    required this.opponentName,
    required this.opponentTrophies,
    required this.opponentBadge,
    required this.opponentPortrait,
    this.opponentSubtitle,
    required this.statusText,
    required this.cancelKey,
    required this.cancelText,
    required this.onCancel,
    this.middle,
    this.pulse,
    this.backgroundAsset = 'bg_living_room',
  });

  final bool english;
  final String modeText;
  final String playerName;
  final int playerTrophies;
  final String playerBadge;
  final Widget playerPortrait;
  final String opponentName;
  final int opponentTrophies;
  final String opponentBadge;
  final Widget opponentPortrait;
  final String? opponentSubtitle;
  final String statusText;
  final Key cancelKey;
  final String cancelText;
  final VoidCallback onCancel;

  /// Optional extra widget between the stakes board and the status row —
  /// used for the offline bot difficulty picker.
  final Widget? middle;

  /// Optional ticker driving the VS pulse and the status dots.
  final Animation<double>? pulse;
  final String backgroundAsset;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      arenaImage(
        backgroundAsset,
        fit: BoxFit.cover,
        fallback: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xff241d3f), Color(0xff3a2a5e), Color(0xff54346b)],
            ),
          ),
        ),
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xa31d1224),
              Color(0x381d1224),
              Color(0x0a1d1224),
              Color(0xb31d1224),
            ],
            stops: [0, .3, .62, 1],
          ),
        ),
      ),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 10),
              const _ArenaLogo(),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xb32b1c33),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0x66ffd98b),
                    width: 1.4,
                  ),
                ),
                child: Text(
                  modeText,
                  style: const TextStyle(
                    color: Color(0xfff0d9b0),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              const Spacer(flex: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _MatchupCard(
                      blue: true,
                      badge: playerBadge,
                      name: playerName,
                      trophies: playerTrophies,
                      portrait: playerPortrait,
                    ),
                  ),
                  _VsLetters(pulse: pulse),
                  Expanded(
                    child: _MatchupCard(
                      blue: false,
                      badge: opponentBadge,
                      name: opponentName,
                      trophies: opponentTrophies,
                      subtitle: opponentSubtitle,
                      portrait: opponentPortrait,
                    ),
                  ),
                ],
              ),
              const Spacer(flex: 3),
              _StakesPanel(english: english),
              if (middle != null) ...[const SizedBox(height: 10), middle!],
              const SizedBox(height: 12),
              _MatchupStatus(text: statusText, pulse: pulse),
              const SizedBox(height: 12),
              ArenaButton(
                key: cancelKey,
                text: cancelText,
                danger: true,
                onPressed: onCancel,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Chunky cartoon logo for the matchup scene — single findable text.
class _ArenaLogo extends StatelessWidget {
  const _ArenaLogo();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      sprite('btn_play_paw', size: 26),
      const SizedBox(height: 2),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'CAT PAWS ARENA',
          style: TextStyle(
            color: gold,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
            shadows: const [
              Shadow(color: Color(0xff6b3a12), offset: Offset(0, 3)),
              Shadow(
                color: Color(0x88000000),
                offset: Offset(0, 5),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Tall framed fighter card like the reference matchup page: coloured
/// gradient frame, badge pill on the top edge, big portrait panel, name
/// and trophy count.
class _MatchupCard extends StatelessWidget {
  const _MatchupCard({
    required this.blue,
    required this.badge,
    required this.name,
    required this.trophies,
    required this.portrait,
    this.subtitle,
  });

  final bool blue;
  final String badge;
  final String name;
  final int trophies;
  final Widget portrait;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = blue
        ? const [Color(0xff5ea4e8), Color(0xff2f5f9e), Color(0xff1d3f6e)]
        : const [Color(0xffa06fd0), Color(0xff5e3a8e), Color(0xff3c2554)];
    final border = blue ? const Color(0xffbcd8ff) : const Color(0xffe2c8ff);
    final badgeColor = blue ? const Color(0xffd9ecff) : const Color(0xfff0dfff);
    final badgeInk = blue ? const Color(0xff1d3f6e) : const Color(0xff3c2554);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.fromLTRB(8, 18, 8, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                offset: Offset(0, 5),
                blurRadius: 12,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 88,
                width: double.infinity,
                alignment: Alignment.bottomCenter,
                decoration: BoxDecoration(
                  color: const Color(0x33ffffff),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0x44ffffff),
                    width: 1.2,
                  ),
                ),
                child: portrait,
              ),
              const SizedBox(height: 8),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: cream,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(color: Color(0x66000000), offset: Offset(0, 1)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  sprite('icon_trophy', size: 15),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '$trophies',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xffd8c8f0),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (badge.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: border, width: 1.4),
              boxShadow: const [
                BoxShadow(color: Color(0x55000000), offset: Offset(0, 2)),
              ],
            ),
            child: Text(
              badge,
              style: TextStyle(
                color: badgeInk,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
      ],
    );
  }
}

/// Big cartoon VS letters between the fighter cards, pulsing when a
/// [pulse] ticker is provided.
class _VsLetters extends StatelessWidget {
  const _VsLetters({this.pulse});
  final Animation<double>? pulse;

  @override
  Widget build(BuildContext context) {
    final letters = Text(
      'VS',
      style: TextStyle(
        color: gold,
        fontSize: 44,
        fontWeight: FontWeight.w900,
        height: 1,
        shadows: const [
          Shadow(color: Color(0xff6b3a12), offset: Offset(0, 3)),
          Shadow(
            color: Color(0xaa000000),
            offset: Offset(0, 6),
            blurRadius: 12,
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: pulse == null
          ? letters
          : AnimatedBuilder(
              animation: pulse!,
              builder: (context, child) =>
                  Transform.scale(scale: 1 + 0.08 * pulse!.value, child: child),
              child: letters,
            ),
    );
  }
}

/// Wooden stakes board: +30 win / 0 draw / -25 loss.
class _StakesPanel extends StatelessWidget {
  const _StakesPanel({required this.english});
  final bool english;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xff8a5a34), Color(0xff6b422a), Color(0xff54311f)],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xffd9a05f), width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x55000000),
          offset: Offset(0, 4),
          blurRadius: 10,
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          english ? 'MATCH STAKES' : 'MIZELE MECIULUI',
          style: const TextStyle(
            color: Color(0xffffd98b),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _stake(
              '+30',
              english ? 'WIN' : 'VICTORIE',
              const Color(0xffb9e07a),
            ),
            _stake('0', english ? 'DRAW' : 'EGAL', const Color(0xffe8e0d0)),
            _stake(
              '-25',
              english ? 'LOSS' : 'INFRANGERE',
              const Color(0xffff9d8a),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _stake(String value, String label, Color color) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 17,
          fontWeight: FontWeight.w900,
          shadows: const [
            Shadow(color: Color(0x55000000), offset: Offset(0, 1)),
          ],
        ),
      ),
      Text(
        label,
        style: const TextStyle(
          color: Color(0xfff0d9b0),
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    ],
  );
}

/// Bouncing dots + status line. Uses the caller's [pulse] ticker when
/// provided, otherwise animates itself.
class _MatchupStatus extends StatelessWidget {
  const _MatchupStatus({required this.text, this.pulse});
  final String text;
  final Animation<double>? pulse;

  @override
  Widget build(BuildContext context) => pulse == null
      ? _SelfAnimatedDotsHolder(text: text)
      : _Dots(text: text, pulse: pulse!);
}

class _Dots extends StatelessWidget {
  const _Dots({required this.text, required this.pulse});
  final String text;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: pulse,
    builder: (context, _) {
      Widget dot(int i) {
        final wave =
            0.5 + 0.5 * math.sin((pulse.value * 2 - i * 0.33) * math.pi);
        return Transform.translate(
          offset: Offset(0, -3 * wave),
          child: Opacity(
            opacity: 0.3 + 0.7 * wave,
            child: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: gold,
                boxShadow: [BoxShadow(color: Color(0x66ffc63c), blurRadius: 6)],
              ),
            ),
          ),
        );
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++) ...[
                dot(i),
                if (i < 2) const SizedBox(width: 9),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xfff0ddc8),
              fontSize: 14,
              fontWeight: FontWeight.w800,
              shadows: [Shadow(color: Color(0xaa000000), offset: Offset(0, 1))],
            ),
          ),
        ],
      );
    },
  );
}

class _SelfAnimatedDotsHolder extends StatefulWidget {
  const _SelfAnimatedDotsHolder({required this.text});
  final String text;

  @override
  State<_SelfAnimatedDotsHolder> createState() =>
      _SelfAnimatedDotsHolderState();
}

class _SelfAnimatedDotsHolderState extends State<_SelfAnimatedDotsHolder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Dots(text: widget.text, pulse: _c);
}
