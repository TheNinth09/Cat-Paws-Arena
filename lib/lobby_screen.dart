import 'package:flutter/material.dart';

import 'cat_avatar.dart';
import 'catalog.dart';
import 'profile.dart';
import 'ui_widgets.dart';

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
    padding: const EdgeInsets.all(12),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('trophy-progress'),
        onTap: onRoad,
        borderRadius: BorderRadius.circular(18),
        child: panel(
          Column(
            children: [
              Row(
                children: [
                  sprite('icon_trophy', size: 30),
                  Expanded(
                    child: label(
                      '${player.trophies} / ${player.next}',
                      color: ink,
                      size: 22,
                    ),
                  ),
                  sprite('icon_chest', size: 42),
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: (player.trophies / player.next).clamp(0, 1),
                  minHeight: 14,
                  color: gold,
                  backgroundColor: const Color(0xff6c4244),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${player.room} • Următoarea recompensă: ${player.next}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget hero() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      CatCharacter(player, height: 290),
      label(player.cat, size: 26),
      label(
        powerNames[player.cat == 'Tzuki'
            ? 0
            : player.cat == 'Bubble'
            ? 1
            : player.power],
        size: 14,
      ),
    ],
  );
  Widget controls() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ArenaButton(text: 'MOD: ${modeNames[mode]}', onPressed: onMode),
        ArenaButton(
          text: player.english ? 'BATTLE • PRACTICE' : 'LUPTĂ • ANTRENAMENT',
          onPressed: onBattle,
          spriteName: 'btn_play_paw',
        ),
        const SizedBox(height: 4),
        const Text(
          'Antrenament offline • adversar bot',
          textAlign: TextAlign.center,
          style: TextStyle(color: cream, fontSize: 12),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
      if (constraints.maxHeight < 540 || textScale > 1.3) {
        return ListView(
          key: const PageStorageKey('lobby-scroll'),
          children: [
            progress(),
            Center(child: hero()),
            const SizedBox(height: 12),
            controls(),
          ],
        );
      }
      return Column(
        children: [
          progress(),
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
