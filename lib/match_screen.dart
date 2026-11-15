import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'app_dialogs.dart';
import 'cat_avatar.dart';
import 'catalog.dart';
import 'match_controller.dart';
import 'profile.dart';
import 'ui_widgets.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key, required this.player, required this.mode});
  final Player player;
  final int mode;
  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> with WidgetsBindingObserver {
  late final ArenaMatchController match;
  Timer? emoteTimer;
  String emote = '';
  bool showingDialog = false;
  Player get p => widget.player;
  int get power => p.cat == 'Tzuki'
      ? 0
      : p.cat == 'Bubble'
      ? 1
      : p.power;
  @override
  void initState() {
    super.initState();
    match = ArenaMatchController(p, widget.mode);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    match.pause(background: state != AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    emoteTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    match.dispose();
    super.dispose();
  }

  Future<void> surrender() async {
    if (showingDialog || match.phase == MatchPhase.finished) return;
    showingDialog = true;
    match.pause(modal: true);
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: cream,
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
    showingDialog = false;
    match.pause(modal: false);
    if (yes == true) match.finish(-1);
  }

  Future<void> pause() async {
    match.pause(modal: true);
    await showSettings(context, p);
    if (mounted) match.pause(modal: false);
  }

  void emotes() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: cream,
    builder: (c) => SafeArea(
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        children: [
          for (final item in ['emote_laugh', 'emote_angry', 'emote_love'])
            InkWell(
              onTap: () {
                Navigator.pop(c);
                emoteTimer?.cancel();
                setState(() => emote = item);
                emoteTimer = Timer(const Duration(seconds: 2), () {
                  if (mounted) setState(() => emote = '');
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: sprite(item, size: 75),
              ),
            ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: match,
    builder: (context, _) => PopScope(
      canPop: match.phase == MatchPhase.finished,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) surrender();
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                children: [
                  if (match.phase != MatchPhase.playing)
                    PlayerHud(
                      avatar: CatAvatar(p, size: 46),
                      name: p.name,
                      trophies: p.trophies,
                      coins: p.coins,
                      onProfile: () => showPlayerProfile(context, p),
                      onRoad: () => showTrophyRoad(context, p),
                      onShop: () => showAppDialog(
                        context,
                        'Lăbuțe',
                        const Text(
                          'Pachetele sunt disponibile în fila Magazin din ecranul principal.',
                        ),
                      ),
                      onMenu: () => showSettings(context, p),
                    ),
                  Expanded(
                    child: RoomBackground(
                      tier: p.tier,
                      dim: true,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: switch (match.phase) {
                          MatchPhase.searching => versus(),
                          MatchPhase.playing => battle(),
                          MatchPhase.finished => result(),
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget versus() => ListView(
    padding: const EdgeInsets.symmetric(vertical: 18),
    children: [
      label('ANTRENAMENT OFFLINE', size: 25),
      label('Adversar bot • ±75 trofee', size: 14),
      const SizedBox(height: 18),
      Center(child: CatAvatar(p, size: 95)),
      label('${p.name} • RO • ${p.trophies}', size: 18),
      label('VS', size: 44, color: gold),
      sprite('emote_angry', size: 95),
      label('Bubble Bot • RO • ${match.botTrophies}', size: 18),
      const SizedBox(height: 18),
      label('+30 Victorie • 0 Egal • -25 Înfrângere', size: 15),
      const SizedBox(height: 18),
      const Center(child: CircularProgressIndicator(color: gold)),
    ],
  );
  Widget score(Widget avatar, String name, int points) => Expanded(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        avatar,
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: cream, fontWeight: FontWeight.bold),
        ),
        label('$points', size: 18),
      ],
    ),
  );
  Widget battle() => Column(
    children: [
      Row(
        children: [
          TextButton(
            onPressed: surrender,
            child: const Text('Renunță', style: TextStyle(color: cream)),
          ),
          Expanded(child: label('${match.remaining} s', size: 22)),
          IconButton(
            tooltip: 'Setări',
            onPressed: pause,
            icon: const Icon(Icons.settings, color: cream),
          ),
        ],
      ),
      Row(
        children: [
          score(CatAvatar(p, size: 42), p.name, match.board.score),
          score(sprite('emote_angry', size: 42), 'Bubble Bot', match.botScore),
        ],
      ),
      const SizedBox(height: 8),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = constraints.biggest.shortestSide;
            return Center(
              child: SizedBox.square(
                dimension: side,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: GameWidget(game: match.game),
                      ),
                    ),
                    if (emote.isNotEmpty)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: IgnorePointer(child: sprite(emote, size: 64)),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LinearProgressIndicator(
          value: match.board.charge / 100,
          minHeight: 12,
          color: gold,
          backgroundColor: ink,
        ),
      ),
      Row(
        children: [
          Expanded(
            child: Tooltip(
              message: powerNames[power],
              child: ArenaButton(
                text:
                    '${['ZOOMIES', 'SHADOW POUNCE', 'LASER CHASE'][power]} • ${match.board.charge}%',
                spriteName: powers[power],
                onPressed: match.board.charge >= 100
                    ? () => match.game.power(power)
                    : null,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Emote',
            onPressed: emotes,
            icon: const Icon(Icons.emoji_emotions, color: gold, size: 32),
          ),
        ],
      ),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: label('4 / 5 piese → obstacol • Cascade → combo', size: 12),
      ),
    ],
  );
  Widget result() => ListView(
    padding: const EdgeInsets.symmetric(vertical: 20),
    children: [
      sprite(
        match.result! > 0
            ? 'icon_trophy'
            : match.result! < 0
            ? 'emote_angry'
            : 'emote_love',
        size: 125,
      ),
      label(
        match.result! > 0
            ? 'VICTORIE!'
            : match.result! < 0
            ? 'ÎNFRÂNGERE'
            : 'EGALITATE',
        size: 34,
      ),
      label('${match.board.score} — ${match.botScore}'),
      panel(
        Column(
          children: [
            label(
              match.result! > 0
                  ? '+30 Trofee • +150 Lăbuțe'
                  : match.result! < 0
                  ? '-25 Trofee'
                  : '0 Trofee',
              size: 20,
              color: ink,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                sprite('icon_chest', size: 70),
                const SizedBox(width: 16),
                CatAvatar(p, size: 90),
              ],
            ),
          ],
        ),
      ),
      ArenaButton(
        text: 'REVANȘĂ',
        green: true,
        onPressed: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (_) => MatchScreen(player: p, mode: widget.mode),
          ),
        ),
      ),
      ArenaButton(text: 'ACASĂ', onPressed: () => Navigator.pop(context)),
    ],
  );
}
