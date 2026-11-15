import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'profile.dart';
import 'ui_widgets.dart';

/// Fur palette. The index matches [Player.fur]; indices 0-3 keep the
/// colours used by older saves, 4 is black and 5 is white.
const catFurColours = <Color>[
  Color(0xffa99d91), // 0 — grey
  Color(0xffe7a458), // 1 — orange
  Color(0xfff4e8d5), // 2 — cream
  Color(0xff66546f), // 3 — purple
  Color(0xff292b3c), // 4 — black
  Color(0xfff7f3ea), // 5 — white
];

/// Iris palette. The index matches [Player.eyes]; indices 0-2 keep the
/// colours used by older saves, 3 is copper.
const catEyeColours = <Color>[
  Color(0xff69f0ae), // 0 — green
  Color(0xff40c4ff), // 1 — blue
  Color(0xffffc63c), // 2 — gold
  Color(0xffb06a3b), // 3 — copper
];

/// Number of selectable coat patterns: 0 solid, 1 tabby, 2 bicolour,
/// 3 calico, 4 colourpoint. Matches [Player.pattern].
const catPatternCount = 5;

/// Number of ear variants: 0 two ears, 1 left ear only, 2 folded,
/// 3 tufted. Indices 0-1 keep the meaning older saves used.
const catEarCount = 4;

int _clampIndex(int value, int length) =>
    value < 0 ? 0 : value >= length ? length - 1 : value;

/// Visual description of a cat, independent of [Player]. Every field is a
/// plain value so a spec can be serialized, compared, and rendered by any
/// lane without touching profile or inventory state.
class CatSpec {
  const CatSpec({
    required this.fur,
    required this.pattern,
    required this.eyes,
    required this.ears,
    this.accessory = '',
  });

  /// Resolved fur colour.
  final Color fur;

  /// Pattern index in `0..[catPatternCount)`.
  final int pattern;

  /// Resolved iris colour.
  final Color eyes;

  /// Ear variant index in `0..[catEarCount)`.
  final int ears;

  /// Accessory sprite name from `assets/generated/` ('' = none).
  final String accessory;

  /// Builds a spec from palette indices, clamping out-of-range values so
  /// stale saves can never crash the renderer.
  factory CatSpec.custom({
    int fur = 0,
    int pattern = 0,
    int eyes = 0,
    int ears = 0,
    String accessory = '',
  }) => CatSpec(
    fur: catFurColours[_clampIndex(fur, catFurColours.length)],
    pattern: _clampIndex(pattern, catPatternCount),
    eyes: catEyeColours[_clampIndex(eyes, catEyeColours.length)],
    ears: _clampIndex(ears, catEarCount),
    accessory: accessory,
  );

  @override
  bool operator ==(Object other) =>
      other is CatSpec &&
      other.fur == fur &&
      other.pattern == pattern &&
      other.eyes == eyes &&
      other.ears == ears &&
      other.accessory == accessory;

  @override
  int get hashCode => Object.hash(fur, pattern, eyes, ears, accessory);
}

/// Resolves the visual spec for a cat selection. [cat] is `'Tzuki'`,
/// `'Bubble'`, or anything else (the custom cat reads palette indices from
/// [p]). Preset cats keep their identity: Tzuki is a grey tabby with only
/// the left ear, Bubble is solid black with gold eyes.
CatSpec catSpecFor(String cat, Player p) => switch (cat) {
  'Bubble' => CatSpec(
    fur: const Color(0xff292b3c),
    pattern: 0,
    eyes: const Color(0xffffc63c),
    ears: 0,
    accessory: p.accessory,
  ),
  'Tzuki' => CatSpec(
    fur: const Color(0xff99938b),
    pattern: 1,
    eyes: catEyeColours[_clampIndex(p.eyes, catEyeColours.length)],
    ears: 1,
    accessory: p.accessory,
  ),
  _ => CatSpec.custom(
    fur: p.fur,
    pattern: p.pattern,
    eyes: p.eyes,
    ears: p.ears,
    accessory: p.accessory,
  ),
};

/// The spec [CatAvatar] and [CatCharacter] render for [p].
CatSpec catSpecForPlayer(Player p) => catSpecFor(p.cat, p);

Color furColor(Player p) => catSpecForPlayer(p).fur;

/// Semantic name of a render layer, bottom to top.
enum CatLayerKind { ears, base, pattern, muzzle, eyes }

