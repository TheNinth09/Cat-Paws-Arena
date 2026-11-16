import 'package:flutter/material.dart';

import 'profile.dart';
import 'shell/parked_surface.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({
    super.key,
    required this.player,
    required this.onUnavailable,
    this.onBattle,
  });
  final Player player;
  final ValueChanged<String> onUnavailable;
  final void Function(int mode)? onBattle;

  @override
  Widget build(BuildContext context) => ParkedSurface(
    title: 'EVENIMINTE',
    icon: Icons.emoji_events_rounded,
    english: player.english,
    points: player.english
        ? const ['Weekend challenges', 'Private tournaments', 'Leaderboards']
        : const ['Challenge de weekend', 'Turnee private', 'Clasamente'],
    note: player.english
        ? 'Events and tournaments are parked. No live leaderboard, tournament or online event is connected.'
        : 'Evenimentele și turneele sunt parked. Niciun leaderboard, turneu sau eveniment online live nu este conectat.',
  );
}
