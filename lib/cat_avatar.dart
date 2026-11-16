import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catalog.dart';
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

/// Paints one of the five fur patterns inside the current clip. Shared by
/// the cat head/body layers and the user-avatar painter; [earPaths] are the
/// outer ear silhouettes used by colourpoint so ears tint with the face.
void _paintHeadPattern(
  Canvas canvas, {
  required Color fur,
  required int pattern,
  required List<Path> earPaths,
}) {
  switch (pattern) {
    case 1:
      _tabbyMarks(canvas, fur);
    case 2:
      _bicolourMarks(canvas);
    case 3:
      _calicoMarks(canvas);
    case 4:
      _colourpointMarks(canvas, earPaths);
  }
}

void _tabbyMarks(Canvas canvas, Color fur) {
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

void _bicolourMarks(Canvas canvas) {
  final p = Paint()..color = const Color(0xfffff6e6);
  canvas.drawOval(Rect.fromLTWH(52, 19, 20, 17), p);
  canvas.drawOval(Rect.fromLTWH(35, 71, 52, 41), p);
  canvas.drawOval(Rect.fromLTWH(11, 77, 19, 27), p);
  canvas.drawOval(Rect.fromLTWH(90, 77, 19, 27), p);
}

void _calicoMarks(Canvas canvas) {
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

void _colourpointMarks(Canvas canvas, List<Path> earPaths) {
  final point = Paint()
    ..color = const Color(0xff54402f).withValues(alpha: 0.7);
  for (final ear in earPaths) {
    canvas.drawPath(ear, point);
  }
  canvas.drawOval(
    Rect.fromLTWH(29, 43, 68, 42),
    Paint()..color = const Color(0xff54402f).withValues(alpha: 0.32),
  );
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
    _paintHeadPattern(
      canvas,
      fur: spec.fur,
      pattern: spec.pattern,
      earPaths: _earOuterPaths(spec.ears),
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeadPatternPainter oldDelegate) =>
      oldDelegate.spec != spec;
}

/// The cat muzzle: cream oval, pink nose and mouth arcs. Shared with the
/// avatar painter when the species is a cat.
void _paintCatMuzzle(Canvas canvas) {
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
}

class _MuzzlePainter extends CustomPainter {
  const _MuzzlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    _scaleTo(canvas, size, 120, 120);
    _paintCatMuzzle(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MuzzlePainter oldDelegate) => false;
}

/// The pair of irises, pupils and highlights at the canonical eye spots.
/// Shared by the cat layers and the user-avatar painter.
void _paintEyes(Canvas canvas, Color colour) {
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
}

class _EyePainter extends CustomPainter {
  const _EyePainter(this.colour);
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    _scaleTo(canvas, size, 120, 120);
    _paintEyes(canvas, colour);
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

// ---------------------------------------------------------------------------
// User avatar — a separate creature from the duel cats (Tzuki/Bubble/Custom).
// Rendered by the same layer idea: species silhouette + fur + pattern +
// muzzle + eyes + accessory sprite. No photo, no network, no cost.
// ---------------------------------------------------------------------------

/// Number of avatar species: 0 pisică, 1 câine, 2 iepure, 3 urs.
const avatarSpeciesCount = 4;

/// Romanian species labels for the editor, indexed by [AvatarSpec.species].
const avatarSpeciesNames = ['Pisică', 'Câine', 'Iepure', 'Urs'];

/// Ear-style labels per species, indexed `[species][ears]`. Index 1 always
/// means "only the left ear" across every species.
const avatarEarNames = [
  ['Două urechi', 'Doar stânga', 'Plisate', 'Smocuri'],
  ['Flori', 'O floare', 'Drepte', 'Lungi'],
  ['Drepte', 'O dreaptă', 'Plecate', 'Amestec'],
  ['Mari', 'O ureche', 'Mici', 'Înalte'],
];

/// Shared-preferences key for the locally stored avatar spec JSON.
const avatarSpecKey = 'avatar_spec_v1';

/// Visual description of the player's avatar. Every field is a small index
/// or an accessory sprite id so the whole spec serializes to a compact JSON
/// object that `Player`/`CloudProfile` can persist later.
class AvatarSpec {
  const AvatarSpec({
    this.species = 0,
    this.fur = 0,
    this.pattern = 0,
    this.eyes = 0,
    this.ears = 0,
    this.accessory = '',
  });

  /// Species index in `0..[avatarSpeciesCount)`.
  final int species;

  /// Fur palette index into [catFurColours].
  final int fur;

  /// Pattern index in `0..[catPatternCount)` (same set as the cats).
  final int pattern;

  /// Iris palette index into [catEyeColours].
  final int eyes;

  /// Ear style index in `0..[catEarCount)`; meaning depends on [species].
  final int ears;

  /// Accessory sprite id from `assets/generated/` ('' = none). Only ids from
  /// [accessories] are accepted so a bad save can never request a missing
  /// asset.
  final String accessory;

  Color get furColor => catFurColours[_clampIndex(fur, catFurColours.length)];
  Color get eyeColor => catEyeColours[_clampIndex(eyes, catEyeColours.length)];

  AvatarSpec copyWith({
    int? species,
    int? fur,
    int? pattern,
    int? eyes,
    int? ears,
    String? accessory,
  }) => AvatarSpec(
    species: species ?? this.species,
    fur: fur ?? this.fur,
    pattern: pattern ?? this.pattern,
    eyes: eyes ?? this.eyes,
    ears: ears ?? this.ears,
    accessory: accessory ?? this.accessory,
  );

  /// Compact JSON form proposed for `Player.avatar`/`CloudProfile.avatar`.
  Map<String, Object?> toJson() => {
    's': _clampIndex(species, avatarSpeciesCount),
    'f': _clampIndex(fur, catFurColours.length),
    'p': _clampIndex(pattern, catPatternCount),
    'e': _clampIndex(eyes, catEyeColours.length),
    'r': _clampIndex(ears, catEarCount),
    'a': accessories.contains(accessory) ? accessory : '',
  };

  String toJsonString() => jsonEncode(toJson());

  /// Tolerant parse for local/cloud data: bad or out-of-range values fall
  /// back to defaults instead of throwing, so a corrupt save cannot brick
  /// the avatar. Unknown accessory ids are dropped.
  factory AvatarSpec.fromJson(Map<String, Object?> json) {
    int pick(String key, int fallback, int count) {
      final v = json[key];
      return v is int && v >= 0 && v < count ? v : fallback;
    }

    final a = json['a'];
    return AvatarSpec(
      species: pick('s', 0, avatarSpeciesCount),
      fur: pick('f', 0, catFurColours.length),
      pattern: pick('p', 0, catPatternCount),
      eyes: pick('e', 0, catEyeColours.length),
      ears: pick('r', 0, catEarCount),
      accessory: a is String && accessories.contains(a) ? a : '',
    );
  }

  factory AvatarSpec.fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return const AvatarSpec();
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, Object?>
          ? AvatarSpec.fromJson(decoded)
          : const AvatarSpec();
    } on FormatException {
      return const AvatarSpec();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is AvatarSpec &&
      other.species == species &&
      other.fur == fur &&
      other.pattern == pattern &&
      other.eyes == eyes &&
      other.ears == ears &&
      other.accessory == accessory;

  @override
  int get hashCode => Object.hash(species, fur, pattern, eyes, ears, accessory);
}

/// Loads the locally stored avatar spec; a missing or corrupt value yields
/// the default spec. This is lane-3 local persistence until the orchestrator
/// adds `Player.avatar`/`CloudProfile.avatar` (see docs/requests.md).
AvatarSpec loadAvatarSpec(SharedPreferences prefs) =>
    AvatarSpec.fromJsonString(prefs.getString(avatarSpecKey));

Future<void> saveAvatarSpec(SharedPreferences prefs, AvatarSpec spec) =>
    prefs.setString(avatarSpecKey, spec.toJsonString());

// --- species geometry (canonical 120x120 head space, like the cats) ---------

Path _avatarHeadPath(int species) => switch (species) {
  // Dog: wider cheeks and jowls.
  1 => Path()
    ..moveTo(62, 18)
    ..cubicTo(30, 18, 9, 45, 8, 75)
    ..cubicTo(7, 107, 32, 125, 62, 125)
    ..cubicTo(93, 125, 117, 105, 116, 73)
    ..cubicTo(115, 43, 93, 18, 62, 18)
    ..close(),
  // Bunny: narrower, taller head.
  2 => Path()
    ..moveTo(62, 13)
    ..cubicTo(37, 13, 17, 41, 16, 71)
    ..cubicTo(15, 101, 36, 119, 62, 119)
    ..cubicTo(89, 119, 107, 99, 106, 69)
    ..cubicTo(105, 39, 86, 13, 62, 13)
    ..close(),
  // Bear: the roundest, widest head.
  3 => Path()
    ..moveTo(62, 21)
    ..cubicTo(27, 21, 7, 47, 7, 77)
    ..cubicTo(7, 109, 32, 127, 62, 127)
    ..cubicTo(95, 127, 119, 107, 119, 75)
    ..cubicTo(119, 45, 95, 21, 62, 21)
    ..close(),
  // Cat and anything unexpected: the classic cat head.
  _ => _headPath(),
};

/// Ear stamps for species 1-3 in canonical space: each stamp is
/// `[cx, cy, w, h]` for an oval ear. Left stamp first; a style-1 spec has a
/// single left ear. Species 0 uses the cat's path ears instead.
List<List<double>> _avatarEarStamps(int species, int ears) {
  if (ears == 1) {
    return switch (species) {
      1 => [
        [23.0, 47.0, 22.0, 54.0],
      ],
      2 => [
        [31.0, 34.0, 17.0, 54.0],
      ],
      3 => [
        [26.0, 25.0, 26.0, 26.0],
      ],
      _ => const [],
    };
  }
  return switch ((species, ears)) {
    // Dog: floppy, perked, long floppy.
    (1, 0) => [
      [23.0, 47.0, 22.0, 54.0],
      [97.0, 47.0, 22.0, 54.0],
    ],
    (1, 2) => [
      [27.0, 30.0, 20.0, 32.0],
      [93.0, 30.0, 20.0, 32.0],
    ],
    (1, 3) => [
      [21.0, 50.0, 19.0, 62.0],
      [99.0, 50.0, 19.0, 62.0],
    ],
    // Bunny: upright, lop, mixed (left upright, right lop).
    (2, 0) => [
      [31.0, 34.0, 17.0, 54.0],
      [89.0, 34.0, 17.0, 54.0],
    ],
    (2, 2) => [
      [24.0, 46.0, 24.0, 32.0],
      [96.0, 46.0, 24.0, 32.0],
    ],
    (2, 3) => [
      [31.0, 34.0, 17.0, 54.0],
      [97.0, 46.0, 24.0, 32.0],
    ],
    // Bear: big round, small round, tall oval.
    (3, 0) => [
      [26.0, 25.0, 26.0, 26.0],
      [94.0, 25.0, 26.0, 26.0],
    ],
    (3, 2) => [
      [26.0, 26.0, 18.0, 18.0],
      [94.0, 26.0, 18.0, 18.0],
    ],
    (3, 3) => [
      [26.0, 23.0, 20.0, 34.0],
      [94.0, 23.0, 20.0, 34.0],
    ],
    _ => const [],
  };
}

/// Oval paths approximating the ear stamps, used for pattern clipping and
/// colourpoint tinting.
List<Path> _avatarEarPaths(int species, int ears) => [
  for (final s in _avatarEarStamps(species, ears))
    Path()..addOval(Rect.fromCenter(center: Offset(s[0], s[1]), width: s[2], height: s[3])),
];

Path _avatarClipPath(int species, int ears) {
  final clip = _avatarHeadPath(species);
  if (species == 0) {
    for (final ear in _earOuterPaths(ears)) {
      clip.addPath(ear, Offset.zero);
    }
  } else {
    for (final ear in _avatarEarPaths(species, ears)) {
      clip.addPath(ear, Offset.zero);
    }
  }
  return clip;
}

void _paintAnimalEars(Canvas canvas, int species, int ears, Color fur) {
  final stamps = _avatarEarStamps(species, ears);
  if (stamps.isEmpty) return;
  final furPaint = Paint()..color = fur;
  final line = Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  final inner = Paint()..color = const Color(0xffeca7ad);
  for (final s in stamps) {
    final outer = Rect.fromCenter(
      center: Offset(s[0], s[1]),
      width: s[2],
      height: s[3],
    );
    canvas.drawOval(outer, furPaint);
    canvas.drawOval(outer, line);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s[0], s[1] + s[3] * 0.08),
        width: s[2] * 0.55,
        height: s[3] * 0.62,
      ),
      inner,
    );
  }
}

