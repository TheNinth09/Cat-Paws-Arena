import 'dart:async';

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

  String statusFor(double value) {
    if (value < 0.18) return 'Se deșteaptă pisica...';
    if (value < 0.42) return 'Se ascund șoriceii...';
    if (value < 0.68) return 'Se adună firele de lână...';
    if (value < 0.9) return 'Se lustruiesc trofeele...';
    return 'Totul e gata de luptă!';
  }

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
            tier: widget.player.tier,
            dim: true,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: _BootCharm()),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                    child: Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  label('CAT PAWS', size: 40),
                                  label('ARENA', size: 52, color: gold),
                                  label(
                                    'Paws & Claws',
                                    size: 16,
                                    color: const Color(0xffe8c9a0),
                                  ),
                                  const SizedBox(height: 16),
                                  CatCharacter(widget.player, height: 200),
                                ],
                              ),
                            ),
                          ),
                        ),
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
          ),
  );
}

class StudioSplash extends StatelessWidget {
  const StudioSplash({super.key});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xff46301f), Color(0xff6b422c), Color(0xff8a5433)],
      ),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(child: CustomPaint(painter: _SplashBackdrop())),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 850),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, _) => Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, 28 * (1 - t)),
                      child: _splashLockup(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _splashLockup() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 124,
        height: 124,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xfffff3c4), gold, Color(0xffe8961f)],
          ),
          border: Border.all(color: ink, width: 3),
          boxShadow: const [
            BoxShadow(color: Color(0x66ffc63c), blurRadius: 24),
            BoxShadow(
              color: Color(0x553c241a),
              offset: Offset(0, 6),
              blurRadius: 10,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xfffff8e0), Color(0xfff0d6a0)],
              ),
              border: Border.all(color: const Color(0x66b57f4e), width: 1.5),
            ),
            child: Center(
              child: SizedBox(
                width: 70,
                height: 70,
                child: CustomPaint(
                  painter: CatPainter(
                    const Color(0xffe7a458),
                    1,
                    Colors.greenAccent,
                    1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 20),
      Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'PAWS & ',
              style: TextStyle(
                color: cream,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                shadows: const [
                  Shadow(
                    color: Color(0x66000000),
                    offset: Offset(0, 3),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            TextSpan(
              text: 'CLAWS',
              style: TextStyle(
                color: gold,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                shadows: const [
                  Shadow(
                    color: Color(0x66000000),
                    offset: Offset(0, 3),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 6),
      const Text(
        'GAME STUDIO',
        style: TextStyle(
          color: Color(0xffe8c9a0),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 6,
        ),
      ),
      const SizedBox(height: 22),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 34, height: 2, color: const Color(0x55ffc63c)),
          const SizedBox(width: 10),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: gold,
              border: Border.all(color: ink, width: 1),
            ),
          ),
          const SizedBox(width: 10),
          Container(width: 34, height: 2, color: const Color(0x55ffc63c)),
        ],
      ),
      const SizedBox(height: 14),
      const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pets, size: 15, color: Color(0xffd8b48f)),
          SizedBox(width: 6),
          Text(
            'CAT PAWS ARENA • v1.0.2',
            style: TextStyle(
              color: Color(0xffd8b48f),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ),
    ],
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

class _SplashBackdrop extends CustomPainter {
  const _SplashBackdrop();

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
    final paint = Paint();
    paint.shader = RadialGradient(
      center: const Alignment(0, -0.7),
      radius: 0.95,
      colors: [const Color(0x33ffc63c), const Color(0x00ffc63c)],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
    paint.shader = null;

    paint.color = const Color(0x10ffedbb);
    paw(canvas, Offset(w * 0.13, h * 0.17), 26, -0.4, paint);
    paw(canvas, Offset(w * 0.88, h * 0.13), 18, 0.5, paint);
    paw(canvas, Offset(w * 0.09, h * 0.68), 17, 0.3, paint);
    paw(canvas, Offset(w * 0.93, h * 0.72), 23, -0.25, paint);

    final yc = Offset(w * 0.87, h * 0.92);
    final yr = (w < h ? w : h) * 0.085;
    paint
      ..color = const Color(0x80d9a05b)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(yc.dx - yr * 0.6, yc.dy + yr * 0.5)
        ..cubicTo(
          yc.dx - yr * 2.2,
          yc.dy + yr * 1.6,
          yc.dx - yr * 3.4,
          yc.dy + yr * 0.4,
          yc.dx - yr * 4.2,
          yc.dy + yr * 1.1,
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
  }

  @override
  bool shouldRepaint(_SplashBackdrop old) => false;
}