/// One paint layer of the cat. Each painter draws in a canonical space —
/// 120×120 for the head layers, 240×310 for the body layers — with a
/// transparent background, matching what a transparent PNG layer would
/// contain.
class CatLayer {
  const CatLayer(this.kind, this.painter);
  final CatLayerKind kind;
  final CustomPainter painter;
}

/// Ordered head layers for [spec], bottom to top.
List<CatLayer> catLayers(CatSpec spec) => [
  CatLayer(CatLayerKind.ears, _EarPainter(spec.fur, spec.ears)),
  CatLayer(CatLayerKind.base, _HeadBasePainter(spec.fur)),
  CatLayer(CatLayerKind.pattern, _HeadPatternPainter(spec)),
  CatLayer(CatLayerKind.muzzle, const _MuzzlePainter()),
  CatLayer(CatLayerKind.eyes, _EyePainter(spec.eyes)),
];

/// Ordered body layers for the full-body [CatCharacter], bottom to top.
List<CatLayer> catBodyLayers(CatSpec spec) => [
  CatLayer(CatLayerKind.base, _BodyBasePainter(spec.fur)),
  CatLayer(CatLayerKind.pattern, _BodyPatternPainter(spec)),
];

/// Paints a [CatSpec] as an ordered stack of independent layers. Used by
/// [CatSpecAvatar] and [CatCharacter]; tests can narrow [onlyLayers] to
/// prove a single layer does not affect the others.
class CatLayersPainter extends CustomPainter {
  const CatLayersPainter(this.spec, {this.body = false, this.onlyLayers});

  final CatSpec spec;

  /// When true, paints the 240×310 body layers instead of the head.
  final bool body;

  /// Optional subset of layer kinds to paint; null paints all of them.
  final Set<CatLayerKind>? onlyLayers;

  @override
  void paint(Canvas canvas, Size size) {
    final layers = body ? catBodyLayers(spec) : catLayers(spec);
    for (final layer in layers) {
      if (onlyLayers != null && !onlyLayers!.contains(layer.kind)) {
        continue;
      }
      layer.painter.paint(canvas, size);
    }
  }

  @override
  bool shouldRepaint(CatLayersPainter oldDelegate) =>
      oldDelegate.spec != spec ||
      oldDelegate.body != body ||
      !setEquals(oldDelegate.onlyLayers, onlyLayers);
}

// ---------------------------------------------------------------------------
// Shared geometry. All coordinates live in the canonical head space
// (120×120) or body space (240×310) and are mirrored for the right side
// about x = 62 (head) / x = 124 equivalents as noted per helper.
// ---------------------------------------------------------------------------

Path _headPath() => Path()
  ..moveTo(62, 16)
  ..cubicTo(32, 16, 12, 42, 11, 72)
  ..cubicTo(10, 104, 34, 122, 63, 122)
  ..cubicTo(94, 122, 114, 102, 113, 70)
  ..cubicTo(112, 40, 90, 16, 62, 16)
  ..close();

Path _bodyPath() => Path()
  ..moveTo(104, 111)
  ..cubicTo(67, 139, 43, 232, 62, 273)
  ..quadraticBezierTo(128, 299, 198, 271)
  ..cubicTo(202, 219, 192, 150, 165, 113)
  ..close();

Path _tailPath() => Path()
  ..moveTo(94, 266)
  ..cubicTo(15, 244, -2, 295, 49, 294)
  ..quadraticBezierTo(82, 301, 135, 282);

/// Outer ear silhouettes for [ears], left side first then mirrored right.
/// Index 1 keeps only the left ear; 2 are folded flops; 3 adds tufts.
List<Path> _earOuterPaths(int ears) {
  if (ears == 2) {
    return [
      Path()..addOval(Rect.fromCenter(center: const Offset(27, 31), width: 36, height: 18)),
      Path()..addOval(Rect.fromCenter(center: const Offset(97, 31), width: 36, height: 18)),
    ];
  }
  final left = Path()
    ..moveTo(15, 5)
    ..cubicTo(9, 12, 9, 24, 15, 34)
    ..cubicTo(20, 41, 34, 40, 41, 32)
    ..cubicTo(45, 24, 40, 12, 30, 7)
    ..cubicTo(24, 4, 19, 3, 15, 5)
    ..close();
  final right = Path()
    ..moveTo(109, 5)
    ..cubicTo(115, 12, 115, 24, 109, 34)
    ..cubicTo(104, 41, 90, 40, 83, 32)
    ..cubicTo(79, 24, 84, 12, 94, 7)
    ..cubicTo(100, 4, 105, 3, 109, 5)
    ..close();
  final paths = <Path>[left];
  if (ears != 1) paths.add(right);
  if (ears == 3) {
    paths.add(
      Path()
        ..moveTo(15, 5)
        ..lineTo(7, 0)
        ..lineTo(18, 9)
        ..close(),
    );
    if (ears != 1) {
      paths.add(
        Path()
          ..moveTo(109, 5)
          ..lineTo(117, 0)
          ..lineTo(106, 9)
          ..close(),
      );
    }
  }
  return paths;
}

