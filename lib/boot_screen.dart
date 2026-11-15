import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'arena.dart';
import 'cat_avatar.dart';
import 'catalog.dart';
import 'home_screen.dart';
import 'profile.dart';
import 'ui_widgets.dart';

class Boot extends StatefulWidget {
  const Boot({super.key, required this.player});
  final Player player;
  @override
  State<Boot> createState() => _BootState();
}

class _BootState extends State<Boot> {
  final audio = AudioPlayer();
  bool splash = true;
  double progress = 0;
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
      setState(() => progress = (i + 1) / assets.length);
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, a, b) => Home(player: widget.player),
        transitionsBuilder: (_, animation, b, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: splash
        ? const StudioSplash()
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
                              const SizedBox(height: 20),
                              CatCharacter(widget.player, height: 240),
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

class StudioSplash extends StatelessWidget {
  const StudioSplash({super.key});
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: cream,
    child: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pets, color: ink, size: 86),
              const SizedBox(height: 18),
              Text(
                'PAWS & CLAWS',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(color: ink, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'GAME STUDIO',
                style: TextStyle(
                  color: ink,
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
