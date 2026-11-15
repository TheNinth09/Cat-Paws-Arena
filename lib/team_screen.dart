import 'package:flutter/material.dart';

import 'catalog.dart';
import 'profile.dart';
import 'ui_widgets.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({
    super.key,
    required this.player,
    required this.onUnavailable,
  });
  final Player player;
  final ValueChanged<String> onUnavailable;
  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final search = TextEditingController(), message = TextEditingController();
  String? offer, wanted;
  bool get unlocked => widget.player.trophies >= 200;
  @override
  void dispose() {
    search.dispose();
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey('team-scroll'),
    padding: const EdgeInsets.all(12),
    children: [
      panel(
        Row(
          children: [
            const Icon(Icons.shield, color: Color(0xffc18a35), size: 48),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ECHIPA TA',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    unlocked
                        ? 'Nicio echipă conectată'
                        : 'Se deblochează la 200 trofee',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: search,
              enabled: unlocked,
              decoration: const InputDecoration(
                labelText: 'Caută o echipă',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            ArenaButton(
              text: 'CAUTĂ / ALĂTURĂ-TE',
              onPressed: unlocked
                  ? () => widget.onUnavailable('Căutare echipă')
                  : null,
              green: true,
            ),
            ArenaButton(
              text: 'CREEAZĂ ECHIPĂ',
              onPressed: unlocked
                  ? () => widget.onUnavailable('Creare echipă')
                  : null,
            ),
          ],
        ),
      ),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'CHAT ECHIPĂ',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const Divider(color: ink),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Mesajele echipei vor apărea aici după conectarea la server. Nu există mesaje live în versiunea offline.',
                textAlign: TextAlign.center,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xffffdfa1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ink, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'CERERE DE TRADE (SCHIMB)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  sprite(offer ?? 'acc_witch_hat', size: 64),
                  DropdownButtonFormField<String>(
                    initialValue: offer,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'OFERĂ'),
                    items: [
                      for (final item in [
                        ...accessories,
                        ...powers,
                      ].where(widget.player.owned.contains))
                        DropdownMenuItem(
                          value: item,
                          child: Text(
                            itemName(item),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: unlocked
                        ? (v) => setState(() => offer = v)
                        : null,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: wanted,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'CERE'),
                    items: [
                      for (final item in [...accessories, ...powers])
                        DropdownMenuItem(
                          value: item,
                          child: Text(
                            itemName(item),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: unlocked
                        ? (v) => setState(() => wanted = v)
                        : null,
                  ),
                  ArenaButton(
                    text: 'TRIMITE CERERE',
                    green: true,
                    onPressed: unlocked && offer != null && wanted != null
                        ? () => widget.onUnavailable('Schimb între coechipieri')
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: message,
              enabled: unlocked,
              maxLength: 200,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Scrie un mesaj...',
                border: OutlineInputBorder(),
              ),
            ),
            ArenaButton(
              text: 'TRIMITE MESAJ',
              onPressed: unlocked
                  ? () => widget.onUnavailable('Chat echipă')
                  : null,
              green: true,
            ),
          ],
        ),
      ),
    ],
  );
}
