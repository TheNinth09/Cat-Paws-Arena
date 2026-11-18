import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'arena.dart';
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
  double progress = 0;

  String statusFor(double value) {
    if (value < 0.18) return 'Se deșteaptă pisica...';
    if (value < 0.42) return 'Se ascund șoriceii...';
    if (value < 0.68) return 'Se adună firele de lână...';
    if (value < 0.9) return 'Se lustruiesc trofeele...';
    return 'Totul e gata de luptă!';
  }

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    start();
  }

  Future<void> start() async {
    if (widget.player.sfx) {
      unawaited(
        audio.play(AssetSource('generated/purr.wav')).catchError((Object _) {}),
      );
    }
    unawaited(
      precacheImage(
        const AssetImage('assets/images/splash_screen.png'),
        context,
      ).catchError((Object _) {}),
    );
    final imageAssets = [
      ...MatchBoard.names,
      'tile_box',
      'special_fish_rocket',
      'special_yarn_bomb',
      'special_mouse_copter',
      'special_rainbow_paw',
      'cat_tzuki',
      'cat_bubble',
      'cat_cushion',
      'trophy_gold_fish',
      'milestone_chest',
      'paws_daily_5',
      'btn_emote',
      'emote_happy',
      'emote_cheer',
      'emote_surprised',
      'emote_laugh',
    ];
    final generatedAssets = [
      'icon_paw_coin',
      'icon_trophy',
      'icon_chest',
      ...powers,
      ...accessories,
      'emote_angry',
      'emote_love',
    ];
    final assets = [
      for (final n in imageAssets) 'assets/images/$n.png',
      for (final n in generatedAssets) 'assets/generated/$n.png',
    ];
    for (var i = 0; i < assets.length; i++) {
      if (!mounted) return;
      await precacheImage(
        AssetImage(assets[i]),
        context,
      ).catchError((Object _) {});
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
    body: Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/splash_screen.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0xCC1c0f08),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        const Positioned.fill(child: CustomPaint(painter: _BootCharm())),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                panel(
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        statusFor(progress),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _YarnProgress(progress),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text(
                            'ÎNCĂRCARE',
                            style: TextStyle(
                              color: Color(0xff8a5a3b),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.8,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(progress * 100).round()}%',
                            style: const TextStyle(
                              color: ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
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
      ],
    ),
  );
}

class _YarnProgress extends StatelessWidget {
  const _YarnProgress(this.value);
  final double value;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: value),
    duration: const Duration(milliseconds: 280),
    curve: Curves.easeOutCubic,
    builder: (context, v, _) => SizedBox(
      height: 30,
      width: double.infinity,
      child: CustomPaint(painter: _YarnPainter(v)),
    ),
  );
}

