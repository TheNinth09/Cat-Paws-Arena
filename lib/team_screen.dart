import 'package:flutter/material.dart';

import 'profile.dart';
import 'ui_widgets.dart';

class TeamScreen extends StatelessWidget {
  const TeamScreen({
    super.key,
    required this.player,
    required this.onUnavailable,
  });
  final Player player;
  final ValueChanged<String> onUnavailable;

  @override
  Widget build(BuildContext context) {
    final english = player.english;
    return ListView(
      key: const PageStorageKey('team-scroll'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      children: [
        SectionHeading('ECHIPĂ'),
        _TeamHeader(english: english),
        SectionHeading(
          english ? 'TEAM SOCIAL (PARKED)' : 'SOCIAL ECHIPĂ (PARKED)',
        ),
        panel(_chatPanel(english)),
        panel(_tradePanel(english)),
        _inputBar(english),
        const SizedBox(height: 8),
        Text(
          english
              ? 'Teams, free-text chat and trading are parked. Nothing here is a live service.'
              : 'Echipele, chatul liber și schimburile sunt parked. Nimic de aici nu este un serviciu live.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xff6b4a32),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _chatPanel(bool english) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        english ? 'MESSAGES (PARKED)' : 'MESAJE (PARKED)',
        style: const TextStyle(
          color: ink,
          fontSize: 15,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        english
            ? 'No live chat. When teams are enabled, only preset emotes will be available.'
            : 'Niciun chat live. Când echipele vor fi activate, vor exista doar emote presetate.',
        style: const TextStyle(
          color: Color(0xff6b4a32),
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final name in ['emote_love', 'emote_laugh', 'emote_angry'])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Opacity(opacity: 0.65, child: sprite(name, size: 34)),
            ),
        ],
      ),
    ],
  );

  Widget _tradePanel(bool english) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 10),
      Text(
        english ? 'TRADE REQUEST (PARKED)' : 'CERERE DE TRADE (PARKED)',
        style: const TextStyle(
          color: ink,
          fontSize: 15,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        english
            ? 'Trading is parked; there is no shared live inventory or peer-to-peer exchange.'
            : 'Schimburile sunt parked; nu există inventar partajat live sau schimb peer-to-peer.',
        style: const TextStyle(
          color: Color(0xff6b4a32),
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 10),
      ArenaButton(
        text: english ? 'TRADE' : 'SCHIMBĂ',
        onPressed: () {
          onUnavailable(english ? 'Team trading' : 'Schimburi de echipă');
        },
        secondary: true,
        singleLine: true,
      ),
    ],
  );

  Widget _inputBar(bool english) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xfffffbec),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: ink, width: 1.8),
    ),
    child: Row(
      children: [
        sprite('tile_paw', size: 28),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            english ? 'Chat is parked...' : 'Chatul este parked...',
            style: TextStyle(
              color: ink.withValues(alpha: 0.45),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Icon(Icons.send, color: ink.withValues(alpha: 0.35)),
      ],
    ),
  );
}

class _TeamHeader extends StatelessWidget {
  const _TeamHeader({required this.english});
  final bool english;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xfffff3c4), gold, Color(0xffe8a92e)],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: ink, width: 2.4),
      boxShadow: const [
        BoxShadow(
          color: Color(0x6651312d),
          offset: Offset(0, 4),
          blurRadius: 6,
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xff51312d),
            border: Border.all(color: gold, width: 2),
          ),
          child: const Icon(Icons.shield, color: gold, size: 30),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                english ? 'TEAM: ROYAL CATS' : 'ECHIPA: PISICILE REGALE',
                style: const TextStyle(
                  color: ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                english
                    ? 'Members: parked • preset emotes only'
                    : 'Membri: parked • doar emote presetate',
                style: const TextStyle(
                  color: Color(0xff6b4a32),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
