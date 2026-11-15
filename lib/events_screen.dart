import 'package:flutter/material.dart';

import 'profile.dart';
import 'ui_widgets.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({
    super.key,
    required this.player,
    required this.onUnavailable,
  });
  final Player player;
  final ValueChanged<String> onUnavailable;
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final code = TextEditingController();
  int selected = 0;
  bool get unlocked => widget.player.trophies >= 250;
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey('events-scroll'),
    padding: const EdgeInsets.all(12),
    children: [
      panel(
        Row(
          children: [
            for (var i = 0; i < 2; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ArenaButton(
                    text: ['GLOBAL', 'PRIVATE'][i],
                    green: selected == i,
                    onPressed: () => setState(() => selected = i),
                  ),
                ),
              ),
          ],
        ),
        padding: const EdgeInsets.all(6),
      ),
      if (!unlocked)
        panel(
          const Text(
            'Evenimentele se deblochează la 250 trofee.',
            textAlign: TextAlign.center,
          ),
        ),
      if (selected == 0)
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              label('TURNEUL GLOBAL\nDE WEEKEND', size: 27, color: ink),
              const SizedBox(height: 18),
              sprite('icon_golden_fish', size: 140),
              const SizedBox(height: 12),
              const Text(
                'Calendarul și participanții sunt disponibili doar după conectarea la server.',
                textAlign: TextAlign.center,
              ),
              ArenaButton(
                text: 'INTRĂ ÎN TURNEU',
                green: true,
                onPressed: unlocked
                    ? () => widget.onUnavailable('Turneu global')
                    : null,
              ),
            ],
          ),
        ),
      const SectionHeading('EVENIMENTE PRIVATE'),
      AdaptiveCardGrid(
        minWidth: 140,
        maxColumns: 2,
        children: [
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label('CREEAZĂ EVENIMENT', size: 18, color: ink),
                const SizedBox(height: 12),
                const Icon(Icons.key, color: Color(0xffcb8b28), size: 70),
                ArenaButton(
                  text: 'CREEAZĂ',
                  onPressed: unlocked
                      ? () => widget.onUnavailable('Creare turneu privat')
                      : null,
                ),
              ],
            ),
          ),
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label('INTRĂ CU COD', size: 18, color: ink),
                const SizedBox(height: 12),
                sprite('icon_trophy', size: 70),
                ArenaButton(
                  text: 'INTRODU CODUL',
                  onPressed: unlocked
                      ? () => setState(() => selected = 1)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
      if (selected == 1)
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: code,
                enabled: unlocked,
                maxLength: 12,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Cod turneu',
                  border: OutlineInputBorder(),
                ),
              ),
              ArenaButton(
                text: 'ALĂTURĂ-TE',
                green: true,
                onPressed: unlocked
                    ? () => widget.onUnavailable('Intrare în turneu privat')
                    : null,
              ),
            ],
          ),
        ),
    ],
  );
}
