import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'boot_screen.dart';
import 'profile.dart';

/// First thing shown at launch: the Paws & Claws Studios card over pure
/// black. The cinematic cue fires immediately at full volume while the
/// artwork fades in (600 ms), holds (1200 ms) and fades out (600 ms),
/// then hands off to [Boot] — the game splash with its loading bar.
class StudioIntro extends StatefulWidget {
  const StudioIntro({super.key, required this.player});
  final Player player;

  @override
  State<StudioIntro> createState() => _StudioIntroState();
}

class _StudioIntroState extends State<StudioIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..forward();
  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: 1.0).chain(
        CurveTween(curve: Curves.easeIn),
      ),
      weight: 25,
    ),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 0.0).chain(
        CurveTween(curve: Curves.easeOut),
      ),
      weight: 25,
    ),
  ]).animate(_fade);
  final AudioPlayer _audio = AudioPlayer();

  @override
  void initState() {
    super.initState();
    unawaited(
      _audio
          .play(AssetSource('audio/studio_intro_cue.wav'), volume: 1)
          .catchError((Object _) {}),
    );
    _fade.addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, a, b) => Boot(player: widget.player),
          transitionsBuilder: (_, animation, b, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(
      precacheImage(
        const AssetImage('assets/images/studio_logo.png'),
        context,
      ).catchError((Object _) {}),
    );
  }

  @override
  void dispose() {
    _fade.dispose();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: FadeTransition(
      opacity: _opacity,
      child: Image.asset(
        'assets/images/studio_logo.png',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        errorBuilder: (_, _, _) => const SizedBox.expand(),
      ),
    ),
  );
}
