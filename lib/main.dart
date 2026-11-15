import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arena.dart';
import 'board_game.dart';
import 'profile.dart';
import 'ui_widgets.dart';

const accessories = [
  'acc_pirate_bandana',
  'acc_witch_hat',
  'acc_pink_bow',
  'acc_ninja_headband',
];
const powers = ['vfx_zoomies', 'vfx_shadow_pounce', 'vfx_laser_chase'];
const powerNames = ['The Midnight Zoomies', 'Shadow Pounce', 'Laser Chase'];
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final player = Player(await SharedPreferences.getInstance());
  runApp(CatPawsApp(player: player));
}

class CatPawsApp extends StatelessWidget {
  const CatPawsApp({super.key, required this.player});
  final Player player;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Cat Paws Arena • Paws & Claws',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: gold),
      scaffoldBackgroundColor: ink,
      fontFamily: 'sans-serif',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: ink, fontWeight: FontWeight.w600),
      ),
    ),
    home: Boot(player: player),
  );
}

class Boot extends StatefulWidget {
  const Boot({super.key, required this.player});
  final Player player;
  @override
  State<Boot> createState() => _BootState();
}

class _BootState extends State<Boot> {
  bool splash = true;
  double progress = 0;
  final audio = AudioPlayer();
  final statuses = [
    'Se pregătesc bobițele...',
    'Se ascund șoriceii...',
    'Se spală lăbuțele...',
    'Se aranjează pernele...',
  ];
  @override
  void initState() {
    super.initState();
    start();
  }

  Future<void> start() async {
    if (widget.player.sfx) {
      unawaited(
        audio.play(AssetSource('generated/purr.wav')).catchError((Object _) {}),
      );
    }
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => splash = false);
    final assets = [
      ...MatchBoard.names,
      'icon_paw_coin',
      'icon_trophy',
      'icon_chest',
      ...powers,
      ...accessories,
      'emote_laugh',
      'emote_angry',
      'emote_love',
    ];
    for (var i = 0; i < assets.length; i++) {
      if (!mounted) return;
      await precacheImage(
        AssetImage('assets/generated/${assets[i]}.png'),
        context,
      );
      if (!mounted) return;
      setState(() => progress = (i + 1) / (assets.length + 1));
    }
    if (!mounted) return;
    setState(() => progress = 1);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, a, b) => Home(player: widget.player),
          transitionsBuilder: (_, a, b, c) =>
              FadeTransition(opacity: a, child: c),
        ),
      );
    }
  }

  @override
  void dispose() {
    audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: splash
        ? Image.asset(
            'assets/studio_splash.png',
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
          )
        : RoomBackground(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            children: [
                              label('CAT PAWS', size: 42),
                              label('ARENA', size: 54, color: gold),
                              label('Paws & Claws', size: 18),
                              const SizedBox(height: 24),
                              CatAvatar(widget.player, size: 160),
                            ],
                          ),
                        ),
                      ),
                    ),
                    panel(
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          label(
                            statuses[min(3, (progress * 4).floor())],
                            size: 17,
                            color: ink,
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 16,
                              color: gold,
                              backgroundColor: ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          label(
                            '${(progress * 100).round()}%',
                            size: 18,
                            color: ink,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
  );
}

class CatAvatar extends StatelessWidget {
  const CatAvatar(this.player, {super.key, this.size = 120});
  final Player player;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (player.photo != null)
          ClipOval(
            child: Image.memory(base64Decode(player.photo!), fit: BoxFit.cover),
          )
        else
          CustomPaint(
            painter: CatPainter(
              player.cat == 'Bubble'
                  ? const Color(0xff292b3c)
                  : player.cat == 'Tzuki'
                  ? const Color(0xff99938b)
                  : [
                      const Color(0xffa99d91),
                      const Color(0xffe7a458),
                      const Color(0xfff4e8d5),
                      const Color(0xff66546f),
                    ][player.fur],
              player.cat == 'Tzuki' ? 1 : player.ears,
              player.cat == 'Bubble'
                  ? gold
                  : [
                      Colors.greenAccent,
                      Colors.lightBlueAccent,
                      gold,
                    ][player.eyes],
              player.cat == 'Tzuki' ? 1 : player.pattern,
            ),
          ),
        if (player.accessory.isNotEmpty)
          Align(
            alignment: Alignment.topCenter,
            child: sprite(player.accessory, size: size * 0.7),
          ),
      ],
    ),
  );
}