/// Species-specific muzzles/snouts in canonical space.
void _paintAnimalMuzzle(Canvas canvas, int species) {
  switch (species) {
    case 1:
      // Dog: broad cream muzzle, large dark nose, happy mouth.
      canvas.drawOval(
        const Rect.fromLTWH(36, 74, 52, 36),
        Paint()..color = const Color(0xffffeddd),
      );
      canvas.drawOval(
        const Rect.fromLTWH(50, 78, 22, 14),
        Paint()..color = const Color(0xff4a3b2f),
      );
      canvas.drawPath(
        Path()
          ..moveTo(48, 100)
          ..quadraticBezierTo(62, 108, 76, 100),
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    case 2:
      // Bunny: small muzzle, tiny nose, two buck teeth.
      canvas.drawOval(
        const Rect.fromLTWH(44, 78, 36, 26),
        Paint()..color = const Color(0xffffeddd),
      );
      canvas.drawOval(
        const Rect.fromLTWH(56, 80, 10, 8),
        Paint()..color = const Color(0xffe78e9c),
      );
      for (final x in [52.0, 62.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 94, 8, 11),
            const Radius.circular(3),
          ),
          Paint()..color = Colors.white,
        );
      }
      canvas.drawLine(
        const Offset(58, 94),
        const Offset(58, 105),
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    case 3:
      // Bear: wide muzzle, big round nose.
      canvas.drawOval(
        const Rect.fromLTWH(28, 74, 68, 34),
        Paint()..color = const Color(0xffffeddd),
      );
      canvas.drawOval(
        const Rect.fromLTWH(46, 76, 30, 18),
        Paint()..color = const Color(0xff4a3b2f),
      );
      canvas.drawPath(
        Path()
          ..moveTo(50, 102)
          ..quadraticBezierTo(62, 108, 74, 102),
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
  }
}

/// Paints an [AvatarSpec] in the canonical 120x120 space. Species 0 is a
/// cat and delegates to the cat layer stack so it looks identical to the
/// duel cats; species 1-3 draw their own ears, head, muzzle and eyes.
class AvatarPainter extends CustomPainter {
  const AvatarPainter(this.spec);
  final AvatarSpec spec;

  @override
  void paint(Canvas canvas, Size size) {
    final species = _clampIndex(spec.species, avatarSpeciesCount);
    if (species == 0) {
      CatLayersPainter(
        CatSpec(
          fur: spec.furColor,
          pattern: _clampIndex(spec.pattern, catPatternCount),
          eyes: spec.eyeColor,
          ears: _clampIndex(spec.ears, catEarCount),
        ),
      ).paint(canvas, size);
      return;
    }
    _scaleTo(canvas, size, 120, 120);
    final fur = spec.furColor;
    _paintAnimalEars(canvas, species, spec.ears, fur);
    final head = _avatarHeadPath(species);
    canvas.drawPath(head, Paint()..color = fur);
    canvas.drawPath(
      head,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    final pattern = _clampIndex(spec.pattern, catPatternCount);
    if (pattern != 0) {
      canvas.save();
      canvas.clipPath(_avatarClipPath(species, spec.ears));
      _paintHeadPattern(
        canvas,
        fur: fur,
        pattern: pattern,
        earPaths: _avatarEarPaths(species, spec.ears),
      );
      canvas.restore();
    }
    _paintAnimalMuzzle(canvas, species);
    _paintEyes(canvas, spec.eyeColor);
    canvas.restore();
  }

  @override
  bool shouldRepaint(AvatarPainter oldDelegate) => oldDelegate.spec != spec;
}

/// Renders an [AvatarSpec] avatar. Set [showAccessory] false to hide the
/// sprite overlay (used where the accessory is drawn separately).
class AvatarAvatar extends StatelessWidget {
  const AvatarAvatar(
    this.spec, {
    super.key,
    this.size = 64,
    this.showAccessory = true,
  });
  final AvatarSpec spec;
  final double size;
  final bool showAccessory;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: AvatarPainter(spec)),
        if (showAccessory && spec.accessory.isNotEmpty)
          Align(
            alignment: Alignment.topCenter,
            child: sprite(spec.accessory, size: size * .7),
          ),
      ],
    ),
  );
}