/// Inner-ear details, drawn in pink on top of the fur silhouette.
List<Path> _earInnerPaths(int ears) {
  if (ears == 2) {
    return [
      Path()..addOval(Rect.fromCenter(center: const Offset(26, 30), width: 20, height: 10)),
      Path()..addOval(Rect.fromCenter(center: const Offset(98, 30), width: 20, height: 10)),
    ];
  }
  final left = Path()
    ..moveTo(19, 11)
    ..cubicTo(15, 16, 15, 24, 19, 29)
    ..cubicTo(24, 34, 32, 33, 36, 27)
    ..cubicTo(38, 20, 33, 12, 27, 9)
    ..cubicTo(24, 8, 21, 9, 19, 11)
    ..close();
  final right = Path()
    ..moveTo(105, 11)
    ..cubicTo(109, 16, 109, 24, 105, 29)
    ..cubicTo(100, 34, 92, 33, 88, 27)
    ..cubicTo(86, 20, 91, 12, 97, 9)
    ..cubicTo(100, 8, 103, 9, 105, 11)
    ..close();
  final paths = <Path>[left];
  if (ears != 1) paths.add(right);
  return paths;
}

/// Clip region for head patterns: the head plus every ear silhouette, so
/// markings (colourpoint ears, calico patches) can cover the ears too.
Path _headClipPath(int ears) {
  final clip = _headPath();
  for (final ear in _earOuterPaths(ears)) {
    clip.addPath(ear, Offset.zero);
  }
  return clip;
}

/// Marking colour for tabby/bicolour details: dark furs get light marks.
Color _markingColor(Color fur) => fur.computeLuminance() < 0.32
    ? const Color(0xffecdcbd).withValues(alpha: 0.9)
    : ink.withValues(alpha: 0.5);

void _scaleTo(Canvas canvas, Size size, double w, double h) {
  canvas.save();
  canvas.scale(size.width / w, size.height / h);
}

// ---------------------------------------------------------------------------
// Head layers (120×120)
// ---------------------------------------------------------------------------

class _EarPainter extends CustomPainter {
  const _EarPainter(this.fur, this.ears);
  final Color fur;
  final int ears;

  @override
  void paint(Canvas canvas, Size size) {
    _scaleTo(canvas, size, 120, 120);
    final furPaint = Paint()..color = fur;
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final path in _earOuterPaths(ears)) {
      canvas.drawPath(path, furPaint);
      canvas.drawPath(path, line);
    }
    final inner = Paint()..color = const Color(0xffeca7ad);
    for (final path in _earInnerPaths(ears)) {
      canvas.drawPath(path, inner);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EarPainter oldDelegate) =>
      oldDelegate.fur != fur || oldDelegate.ears != ears;
}

class _HeadBasePainter extends CustomPainter {
  const _HeadBasePainter(this.fur);
  final Color fur;

  @override
  void paint(Canvas canvas, Size size) {
    _scaleTo(canvas, size, 120, 120);
    final head = _headPath();
    canvas.drawPath(head, Paint()..color = fur);
    canvas.drawPath(
      head,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeadBasePainter oldDelegate) => oldDelegate.fur != fur;
}

class _HeadPatternPainter extends CustomPainter {
  const _HeadPatternPainter(this.spec);
  final CatSpec spec;

  @override
  void paint(Canvas canvas, Size size) {
    if (spec.pattern == 0) return;
    _scaleTo(canvas, size, 120, 120);
    canvas.save();
    canvas.clipPath(_headClipPath(spec.ears));
    switch (spec.pattern) {
      case 1:
        _tabby(canvas, spec.fur);
      case 2:
        _bicolour(canvas);
      case 3:
        _calico(canvas);
      case 4:
        _colourpoint(canvas);
    }
    canvas.restore();
    canvas.restore();
  }

