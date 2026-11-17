import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cat_avatar.dart';
import 'match_controller.dart';
import 'profile.dart';
import 'shell/house_tour.dart';
import 'ui_widgets.dart';

/// Opponent identity shown on the pre-match VS screen. [badge] is the
/// peer-visible label required by the contract: 'BOT' for house cats and
/// 'ONLINE' for friend rooms — never an unlabelled stranger.
class VsOpponent {
  const VsOpponent({
    required this.name,
    required this.trophies,
    required this.badge,
    required this.avatar,
    this.subtitle,
  });

  final String name;
  final int trophies;
  final String badge;
  final Widget avatar;
  final String? subtitle;

  /// House-cat bot (or the rotating practice bot when [cat] is null).
  factory VsOpponent.houseCat(Player player, HouseCat? cat) {
    if (cat == null) {
      return VsOpponent(
        name: 'BOT',
        trophies: player.trophies,
        badge: 'BOT',
        avatar: const _BotAvatar(size: 64),
        subtitle: 'Antrenament',
      );
    }
    return VsOpponent(
      name: cat.name,
      trophies: cat.trophies,
      badge: 'BOT',
      avatar: CatAvatar(houseCatPlayer(player.prefs, cat), size: 64),
      subtitle: 'Nv ${cat.level}',
    );
  }

  /// Friend duel opponent resolved from the cloud profile (preset name and
  /// cat loadout only — typed names never leave the device).
  factory VsOpponent.online(Player player, OnlineOpponentInfo info) {
    final spec = Player(player.prefs)
      ..name = info.name
      ..cat = info.cat
      ..trophies = info.trophies
      ..coins = 0
      ..fur = info.fur
      ..eyes = info.eyes
      ..ears = info.ears
      ..pattern = info.pattern
      ..accessory = info.accessory
      ..power = info.power
      ..photo = null;
    return VsOpponent(
      name: info.name,
      trophies: info.trophies,
      badge: 'ONLINE',
      avatar: CatAvatar(spec, size: 64, allowPhoto: false),
      subtitle: 'Prieten',
    );
  }
}

/// Pre-match versus screen shown before [MatchScreen] for both house-cat
/// duels and online friend duels. Displays the matchup, the trophy stakes
/// and a preparing state, then replaces itself with [matchScreen] once the
/// arena is ready. [autoStartAfter] is tunable for tests.
class VsScreen extends StatefulWidget {
  const VsScreen({
    super.key,
    required this.player,
    required this.opponent,
    required this.matchScreen,
    this.autoStartAfter = const Duration(seconds: 3),
  });

  final Player player;
  final VsOpponent opponent;

  /// The duel screen pushed (via pushReplacement) when the arena is ready,
  /// normally a [MatchScreen] for the same opponent.
  final Widget matchScreen;
  final Duration autoStartAfter;

  @override
  State<VsScreen> createState() => _VsScreenState();
}

class _VsScreenState extends State<VsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dots;
  Timer? _startTimer;

  Player get p => widget.player;
  bool get english => p.english;

  @override
  void initState() {
    super.initState();
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _startTimer = Timer(widget.autoStartAfter, _startMatch);
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _dots.dispose();
    super.dispose();
  }

  void _startMatch() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => widget.matchScreen),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff241d3f), Color(0xff3a2a5e), Color(0xff54346b)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 14),
            Text(
              'CAT PAWS ARENA',
              style: TextStyle(
                color: gold,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                shadows: const [
                  Shadow(color: Color(0x88000000), offset: Offset(0, 2)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              english ? '1v1 DUEL' : 'DUEL 1v1',
              style: const TextStyle(
                color: Color(0xffcbb8e8),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _fighterCard(player: true)),
                  const SizedBox(width: 8),
                  const _VsLightning(),
                  const SizedBox(width: 8),
                  Expanded(child: _fighterCard(player: false)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _stakesPanel(),
            const Spacer(),
            _preparing(),
            const SizedBox(height: 10),
            ArenaButton(
              key: const ValueKey('vs-cancel'),
              text: english ? 'CANCEL' : 'ANULEAZĂ',
              danger: true,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );

  Widget _fighterCard({required bool player}) {
    final blue = player;
    final name = player ? p.name : widget.opponent.name;
    final trophies = player ? p.trophies : widget.opponent.trophies;
    final badge = player ? (english ? 'YOU' : 'TU') : widget.opponent.badge;
    final subtitle = player
        ? (english ? 'PLAYER' : 'JUCĂTOR')
        : widget.opponent.subtitle;
    final avatar = player
        ? CatAvatar(p, size: 58, allowPhoto: false)
        : widget.opponent.avatar;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: blue
              ? const [Color(0xff4a90d9), Color(0xff2f5f9e), Color(0xff1d3f6e)]
              : const [Color(0xff8a5fc0), Color(0xff5e3a8e), Color(0xff3c2554)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: blue ? const Color(0xffbcd8ff) : const Color(0xffe2c8ff),
          width: 1.6,
        ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.flag_rounded, size: 13, color: cream.withValues(alpha: .9)),
              const SizedBox(width: 4),
              Text(
                badge,
                style: const TextStyle(
                  color: cream,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: 66,
            height: 66,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xfffff3d0),
              border: Border.all(color: ink, width: 2),
            ),
            child: ClipOval(child: avatar),
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
              shadows: [Shadow(color: Color(0x66000000), offset: Offset(0, 1))],
            ),
          ),
          const SizedBox(height: 3),
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
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xffd8c8f0),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Wooden Match Stakes board: +30 win / 0 draw / -25 loss.
  Widget _stakesPanel() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 22),
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
            _stake('+30', english ? 'WIN' : 'VICTORIE', const Color(0xffb9e07a)),
            _stake('0', english ? 'DRAW' : 'EGAL', const Color(0xffe8e0d0)),
            _stake('-25', english ? 'LOSS' : 'INFRANGERE', const Color(0xffff9d8a)),
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

  Widget _preparing() => AnimatedBuilder(
    animation: _dots,
    builder: (context, _) {
      Widget dot(int i) {
        final wave =
            0.5 + 0.5 * math.sin((_dots.value * 2 - i * 0.33) * math.pi);
        return Opacity(
          opacity: 0.3 + 0.7 * wave,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: gold,
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
                if (i < 2) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            english ? 'Getting the arena ready...' : 'Se pregătește arena...',
            style: const TextStyle(
              color: Color(0xffd8c8f0),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
    },
  );
}

/// Lightning VS badge between the two fighter cards.
class _VsLightning extends StatelessWidget {
  const _VsLightning();

  @override
  Widget build(BuildContext context) => Container(
    width: 52,
    height: 52,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xfffff6bd), gold, Color(0xffe8a01f)],
      ),
      boxShadow: [
        BoxShadow(color: Color(0x88ffc63c), blurRadius: 14),
        BoxShadow(color: Color(0x66000000), offset: Offset(0, 3)),
      ],
    ),
    child: const Icon(Icons.bolt_rounded, color: ink, size: 30),
  );
}

/// Generic bot head for practice opponents without a fixed house cat.
class _BotAvatar extends StatelessWidget {
  const _BotAvatar({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xff8d8177), Color(0xff5d534b)],
      ),
    ),
    child: Icon(Icons.smart_toy_rounded, color: cream, size: size * .55),
  );
}
