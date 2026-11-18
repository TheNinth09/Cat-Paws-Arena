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
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _bubble(
                'cat_tzuki',
                'Miorlău22',
                english ? 'Hello everyone!' : 'Salutare tuturor!',
              ),
              _bubble(
                'cat_bubble',
                'ShadowCat',
                english
                    ? 'Anyone up for a match?'
                    : 'Cine are chef de un meci?',
              ),
              _tradeCard(english),
              _bubble(
                'emote_love',
                'Pisoi_Lover',
                english ? 'Request sent!' : 'Am trimis cererea!',
              ),
            ],
          ),
        ),
        _inputBar(english),
        const SizedBox(height: 8),
        Text(
          english
              ? 'Preview only — teams, chat and trading arrive later. Nothing here is a live service.'
              : 'Doar previzualizare — echipele, chatul și schimburile vin în curând. Nimic de aici nu este live.',
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

  Widget _bubble(String catArt, String name, String message) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xfff3e0b8),
            border: Border.all(color: ink, width: 1.8),
          ),
          child: ClipOval(
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: arenaImage(
                catArt,
                width: 34,
                height: 34,
                fallback: sprite(catArt, size: 34),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xfffffbec),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: ink, width: 1.6),
            ),
            child: Text(
              '$name: $message',
              style: const TextStyle(
                color: ink,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _tradeCard(bool english) => Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xffffe6a8), Color(0xfff6c46a)],
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: ink, width: 2),
      boxShadow: const [
        BoxShadow(color: Color(0x4451312d), offset: Offset(0, 3)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          english ? 'TRADE REQUEST' : 'CERERE DE TRADE (SCHIMB)',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: ink,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            sprite('acc_witch_hat', size: 44),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    english ? 'OFFERS: Gigel' : 'OFERĂ: Gigel',
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    english ? 'Wizard Hat' : 'Pălărie Vrăjitoare',
                    style: const TextStyle(
                      color: Color(0xff6b4a32),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    english
                        ? 'ASKS: Pirate Bandana / Zoomies'
                        : 'CERE: Bandană Pirat / Putere Zoomies',
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      sprite('acc_pirate_bandana', size: 34),
                      const SizedBox(width: 8),
                      arenaImage(
                        'power_zoomies',
                        width: 34,
                        height: 34,
                        fallback: sprite('vfx_zoomies', size: 34),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 120,
              child: ArenaButton(
                text: english ? 'TRADE' : 'SCHIMBĂ',
                singleLine: true,
                onPressed: () {
                  onUnavailable(
                    english ? 'Team trading' : 'Schimburi de echipă',
                  );
                },
              ),
            ),
          ],
        ),
      ],
    ),
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
            english ? 'Chat arrives soon...' : 'Chatul vine în curând...',
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