  void _tabby(Canvas canvas, Color fur) {
    final stroke = Paint()
      ..color = _markingColor(fur)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    for (final x in [46.0, 62.0, 78.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(x - 4, 29)
          ..quadraticBezierTo(x + 4, 36, x - 3, 45),
        stroke,
      );
    }
    for (final (x1, y1, x2, y2) in [
      (22.0, 55.0, 31.0, 63.0),
      (17.0, 67.0, 27.0, 73.0),
      (98.0, 55.0, 89.0, 63.0),
      (103.0, 67.0, 93.0, 73.0),
    ]) {
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), stroke);
    }
  }

  void _bicolour(Canvas canvas) {
    final p = Paint()..color = const Color(0xfffff6e6);
    canvas.drawOval(Rect.fromLTWH(52, 19, 20, 17), p);
    canvas.drawOval(Rect.fromLTWH(35, 71, 52, 41), p);
    canvas.drawOval(Rect.fromLTWH(11, 77, 19, 27), p);
    canvas.drawOval(Rect.fromLTWH(90, 77, 19, 27), p);
  }

  void _calico(Canvas canvas) {
    canvas.drawOval(
      Rect.fromLTWH(74, 28, 36, 32),
      Paint()..color = const Color(0xff454b5c),
    );
    canvas.drawOval(
      Rect.fromLTWH(15, 56, 32, 27),
      Paint()..color = const Color(0xffe8973f),
    );
    canvas.drawOval(
      Rect.fromLTWH(58, 82, 22, 18),
      Paint()..color = const Color(0xff454b5c),
    );
    canvas.drawOval(
      Rect.fromLTWH(20, 30, 15, 13),
      Paint()..color = const Color(0xffe8973f),
    );
  }

  void _colourpoint(Canvas canvas) {
    final point = Paint()
      ..color = const Color(0xff54402f).withValues(alpha: 0.7);
    for (final ear in _earOuterPaths(spec.ears)) {
      canvas.drawPath(ear, point);
    }
    canvas.drawOval(
      Rect.fromLTWH(29, 43, 68, 42),
      Paint()..color = const Color(0xff54402f).withValues(alpha: 0.32),
    );
  }

  @override
  bool shouldRepaint(_HeadPatternPainter oldDelegate) =>
      oldDelegate.spec != spec;
}

class _MuzzlePainter extends CustomPainter {
  const _MuzzlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    _scaleTo(canvas, size, 120, 120);
    final p = Paint()..color = const Color(0xffffeddd);
    canvas.drawOval(const Rect.fromLTWH(34, 78, 54, 30), p);
    p.color = const Color(0xffe78e9c);
    canvas.drawPath(
      Path()
        ..moveTo(51, 83)
        ..lineTo(68, 83)
        ..lineTo(60, 91)
        ..close(),
      p,
    );
    final mouth = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final x in [42.0, 60.0]) {
      canvas.drawArc(
        Rect.fromLTWH(x, 86, 18, 13),
        0,
        pi,
        false,
        mouth,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MuzzlePainter oldDelegate) => false;
}

class _EyePainter extends CustomPainter {
  const _EyePainter(this.colour);
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    _scaleTo(canvas, size, 120, 120);
    for (final x in [35.0, 81.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 65), width: 25, height: 30),
        Paint()..color = colour,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x + 2, 66), width: 12, height: 24),
        Paint()..color = const Color(0xff171b25),
      );
      canvas.drawCircle(
        Offset(x + 5, 58),
        4,
        Paint()..color = Colors.white,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EyePainter oldDelegate) => oldDelegate.colour != colour;
}

// ---------------------------------------------------------------------------
// Body layers (240×310)
// ---------------------------------------------------------------------------

class _BodyBasePainter extends CustomPainter {
  const _BodyBasePainter(this.fur);
  final Color fur;

  @override
  void paint(Canvas canvas, Size size) {
    _scaleTo(canvas, size, 240, 310);
    final tail = _tailPath();
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
    final body = _bodyPath();
    canvas.drawPath(body, Paint()..color = fur);
    canvas.drawPath(
      body,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawOval(
      const Rect.fromLTWH(111, 130, 62, 124),
      Paint()..color = const Color(0xffffeddd),
    );
    for (final x in [102.0, 153.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 222, 30, 60),
          const Radius.circular(12),
        ),
        Paint()..color = fur,
      );
      canvas.drawOval(
        Rect.fromLTWH(x - 4, 263, 39, 20),
        Paint()..color = const Color(0xffffeddd),
      );
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
  bool shouldRepaint(_BodyBasePainter oldDelegate) => oldDelegate.fur != fur;
}

class _BodyPatternPainter extends CustomPainter {
  const _BodyPatternPainter(this.spec);
  final CatSpec spec;

