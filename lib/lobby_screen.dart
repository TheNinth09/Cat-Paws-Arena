import 'package:flutter/material.dart';

import 'cat_avatar.dart';
import 'catalog.dart';
import 'profile.dart';
import 'ui_widgets.dart';

const _cardGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xffffe0a0), Color(0xffffedbb), Color(0xffe9ab60)],
);
const _stageGradient = RadialGradient(
  center: Alignment(0, -0.55),
  radius: 1.05,
  colors: [Color(0xfffff6d8), Color(0xfff4d9a0), Color(0xffe2a866)],
);
const _goldGradient = LinearGradient(
  colors: [Color(0xfffff3c4), gold, Color(0xffe8a92e)],
);

class LobbyScreen extends StatelessWidget {
  const LobbyScreen({
    super.key,
    required this.player,
    required this.mode,
    required this.onMode,
    required this.onBattle,
    required this.onRoad,
  });
  final Player player;
  final int mode;
  final VoidCallback onMode, onBattle, onRoad;
  Widget progress() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('trophy-progress'),
        onTap: onRoad,
        borderRadius: BorderRadius.circular(20),
        child: _TrophyCard(player: player),
      ),
    ),
  );
  Widget hero() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _HeroStage(player: player),
      const SizedBox(height: 8),
      label(player.cat, size: 24),
      const SizedBox(height: 4),
      _PowerPill(
        powerNames[player.cat == 'Tzuki'
            ? 0
            : player.cat == 'Bubble'
            ? 1
            : player.power],
      ),
    ],
  );
  Widget controls() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ArenaButton(text: 'MOD: ${modeNames[mode]}', onPressed: onMode),
        const SizedBox(height: 4),
        ArenaButton(
          text: player.english ? 'BATTLE • PRACTICE' : 'LUPTĂ • ANTRENAMENT',
          onPressed: onBattle,
          green: true,
          spriteName: 'btn_play_paw',
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0x553b2a24),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x55ffc63c), width: 1),
          ),
          child: const Text(
            'Antrenament offline • adversar bot',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cream,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final strip = _ModeStrip(player: player, mode: mode, onTap: onMode);
      if (constraints.maxHeight < 580 || textScale > 1.3) {
        return ListView(
          key: const PageStorageKey('lobby-scroll'),
          padding: const EdgeInsets.only(bottom: 14),
          children: [
            progress(),
            const SizedBox(height: 4),
            strip,
            const SizedBox(height: 10),
            Center(child: hero()),
            const SizedBox(height: 8),
            controls(),
          ],
        );
      }
      return Column(
        children: [
          progress(),
          strip,
          Expanded(
            child: Center(
              child: FittedBox(fit: BoxFit.scaleDown, child: hero()),
            ),
          ),
          controls(),
        ],
      );
    },
  );
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon(this.asset);
  final String asset;
  @override
  Widget build(BuildContext context) => Container(
    width: 50,
    height: 50,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: _goldGradient,
      border: Border.all(color: ink, width: 2.5),
      boxShadow: const [
        BoxShadow(
          color: Color(0x5561312d),
          offset: Offset(0, 3),
          blurRadius: 3,
        ),
      ],
    ),
    child: Center(child: sprite(asset, size: 30)),
  );
}

class _TrophyCard extends StatelessWidget {
  const _TrophyCard({required this.player});
  final Player player;

  @override
  Widget build(BuildContext context) {
    final ratio = (player.trophies / player.next).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: _cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ink, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x6651312d),
            offset: Offset(0, 4),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          _BadgeIcon('icon_trophy'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'TROFEE',
                      style: TextStyle(
                        color: Color(0xff8a5a3b),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        player.room,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Color(0xff8a5a3b),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 32,
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${player.trophies} / ${player.next}',
                      softWrap: false,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xff6c4244),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ink, width: 1.5),
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
                const SizedBox(height: 4),
                Text(
                  'Următoarea recompensă: ${player.next}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xff7a4a32),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          sprite('icon_chest', size: 44),
        ],
      ),
    );
  }
}

class _HeroStage extends StatelessWidget {
  const _HeroStage({required this.player});
  final Player player;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 420),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: _stageGradient,
        border: Border.all(color: ink, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x6651312d),
            offset: Offset(0, 5),
            blurRadius: 8,
          ),
        ],
      ),
      child: SizedBox(
        height: 245,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 6,
              left: 14,
              child: Opacity(
                opacity: 0.25,
                child: sprite('tile_paw', size: 30),
              ),
            ),
            Positioned(
              bottom: 4,
              right: 14,
              child: Opacity(
                opacity: 0.25,
                child: sprite('tile_paw', size: 30),
              ),
            ),
            CatCharacter(player, height: 235),
          ],
        ),
      ),
    ),
  );
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

class _ModeStrip extends StatelessWidget {
  const _ModeStrip({
    required this.player,
    required this.mode,
    required this.onTap,
  });
  final Player player;
  final int mode;
  final VoidCallback onTap;

  static const _icons = [
    Icons.group,
    Icons.bolt,
    Icons.hourglass_empty,
    Icons.emoji_events,
  ];
  static const _tags = ['1V1', 'RUSH', 'SURV', 'RANK'];

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 4, 14, 2),
    child: Row(
      children: [
        for (var i = 0; i < _icons.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _ModeTile(
                icon: _icons[i],
                tag: _tags[i],
                selected: i == mode,
                locked: i > player.tier,
                onTap: onTap,
              ),
            ),
          ),
      ],
    ),
  );
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.icon,
    required this.tag,
    required this.selected,
    required this.locked,
    required this.onTap,
  });
  final IconData icon;
  final String tag;
  final bool selected, locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          gradient: selected ? _goldGradient : null,
          color: selected ? null : const Color(0x663b2a24),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? ink : const Color(0x77ffc63c),
            width: selected ? 2 : 1.2,
          ),
        ),
        child: Opacity(
          opacity: locked ? 0.55 : 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                locked ? Icons.lock_outline : icon,
                size: 19,
                color: selected ? ink : cream,
              ),
              const SizedBox(height: 3),
              Text(
                tag,
                style: TextStyle(
                  color: selected ? ink : cream,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