class CatPainter extends CustomPainter {
  CatPainter(this.fur, this.ears, this.eye, this.pattern);
  final Color fur, eye;
  final int ears, pattern;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 120, size.height / 120);
    final p = Paint()..color = fur;
    final head = Path()
      ..moveTo(17, 53)
      ..lineTo(12, 6)
      ..quadraticBezierTo(20, 1, 43, 31)
      ..quadraticBezierTo(60, 24, 78, 31);
    if (ears == 0) {
      head.lineTo(107, 6);
      head.lineTo(104, 54);
    } else {
      head.quadraticBezierTo(106, 36, 105, 57);
    }
    head.cubicTo(130, 112, 2, 135, 12, 69);
    head.close();
    canvas.drawPath(head, p);
    canvas.drawPath(
      head,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    p.color = const Color(0xffeca7ad);
    canvas.drawPath(
      Path()
        ..moveTo(19, 15)
        ..lineTo(37, 35)
        ..lineTo(22, 46)
        ..close(),
      p,
    );
    if (pattern > 0) {
      p.color = ink.withValues(alpha: 0.45);
      for (var i = 0; i < 3; i++) {
        canvas.drawOval(Rect.fromLTWH(43 + i * 10, 31, 5, 22 - i * 3), p);
      }
    }
    p.color = const Color(0xffffeddd);
    canvas.drawOval(const Rect.fromLTWH(34, 78, 54, 30), p);
    for (final x in [35.0, 81.0]) {
      p.color = eye;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 65), width: 25, height: 30),
        p,
      );
      p.color = const Color(0xff171b25);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x + 2, 66), width: 12, height: 24),
        p,
      );
      p.color = Colors.white;
      canvas.drawCircle(Offset(x + 5, 58), 4, p);
    }
    p.color = const Color(0xffe78e9c);
    canvas.drawPath(
      Path()
        ..moveTo(51, 83)
        ..lineTo(68, 83)
        ..lineTo(60, 91)
        ..close(),
      p,
    );
    canvas.drawArc(
      const Rect.fromLTWH(42, 86, 18, 13),
      0,
      pi,
      false,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawArc(
      const Rect.fromLTWH(60, 86, 18, 13),
      0,
      pi,
      false,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(CatPainter old) =>
      old.fur != fur ||
      old.ears != ears ||
      old.eye != eye ||
      old.pattern != pattern;
}

class Home extends StatefulWidget {
  const Home({super.key, required this.player});
  final Player player;
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Player get p => widget.player;
  int tab = 2, mode = 0;
  final scaffold = GlobalKey<ScaffoldState>();
  final pages = PageController(initialPage: 2);
  String tr(String ro, String en) => p.english ? en : ro;
  @override
  void initState() {
    super.initState();
    p.addListener(refresh);
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    p.removeListener(refresh);
    pages.dispose();
    super.dispose();
  }

  void select(int i) {
    setState(() => tab = i);
    pages.animateToPage(
      i,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> modal(String title, Widget body) => showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: cream,
      title: Text(
        title,
        style: const TextStyle(color: ink, fontWeight: FontWeight.w900),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(child: body),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: Text(tr('ÎNCHIDE', 'CLOSE')),
        ),
      ],
    ),
  );
  void online(String feature) => modal(
    feature,
    Text(
      tr(
        'Necesită un server și configurarea serviciilor online. Această versiune este offline; nicio tranzacție sau conexiune reală nu a fost efectuată.',
        'Requires a backend and online service configuration. This build is offline; no real transaction or connection was made.',
      ),
    ),
  );
  void profile() {
    final name = TextEditingController(text: p.name);
    modal(
      tr('Profilul meu', 'My profile'),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CatAvatar(p),
          TextField(
            controller: name,
            maxLength: 20,
            decoration: const InputDecoration(labelText: 'Nume / Name'),
          ),
          action('SALVEAZĂ', () {
            if (name.text.trim().isNotEmpty) {
              p.name = name.text.trim();
              p.save();
              Navigator.pop(context);
            }
          }),
          action('Fotografie', () async {
            final image = await ImagePicker().pickImage(
              source: ImageSource.gallery,
              maxWidth: 256,
              maxHeight: 256,
              imageQuality: 75,
            );
            if (image != null) {
              p.photo = base64Encode(await image.readAsBytes());
              p.save();
            }
          }),
          action('Avatar pisică', () {
            p.photo = null;
            p.save();
          }),
        ],
      ),
    );
  }

  void settings() => showDialog<void>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, update) => AlertDialog(
        backgroundColor: cream,
        title: const Text('Settings / Setări'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in [
              ('SFX', p.sfx),
              ('Music', p.music),
              ('English', p.english),
              ('Notifications', p.notifications),
            ])
              SwitchListTile(
                title: Text(item.$1),
                value: item.$2,
                onChanged: (v) {
                  if (item.$1 == 'SFX') p.sfx = v;
                  if (item.$1 == 'Music') p.music = v;
                  if (item.$1 == 'English') p.english = v;
                  if (item.$1 == 'Notifications') p.notifications = v;
                  p.save();
                  update(() {});
                },
              ),
            const Text(
              'Music and notification delivery require additional content/services. Preferences are saved locally.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('OK'),
          ),
        ],
      ),
    ),
  );
  Widget hud() => PlayerHud(
    avatar: CatAvatar(p, size: 46),
    name: p.name,
    trophies: p.trophies,
    coins: p.coins,
    onProfile: profile,
    onRoad: road,
    onShop: () => select(0),
    onMenu: () => scaffold.currentState!.openEndDrawer(),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    key: scaffold,
    endDrawer: Drawer(
      backgroundColor: cream,
      child: SafeArea(
        child: ListView(
          children: [
            const ListTile(
              title: Text(
                'PAWS & CLAWS',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
              ),
            ),
            for (final title in [
              'Google Play / Facebook Cloud Sync',
              'Friends List',
              'Settings',
              'Support',
              "What's New",
              'Leaderboards',
            ])
              ListTile(
                title: Text(title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  if (title == 'Settings') {
                    settings();
                  } else if (title == "What's New") {
                    modal(
                      title,
                      const Text(
                        'Offline arena 1.0 • Match-3 cascades, cat creator, trophy road, local rewards.',
                      ),
                    );
                  } else if (title == 'Leaderboards') {
                    modal(
                      title,
                      DefaultTabController(
                        length: 2,
                        child: SizedBox(
                          height: 170,
                          child: Column(
                            children: [
                              const TabBar(
                                tabs: [
                                  Tab(text: 'Global'),
                                  Tab(text: 'Local'),
                                ],
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'Online rankings unavailable.\n${p.name}: ${p.trophies} trophies',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  } else {
                    online(title);
                  }
                },
              ),
          ],
        ),
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            children: [
              hud(),
              Expanded(
                child: RoomBackground(
                  tier: p.tier,
                  child: PageView(
                    controller: pages,
                    onPageChanged: (i) => setState(() => tab = i),
                    children: [shop(), cats(), lobby(), team(), events()],
                  ),
                ),
              ),
              ArenaBottomBar(
                selected: tab,
                onSelected: select,
                english: p.english,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget list(List<Widget> children) =>
      ListView(padding: const EdgeInsets.all(16), children: children);
  Widget lobby() => ListView(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: InkWell(
          onTap: road,
          child: panel(
            Column(
              children: [
                Row(
                  children: [
                    sprite('icon_trophy'),
                    Expanded(
                      child: label('${p.trophies} / ${p.next}', color: ink),
                    ),
                    sprite('icon_chest'),
                  ],
                ),
                LinearProgressIndicator(
                  value: (p.trophies / p.next).clamp(0, 1),
                  color: gold,
                  backgroundColor: ink,
                  minHeight: 12,
                ),
                const SizedBox(height: 6),
                Text(
                  '${p.room} • ${tr('Următoarea recompensă', 'Next reward')}: ${p.next}',
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Center(child: CatAvatar(p, size: 180)),
      label(p.cat, size: 32),
      label(
        powerNames[p.cat == 'Tzuki'
            ? 0
            : p.cat == 'Bubble'
            ? 1
            : p.power],
        size: 16,
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            action(
              '${tr('MOD', 'MODE')}: ${['1v1 Arena', 'Speed Rush', 'Survival', 'High-Stakes Ranked'][mode]}',
              () => modal(
                'Mod de joc',
                Column(
                  children: [
                    for (var i = 0; i < 4; i++)
                      action(
                        '${['1v1 Arena', 'Speed Rush', 'Survival', 'High-Stakes Ranked'][i]}${i > p.tier ? ' • ${[0, 300, 800, 1500][i]} trofee' : ''}',
                        i <= p.tier
                            ? () {
                                setState(() => mode = i);
                                Navigator.pop(context);
                              }
                            : null,
                      ),
                  ],
                ),
              ),
            ),
            action(tr('LUPTĂ • ANTRENAMENT', 'BATTLE • PRACTICE'), start),
            const Text(
              'Offline bot • no live matchmaking',
              textAlign: TextAlign.center,
              style: TextStyle(color: cream, fontSize: 12),
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    ],
  );
  Future<void> start() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MatchScreen(player: p, mode: mode),
      ),
    );
    refresh();
  }

  void road() => modal(
    tr('Turul Casei', 'Trophy Road'),
    Column(
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
              children: [
                sprite(
                  entry.$1 == 1500 ? 'icon_golden_fish' : 'icon_chest',
                  size: 60,
                ),
                Text('${entry.$1} • ${entry.$2}', textAlign: TextAlign.center),
                action(
                  p.claims.contains(entry.$1) ? 'Revendicat' : '+100 Lăbuțe',
                  p.trophies >= entry.$1 && !p.claims.contains(entry.$1)
                      ? () {
                          p.claims.add(entry.$1);
                          p.coins += 100;
                          p.save();
                          Navigator.pop(context);
                          road();
                        }
                      : null,
                ),
              ],
            ),
          ),
      ],
    ),
  );
  Widget shop() => list([
    label(tr('MAGAZIN', 'SHOP'), size: 32),
    panel(
      Column(
        children: [
          label(tr('Cadoul zilei', 'Daily gift'), color: ink),
          sprite('icon_chest', size: 75),
          action(
            '+200 Lăbuțe',
            p.daily == p.today
                ? null
                : () {
                    p.claimDaily();
                  },
          ),
        ],
      ),
    ),
    ProductCard(
      title: 'Oferta zilei',
      subtitle: 'Pirate + The Midnight Zoomies',
      spriteName: 'acc_pirate_bandana',
      buttonText: p.owned.contains('daily_combo') ? 'DEȚINUT' : '650 Lăbuțe',
      onPressed: p.owned.contains('daily_combo')
          ? null
          : () {
              if (p.coins >= 650) {
                p.coins -= 650;
                p.owned.addAll(['daily_combo', accessories[0], powers[0]]);
                p.save();
              } else {
                modal('Oferta zilei', const Text('Nu ai suficiente Lăbuțe.'));
              }
            },
    ),
    label('Accesorii & Puteri'),
    for (final item in [...accessories, ...powers])
      ProductCard(
        title: item
            .replaceAll('acc_', '')
            .replaceAll('vfx_', '')
            .replaceAll('_', ' '),
        spriteName: item,
        buttonText: p.owned.contains(item) ? 'DEȚINUT' : '300 Lăbuțe',
        onPressed: p.owned.contains(item)
            ? null
            : () {
                if (!p.buy(item, 300)) {
                  modal('Lăbuțe', const Text('Nu ai suficiente Lăbuțe.'));
                }
              },
      ),
    label('Lăbuțe • IAP'),
    const Text(
      'Purchases unavailable in this offline build.',
      style: TextStyle(color: cream),
    ),
    for (final pack in [
      ('500', '8.99'),
      ('1,500', '22.99'),
      ('3,250 MOST POPULAR', '44.99'),
      ('7,000', '89.99'),
      ('12,750', '134.99'),
      ('25,000 BEST VALUE', '224.99'),
    ])
      ProductCard(
        title: pack.$1,
        spriteName: 'icon_paw_coin',
        subtitle: 'Pachet de Lăbuțe',
        buttonText: '${pack.$2} LEI',
        onPressed: () => online('Google Play Billing'),
      ),
  ]);
  Widget cats() => list([
    label(tr('PISICILE TALE', 'YOUR CATS'), size: 30),
    Center(child: CatAvatar(p, size: 180)),
    for (final cat in ['Tzuki', 'Bubble', 'Custom'])
      panel(
        Row(
          children: [
            const Icon(Icons.pets, size: 40),
            Expanded(child: Text(cat == 'Custom' ? 'Creează-ți Pisica' : cat)),
            action(p.cat == cat ? 'ECHIPAT' : 'ALEGE', () {
              p.cat = cat;
              p.photo = null;
              p.save();
            }),
          ],
        ),
      ),
    panel(
      Column(
        children: [
          const Text(
            'Tzuki • ONLY left ear • The Midnight Zoomies\nBubble • Shadow Pounce',
            textAlign: TextAlign.center,
          ),
          if (p.cat == 'Custom') ...[
            const Text('Culoare blană'),
            Wrap(
              children: [
                for (var i = 0; i < 4; i++)
                  action(['Gri', 'Portocaliu', 'Crem', 'Mov'][i], () {
                    p.fur = i;
                    p.save();
                  }),
              ],
            ),
            const Text('Model'),
            Wrap(
              children: [
                for (var i = 0; i < 2; i++)
                  action(['Uniform', 'Tigrat'][i], () {
                    p.pattern = i;
                    p.save();
                  }),
              ],
            ),
            const Text('Ochi'),
            Wrap(
              children: [
                for (var i = 0; i < 3; i++)
                  action(['Verzi', 'Albaștri', 'Aurii'][i], () {
                    p.eyes = i;
                    p.save();
                  }),
              ],
            ),
            Wrap(
              children: [
                for (var i = 0; i < 2; i++)
                  action(['Două urechi', 'Doar stânga'][i], () {
                    p.ears = i;
                    p.save();
                  }),
              ],
            ),
            for (var i = 0; i < 3; i++)
              action(
                powerNames[i],
                i == 0 || p.owned.contains(powers[i])
                    ? () {
                        p.power = i;
                        p.save();
                      }
                    : null,
              ),
          ],
        ],
      ),
    ),
    label('Accesorii'),
    action('Fără accesoriu', () {
      p.accessory = '';
      p.save();
    }),
    for (final item in accessories)
      panel(
        Row(
          children: [
            sprite(item, size: 70),
            Expanded(
              child: action(
                p.owned.contains(item) ? 'ECHIPEAZĂ' : 'MAGAZIN • 300',
                () {
                  if (p.owned.contains(item)) {
                    p.accessory = item;
                    p.save();
                  } else {
                    select(0);
                  }
                },
              ),
            ),
          ],
        ),
      ),
  ]);
  Widget team() => list([
    label('ECHIPĂ', size: 32),
    panel(
      Column(
        children: [
          const Icon(Icons.shield, size: 70),
          Text(
            p.trophies < 200
                ? 'Se deblochează la 200 trofee'
                : 'Echipe • Online backend required',
          ),
          TextField(
            enabled: p.trophies >= 200,
            decoration: const InputDecoration(labelText: 'Caută o echipă'),
          ),
          action(
            'CAUTĂ / ALĂTURĂ-TE',
            p.trophies >= 200 ? () => online('Team Search') : null,
          ),
          action(
            'CREEAZĂ ECHIPĂ',
            p.trophies >= 200 ? () => online('Create Team') : null,
          ),
          action(
            'CHAT LIVE',
            p.trophies >= 200 ? () => online('Team Chat') : null,
          ),
          action(
            'SCHIMB • Accesorii / Costume / Puteri',
            p.trophies >= 200 ? () => online('Trade System') : null,
          ),
        ],
      ),
    ),
  ]);
  Widget events() => list([
    label('EVENIMENTE', size: 32),
    panel(
      DefaultTabController(
        length: 2,
        child: SizedBox(
          height: 340,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Global'),
                  Tab(text: 'Private'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    ListView(
                      children: [
                        const SizedBox(height: 20),
                        sprite('icon_golden_fish', size: 90),
                        Text(
                          p.trophies < 250
                              ? 'Se deblochează la 250 trofee'
                              : 'Turneele live necesită server.',
                        ),
                        action(
                          'TURNEE GLOBALE',
                          p.trophies >= 250
                              ? () => online('Global Tournament')
                              : null,
                        ),
                      ],
                    ),
                    ListView(
                      children: [
                        const TextField(
                          decoration: InputDecoration(labelText: 'Cod turneu'),
                        ),
                        action(
                          'ALĂTURĂ-TE',
                          p.trophies >= 250
                              ? () => online('Join Private Tournament')
                              : null,
                        ),
                        action(
                          'CREEAZĂ COD',
                          p.trophies >= 250
                              ? () => online('Create Private Tournament')
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ]);
}

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key, required this.player, required this.mode});
  final Player player;
  final int mode;
  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> with WidgetsBindingObserver {
  final board = MatchBoard(), bot = MatchBoard();
  late BoardGame game;
  Timer? clock;
  int remaining = 90, botScore = 0;
  bool searching = true, ended = false, paused = false;
  int? result;
  String emote = '';
  int botTrophies = 0;
  Player get p => widget.player;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    botTrophies = max(0, p.trophies + Random().nextInt(151) - 75);
    game = BoardGame(
      board,
      refresh,
      () {
        bot.obstacle();
      },
      [
        'obs_cardboard_box',
        'obs_slipper',
        'obs_tangled_yarn',
        'obs_tangled_yarn',
      ][p.tier],
    );
    begin();
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  Future<void> begin() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted || ended) return;
    setState(() {
      searching = false;
      remaining = widget.mode == 1 ? 45 : 90;
    });
    clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (paused || ended) return;
      remaining--;
      if (remaining % 3 == 0) {
        final previousAttacks = bot.attacks;
        bot.autoMove();
        botScore = bot.score;
        if (bot.attacks > previousAttacks && !game.busy) board.obstacle();
      }
      if (widget.mode == 2 && remaining % 8 == 0 && !game.busy) {
        board.obstacle();
      }
      if (remaining <= 0) {
        finish(board.score.compareTo(botScore));
      } else {
        refresh();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    paused = state != AppLifecycleState.resumed;
    game.suspended = paused;
  }

  @override
  void dispose() {
    clock?.cancel();
    game.active = false;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void finish(int outcome) {
    if (ended) return;
    ended = true;
    game.active = false;
    clock?.cancel();
    p.result(outcome);
    setState(() => result = outcome);
  }

  Future<void> surrender() async {
    paused = true;
    game.suspended = true;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Renunți la meci?'),
        content: const Text('Vei pierde 25 de trofee.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('CONTINUĂ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('RENUNȚĂ'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    paused = false;
    game.suspended = false;
    if (yes == true) finish(-1);
  }

  void emotes() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: cream,
    builder: (c) => SafeArea(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final item in ['emote_laugh', 'emote_angry', 'emote_love'])
            InkWell(
              onTap: () {
                Navigator.pop(c);
                setState(() => emote = item);
                Future<void>.delayed(const Duration(seconds: 2), () {
                  if (mounted) setState(() => emote = '');
                });
              },
              child: sprite(item, size: 95),
            ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: ended,
    onPopInvokedWithResult: (didPop, value) {
      if (!didPop) surrender();
    },
    child: Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: RoomBackground(
              tier: p.tier,
              dim: true,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: result != null
                    ? resultView()
                    : searching
                    ? vsView()
                    : battle(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget vsView() => ListView(
    padding: const EdgeInsets.symmetric(vertical: 20),
    children: [
      label('ANTRENAMENT OFFLINE', size: 28),
      label('Opponent simulated • ±75 trophies', size: 15),
      const SizedBox(height: 30),
      Center(child: CatAvatar(p, size: 120)),
      label('${p.name} • RO • ${p.trophies}'),
      label('VS', size: 54),
      sprite('emote_angry', size: 110),
      label('Bubble Bot • RO • $botTrophies'),
      const SizedBox(height: 25),
      label('+30 Win • 0 Draw • -25 Loss', size: 18),
      const SizedBox(height: 20),
      const Center(child: CircularProgressIndicator(color: gold)),
    ],
  );
  Widget battle() => ListView(
    children: [
      Row(
        children: [
          TextButton(
            onPressed: surrender,
            child: const Text('Renunță', style: TextStyle(color: cream)),
          ),
          Expanded(child: label('$remaining s')),
          IconButton(
            onPressed: () async {
              paused = true;
              game.suspended = true;
              await showDialog<void>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Pauză'),
                  content: const Text('Offline practice is paused.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('CONTINUĂ'),
                    ),
                  ],
                ),
              );
              if (mounted) {
                paused = false;
                game.suspended = false;
              }
            },
            icon: const Icon(Icons.settings, color: cream),
          ),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              children: [
                CatAvatar(p, size: 52),
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: cream,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                label('${board.score}', size: 18),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                sprite('emote_angry', size: 52),
                label('Bubble Bot', size: 16),
                label('$botScore', size: 18),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: GameWidget(game: game),
        ),
      ),
      if (emote.isNotEmpty) sprite(emote, size: 65),
      LinearProgressIndicator(
        value: board.charge / 100,
        color: gold,
        backgroundColor: ink,
        minHeight: 14,
      ),
      Row(
        children: [
          Expanded(
            child: action(
              '${powerNames[p.cat == 'Tzuki'
                  ? 0
                  : p.cat == 'Bubble'
                  ? 1
                  : p.power]} • ${board.charge}%',
              board.charge >= 100
                  ? () => game.power(
                      p.cat == 'Tzuki'
                          ? 0
                          : p.cat == 'Bubble'
                          ? 1
                          : p.power,
                    )
                  : null,
            ),
          ),
          IconButton(
            onPressed: emotes,
            icon: const Icon(Icons.emoji_emotions, color: gold, size: 36),
          ),
        ],
      ),
      label('Match 4 / 5 → attack • Combo × cascades', size: 13),
    ],
  );
  Widget resultView() => ListView(
    padding: const EdgeInsets.symmetric(vertical: 20),
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CatAvatar(p, size: 55),
          const SizedBox(width: 8),
          Expanded(child: label('${p.name}\n${p.trophies} trofee', size: 18)),
          sprite('icon_paw_coin', size: 28),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: label('${p.coins}', size: 18),
            ),
          ),
        ],
      ),
      const SizedBox(height: 30),
      sprite(
        result! > 0
            ? 'icon_trophy'
            : result! < 0
            ? 'emote_angry'
            : 'emote_love',
        size: 140,
      ),
      label(
        result! > 0
            ? 'VICTORIE!'
            : result! < 0
            ? 'ÎNFRÂNGERE'
            : 'EGALITATE',
        size: 38,
      ),
      label('${board.score} — $botScore'),
      label(
        result! > 0
            ? '+30 Trofee • +150 Lăbuțe'
            : result! < 0
            ? '-25 Trofee'
            : '0 Trofee',
        size: 20,
      ),
      const SizedBox(height: 35),
      action('REVANȘĂ', () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (_) => MatchScreen(player: p, mode: widget.mode),
          ),
        );
      }),
      action('ACASĂ', () => Navigator.pop(context)),
    ],
  );
}