class _YarnPainter extends CustomPainter {
  const _YarnPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cy = h / 2;
    const trackH = 16.0;
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, cy - trackH / 2, w, trackH),
      const Radius.circular(trackH / 2),
    );
    final paint = Paint();

    paint.color = const Color(0xff5f4034);
    canvas.drawRRect(track, paint);
    paint
      ..color = const Color(0x8851312d)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(track, paint);
    paint.style = PaintingStyle.fill;

    final p = progress.clamp(0.0, 1.0);
    if (p > 0.001) {
      final fillW = w * p;
      canvas.save();
      canvas.clipRRect(track);
      paint.shader = const LinearGradient(
        colors: [Color(0xfffff0b0), gold, Color(0xffe8961f)],
      ).createShader(Rect.fromLTWH(0, cy - trackH / 2, fillW, trackH));
      canvas.drawRect(Rect.fromLTWH(0, cy - trackH / 2, fillW, trackH), paint);
      paint.shader = null;
      paint
        ..color = const Color(0x4d3c241a)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      for (var x = -trackH; x < fillW + trackH; x += 7) {
        canvas.drawLine(
          Offset(x, cy + trackH / 2),
          Offset(x + trackH, cy - trackH / 2),
          paint,
        );
      }
      paint
        ..color = const Color(0x55ffffff)
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(0, cy - trackH / 2 + 2.5),
        Offset(fillW, cy - trackH / 2 + 2.5),
        paint,
      );
      canvas.restore();
    }

    final ballX = 12 + (w - 24) * p;
    final ballY = cy - 1;
    const br = 11.0;
    if (p > 0.02) {
      paint
        ..color = const Color(0xffd9a05b)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(
        Path()
          ..moveTo(ballX - br + 2, ballY + 3)
          ..quadraticBezierTo(
            ballX - br - 7,
            ballY + 10,
            ballX - br - 15,
            cy + trackH / 2 - 2,
          ),
        paint,
      );
    }
    paint.style = PaintingStyle.fill;
    paint.color = const Color(0xff8a5a34);
    canvas.drawCircle(Offset(ballX, ballY), br, paint);
    paint
      ..color = const Color(0xff5f3a22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(ballX, ballY), radius: br * 0.78),
      0.4,
      2.4,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(ballX, ballY), radius: br * 0.52),
      1.7,
      2.8,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(ballX, ballY), radius: br * 0.28),
      0.1,
      2.1,
      false,
      paint,
    );
    paint
      ..color = const Color(0x40fff3d0)
      ..strokeWidth = 2;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(ballX, ballY), radius: br * 0.85),
      3.5,
      1.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_YarnPainter old) => old.progress != progress;
}

class _BootCharm extends CustomPainter {
  const _BootCharm();

  void paw(
    Canvas canvas,
    Offset center,
    double r,
    double rotation,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, r * 0.4),
        width: r * 1.45,
        height: r * 1.05,
      ),
      paint,
    );
    for (var i = -1; i <= 1; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(i * r * 0.52, -r * 0.42),
          width: r * 0.6,
          height: r * 0.78,
        ),
        paint,
      );
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(r * 0.6, -r * 0.02),
        width: r * 0.52,
        height: r * 0.66,
      ),
      paint,
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint()..color = const Color(0x12ffedbb);
    paw(canvas, Offset(w * 0.13, h * 0.15), 24, -0.35, paint);
    paw(canvas, Offset(w * 0.88, h * 0.12), 17, 0.45, paint);
    paw(canvas, Offset(w * 0.08, h * 0.55), 15, 0.25, paint);
    paw(canvas, Offset(w * 0.93, h * 0.6), 19, -0.3, paint);

    final yc = Offset(w * 0.12, h * 0.93);
    final yr = (w < h ? w : h) * 0.07;
    paint
      ..color = const Color(0x66d9a05b)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(yc.dx + yr * 0.5, yc.dy - yr * 0.3)
        ..cubicTo(
          yc.dx + yr * 2.4,
          yc.dy - yr * 1.4,
          yc.dx + yr * 3.6,
          yc.dy - yr * 0.2,
          yc.dx + yr * 4.4,
          yc.dy - yr * 0.9,
        ),
      paint,
    );
    paint.style = PaintingStyle.fill;
    paint.color = const Color(0xff8a5a34);
    canvas.drawCircle(yc, yr, paint);
    paint
      ..color = const Color(0xff5f3a22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = yr * 0.16;
    canvas.drawArc(
      Rect.fromCircle(center: yc, radius: yr * 0.78),
      0.4,
      2.4,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: yc, radius: yr * 0.52),
      1.7,
      2.8,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: yc, radius: yr * 0.28),
      0.1,
      2.1,
      false,
      paint,
    );
    paint
      ..color = const Color(0x40fff3d0)
      ..strokeWidth = yr * 0.14;
    canvas.drawArc(
      Rect.fromCircle(center: yc, radius: yr * 0.85),
      3.5,
      1.5,
      false,
      paint,
    );

    paint.color = const Color(0x1affedbb);
    for (final o in [
      Offset(w * 0.3, h * 0.08),
      Offset(w * 0.65, h * 0.06),
      Offset(w * 0.5, h * 0.16),
    ]) {
      canvas.drawCircle(o, 3, paint);
    }
  }

  @override
  bool shouldRepaint(_BootCharm old) => false;
}