  @override
  void paint(Canvas canvas, Size size) {
    if (spec.pattern == 0) return;
    _scaleTo(canvas, size, 240, 310);
    if (spec.pattern == 4) {
      _colourpoint(canvas);
    } else {
      canvas.save();
      canvas.clipPath(_bodyPath());
      switch (spec.pattern) {
        case 1:
          _tabby(canvas, spec.fur);
        case 2:
          _bicolour(canvas);
        case 3:
          _calico(canvas);
      }
      canvas.restore();
    }
    canvas.restore();
  }

  void _tabby(Canvas canvas, Color fur) {
    final p = Paint()..color = _markingColor(fur);
    for (var i = 0; i < 4; i++) {
      canvas.drawOval(Rect.fromLTWH(71 - i * 3, 160 + i * 24, 32, 9), p);
    }
    canvas.drawOval(Rect.fromLTWH(52, 132, 26, 8), p);
    canvas.drawOval(Rect.fromLTWH(160, 132, 26, 8), p);
  }

  void _bicolour(Canvas canvas) {
    final p = Paint()..color = const Color(0xfffff6e6);
    canvas.drawOval(Rect.fromLTWH(122, 118, 84, 46), p);
    canvas.drawOval(Rect.fromLTWH(104, 168, 100, 122), p);
  }

  void _calico(Canvas canvas) {
    canvas.drawOval(
      Rect.fromLTWH(140, 226, 66, 56),
      Paint()..color = const Color(0xffe8973f),
    );
    canvas.drawOval(
      Rect.fromLTWH(58, 168, 60, 44),
      Paint()..color = const Color(0xff454b5c),
    );
    canvas.drawOval(
      Rect.fromLTWH(120, 236, 40, 30),
      Paint()..color = const Color(0xff454b5c),
    );
  }

  void _colourpoint(Canvas canvas) {
    final point = Paint()
      ..color = const Color(0xff54402f)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(_tailPath(), point);
    final paw = Paint()..color = const Color(0xff54402f);
    for (final x in [98.0, 149.0]) {
      canvas.drawOval(Rect.fromLTWH(x - 2, 256, 35, 22), paw);
    }
  }

  @override
  bool shouldRepaint(_BodyPatternPainter oldDelegate) =>
      oldDelegate.spec != spec;
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

/// Renders a [CatSpec] from its independent layers. Set [onlyLayers] to
/// render a subset (used by tests and previews); set [showAccessory] false
/// to hide the sprite overlay.
class CatSpecAvatar extends StatelessWidget {
  const CatSpecAvatar(
    this.spec, {
    super.key,
    this.size = 120,
    this.showAccessory = true,
    this.onlyLayers,
  });
  final CatSpec spec;
  final double size;
  final bool showAccessory;
  final Set<CatLayerKind>? onlyLayers;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: CatLayersPainter(spec, onlyLayers: onlyLayers),
        ),
        if (showAccessory && spec.accessory.isNotEmpty)
          Align(
            alignment: Alignment.topCenter,
            child: sprite(spec.accessory, size: size * .7),
          ),
      ],
    ),
  );
}

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
          CatSpecAvatar(
            catSpecForPlayer(player),
            size: size,
            showAccessory: false,
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
            painter: CatLayersPainter(catSpecForPlayer(player), body: true),
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

/// Legacy single-painter cat face kept for source compatibility. New code
/// should use [CatSpecAvatar] or [CatLayersPainter]; this simply routes the
/// old `(fur, ears, eye, pattern)` arguments through the layer system.
class CatPainter extends CustomPainter {
  CatPainter(this.fur, this.ears, this.eye, this.pattern);
  final Color fur, eye;
  final int ears, pattern;
  @override
  void paint(Canvas canvas, Size size) {
    CatLayersPainter(
      CatSpec(
        fur: fur,
        pattern: _clampIndex(pattern, catPatternCount),
        eyes: eye,
        ears: _clampIndex(ears, catEarCount),
      ),
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(CatPainter old) =>
      old.fur != fur ||
      old.ears != ears ||
      old.eye != eye ||
      old.pattern != pattern;
}
