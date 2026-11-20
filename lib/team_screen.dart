import 'package:flutter/material.dart';

import 'profile.dart';
import 'catalog.dart';
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
    if (player.trophies < teamUnlockTrophies) {
      return LockedTabPanel(
        title: english ? 'TEAM' : 'ECHIPA',
        threshold: teamUnlockTrophies,
        trophies: player.trophies,
        english: english,
      );
    }
    return ListView(
      key: const PageStorageKey('team-scroll'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      children: [
        SectionHeading('ECHIPĂ'),
        _TeamHeader(english: english),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 6),
              Center(
                child: arenaImage(
                  'icon_team',
                  width: 64,
                  height: 64,
                  fallback: const Icon(Icons.shield, size: 64),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                english ? 'TEAMS ARRIVE SOON' : 'ECHIPELE VIN ÎN CURÂND',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                english
                    ? 'Friendly duels with your own code already work from the HOME tab. Teams, chat and trading are not live services yet — this page will show them honestly when they arrive.'
                    : 'Duelele cu un prieten prin cod funcționează deja din tab-ul ACASĂ. Echipele, chatul și schimburile nu sunt încă servicii live — această pagină le va arăta onest când vin.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xff6b4a32),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ],
    );
  }
}

class _TeamHeader extends StatelessWidget {
  const _TeamHeader({required this.english});
  final bool english;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
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
                    ? 'Members: coming soon • preset emotes only'
                    : 'Membri: în curând • doar emote presetate',
                style: const TextStyle(
                  color: Color(0xff6b4a32),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0x3351312d),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ink, width: 1.4),
          ),
          child: Text(
            english ? 'PREVIEW' : 'PREVIEW',
            style: const TextStyle(
              color: ink,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    ),
  );
}
