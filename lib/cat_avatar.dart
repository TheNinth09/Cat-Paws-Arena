import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import 'profile.dart';
import 'ui_widgets.dart';

Color furColor(Player p) => p.cat == 'Bubble'
    ? const Color(0xff292b3c)
    : p.cat == 'Tzuki'
    ? const Color(0xff99938b)
    : [
        const Color(0xffa99d91),
        const Color(0xffe7a458),
        const Color(0xfff4e8d5),
        const Color(0xff66546f),
      ][p.fur];

class CatAvatar extends StatelessWidget {
  const CatAvatar(
    this.player, {
    super.key,
    this.size = 120,
    this.allowPhoto = true,
  });
  final Player player;
  final double size;
  final bool allowPhoto;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (allowPhoto && player.photo != null)
          ClipOval(
            child: Image.memory(base64Decode(player.photo!), fit: BoxFit.cover),
          )
        else
          CustomPaint(
            painter: CatPainter(
              furColor(player),
              player.cat == 'Tzuki'
                  ? 1
                  : player.cat == 'Bubble'
                  ? 0
                  : player.ears,
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
            child: sprite(player.accessory, size: size * .7),
          ),
      ],
    ),
  );
}

class CatCharacter extends StatelessWidget {
  const CatCharacter(this.player, {super.key, this.height = 300});
  final Player player;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: height * .78,
    child: Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _BodyPainter(
              furColor(player),
              player.cat == 'Tzuki' || player.pattern > 0,
            ),
          ),
        ),
        Positioned(
          top: height * .025,
          left: height * .15,
          child: CatAvatar(player, size: height * .5, allowPhoto: false),
        ),
      ],
    ),
  );
}

class _BodyPainter extends CustomPainter {
  const _BodyPainter(this.fur, this.striped);
  final Color fur;
  final bool striped;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 240, size.height / 310);
    final p = Paint()..color = fur;
    final tail = Path()
      ..moveTo(94, 266)
      ..cubicTo(15, 244, -2, 295, 49, 294)
      ..quadraticBezierTo(82, 301, 135, 282);
    canvas.drawPath(
      tail,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 27
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      tail,
      Paint()
        ..color = fur
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round,
    );
    final body = Path()
      ..moveTo(104, 111)
      ..cubicTo(67, 139, 43, 232, 62, 273)
      ..quadraticBezierTo(128, 299, 198, 271)
      ..cubicTo(202, 219, 192, 150, 165, 113)
      ..close();
    canvas.drawPath(body, p);
    canvas.drawPath(
      body,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    p.color = const Color(0xffffeddd);
    canvas.drawOval(const Rect.fromLTWH(111, 130, 62, 124), p);
    if (striped) {
      p.color = ink.withValues(alpha: .5);
      for (var i = 0; i < 4; i++) {
        canvas.drawOval(Rect.fromLTWH(71 - i * 3, 160 + i * 24, 32, 9), p);
      }
    }
    for (final x in [102.0, 153.0]) {
      p.color = fur;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 222, 30, 60),
          const Radius.circular(12),
        ),
        p,
      );
      p.color = const Color(0xffffeddd);
      canvas.drawOval(Rect.fromLTWH(x - 4, 263, 39, 20), p);
      canvas.drawOval(
        Rect.fromLTWH(x - 4, 263, 39, 20),
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.fur != fur || old.striped != striped;
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
      p.color = ink.withValues(alpha: .45);
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
    for (final x in [42.0, 60.0]) {
      canvas.drawArc(
        Rect.fromLTWH(x, 86, 18, 13),
        0,
        pi,
        false,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CatPainter old) =>
      old.fur != fur ||
      old.ears != ears ||
      old.eye != eye ||
      old.pattern != pattern;
}
