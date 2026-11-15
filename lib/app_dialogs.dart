import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'cat_avatar.dart';
import 'profile.dart';
import 'ui_widgets.dart';

Future<void> showAppDialog(BuildContext context, String title, Widget child) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cream,
        title: Text(
          title,
          style: const TextStyle(color: ink, fontWeight: FontWeight.w900),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(child: child),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ÎNCHIDE'),
          ),
        ],
      ),
    );
Future<void> showUnavailable(BuildContext context, String feature) =>
    showAppDialog(
      context,
      feature,
      const Text(
        'Această funcție necesită configurarea serviciilor online. Jocul este momentan offline; nu s-a efectuat nicio plată, trimitere de mesaj sau tranzacție.',
      ),
    );
Future<void> showPlayerProfile(BuildContext context, Player p) =>
    showAppDialog(context, 'Profilul meu', _ProfileEditor(player: p));

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({required this.player});
  final Player player;
  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late final name = TextEditingController(text: widget.player.name);
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.player,
    builder: (context, _) {
      final p = widget.player;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CatAvatar(p, size: 100),
          TextField(
            controller: name,
            maxLength: 20,
            decoration: const InputDecoration(labelText: 'Nume jucător'),
          ),
          ArenaButton(
            text: 'SALVEAZĂ',
            green: true,
            onPressed: () {
              if (name.text.trim().isNotEmpty) {
                p.name = name.text.trim();
                p.save();
                Navigator.pop(context);
              }
            },
          ),
          ArenaButton(
            text: 'FOTOGRAFIE',
            onPressed: () async {
              final image = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                maxWidth: 256,
                maxHeight: 256,
                imageQuality: 75,
              );
              if (image == null) return;
              final bytes = await image.readAsBytes();
              if (!mounted) return;
              p.photo = base64Encode(bytes);
              p.save();
            },
          ),
          ArenaButton(
            text: 'AVATAR PISICĂ',
            onPressed: () {
              p.photo = null;
              p.save();
            },
          ),
        ],
      );
    },
  );
}

Future<void> showSettings(BuildContext context, Player p) => showAppDialog(
  context,
  'Setări',
  AnimatedBuilder(
    animation: p,
    builder: (context, _) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final setting in [
          ('Efecte sonore', p.sfx),
          ('Muzică', p.music),
          ('English', p.english),
          ('Notificări', p.notifications),
        ])
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(setting.$1),
            value: setting.$2,
            onChanged: (v) {
              switch (setting.$1) {
                case 'Efecte sonore':
                  p.sfx = v;
                case 'Muzică':
                  p.music = v;
                case 'English':
                  p.english = v;
                case 'Notificări':
                  p.notifications = v;
              }
              p.save();
            },
          ),
        const Text(
          'Preferințele sunt salvate local. Muzica și livrarea notificărilor necesită conținut și servicii suplimentare.',
        ),
      ],
    ),
  ),
);
Future<void> showTrophyRoad(BuildContext context, Player p) => showAppDialog(
  context,
  'Turul Casei',
  AnimatedBuilder(
    animation: p,
    builder: (context, _) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final entry in [
          (0, 'Living'),
          (200, 'Echipă'),
          (250, 'Evenimente'),
          (300, 'Holul Principal • Speed Rush'),
          (800, 'Bucătăria • Survival'),
          (1500, 'Dormitor • Ranked'),
        ])
          panel(
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                sprite(
                  entry.$1 == 1500 ? 'icon_golden_fish' : 'icon_chest',
                  size: 60,
                ),
                Text(
                  '${entry.$1} trofee • ${entry.$2}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                ArenaButton(
                  text: p.claims.contains(entry.$1)
                      ? 'REVENDICAT'
                      : '+100 Lăbuțe',
                  green: true,
                  onPressed:
                      p.trophies >= entry.$1 && !p.claims.contains(entry.$1)
                      ? () {
                          p.claims.add(entry.$1);
                          p.coins += 100;
                          p.save();
                        }
                      : null,
                ),
              ],
            ),
          ),
      ],
    ),
  ),
);
