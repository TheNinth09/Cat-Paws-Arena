import 'package:flutter/material.dart';

import 'profile.dart';
import 'shell/parked_surface.dart';

class TeamScreen extends StatelessWidget {
  const TeamScreen({
    super.key,
    required this.player,
    required this.onUnavailable,
  });
  final Player player;
  final ValueChanged<String> onUnavailable;

  @override
  Widget build(BuildContext context) => ParkedSurface(
    title: 'ECHIPĂ',
    icon: Icons.groups_rounded,
    english: player.english,
    points: player.english
        ? const [
            'Online teams',
            'Preset emotes only',
            'No free-text chat or trading',
          ]
        : const [
            'Echipe online',
            'Doar emote presetate',
            'Fără chat liber sau schimburi',
          ],
    note: player.english
        ? 'Team play is parked. Nothing here is a live service; friend duels use room codes from the Battle tab.'
        : 'Echipele sunt parked. Nimic de aici nu este un serviciu live; duelurile de prieten folosesc coduri de cameră din tab-ul LUPTĂ.',
  );
}
