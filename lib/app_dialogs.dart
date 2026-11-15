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
        backgroundColor: const Color(0xfffff4d8),
        surfaceTintColor: Colors.transparent,
        elevation: 14,
        shadowColor: const Color(0x7751312d),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
        titlePadding: const EdgeInsets.fromLTRB(20, 14, 8, 2),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              tooltip: 'ÎNCHIDE',
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(
                Icons.close_rounded,
                color: Color(0xff9a6a45),
                size: 24,
              ),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(child: child),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ArenaButton(
              text: 'ÎNCHIDE',
              secondary: true,
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ),
        ],
      ),
    );

Future<void> showUnavailable(BuildContext context, String feature) =>
    showAppDialog(
      context,
      feature,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 46, color: Color(0xffa97153)),
          const SizedBox(height: 12),
          Text(
            'Această funcție necesită configurarea serviciilor online. Jocul este momentan offline; nu s-a efectuat nicio plată, trimitere de mesaj sau tranzacție.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xff6b4a35),
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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

  OutlineInputBorder fieldBorder(Color color, {double width = 1.2}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.player,
    builder: (context, _) {
      final p = widget.player;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xffffe9bd), Color(0xffd9a86a)],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x443c241a),
                    offset: Offset(0, 4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(21),
                child: CatAvatar(p, size: 96),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: name,
            maxLength: 20,
            decoration: InputDecoration(
              labelText: 'Nume jucător',
              counterText: '',
              filled: true,
              fillColor: const Color(0xfffffbec),
              border: fieldBorder(const Color(0xffd9b98c)),
              enabledBorder: fieldBorder(const Color(0xffd9b98c)),
              focusedBorder: fieldBorder(const Color(0xffc98f3f), width: 1.6),
            ),
          ),
          const SizedBox(height: 10),
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
            secondary: true,
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
            secondary: true,
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
          ('Efecte sonore', Icons.volume_up, p.sfx),
          ('Muzică', Icons.music_note, p.music),
          ('English', Icons.translate, p.english),
          ('Notificări', Icons.notifications, p.notifications),
        ])
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(
              setting.$2,
              color: const Color(0xffa97153),
              size: 26,
            ),
            title: Text(
              setting.$1,
              style: const TextStyle(
                color: ink,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            value: setting.$3,
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
        const SizedBox(height: 6),
        const Text(
          'Preferințele sunt salvate local. Muzica și livrarea notificărilor necesită conținut și servicii suplimentare.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xff8a6a52),
            fontSize: 12,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
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
        Text(
          '${p.trophies} trofee totale',
          style: const TextStyle(
            color: Color(0xff8a6a52),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        for (final entry in [
          (0, 'Living'),
          (300, 'Holul Principal'),
          (800, 'Bucătăria'),
          (1500, 'Dormitorul Stăpânului'),
        ])
          panel(
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xfffff3cf), Color(0xfff0cf96)],
                        ),
                        border: Border.all(
                          color: const Color(0xffcaa06a),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x333c241a),
                            offset: Offset(0, 2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Center(
                        child: sprite(
                          entry.$1 == 1500 ? 'icon_golden_fish' : 'icon_chest',
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${entry.$1} trofee',
                            style: const TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            entry.$2,
                            style: const TextStyle(
                              color: Color(0xff8a6242),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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
