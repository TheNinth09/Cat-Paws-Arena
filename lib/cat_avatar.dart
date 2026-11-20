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

int _clampIndex(int value, int length) => value < 0
    ? 0
    : value >= length
    ? length - 1
    : value;

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
      Path()..addOval(
        Rect.fromCenter(center: const Offset(27, 31), width: 36, height: 18),
      ),
      Path()..addOval(
        Rect.fromCenter(center: const Offset(97, 31), width: 36, height: 18),
      ),
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
      Path()..addOval(
        Rect.fromCenter(center: const Offset(26, 30), width: 20, height: 10),
      ),
      Path()..addOval(
        Rect.fromCenter(center: const Offset(98, 30), width: 20, height: 10),
      ),
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
  final point = Paint()..color = const Color(0xff54402f).withValues(alpha: 0.7);
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
/// avatar painter — the avatar is always a cat.
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
    canvas.drawArc(Rect.fromLTWH(x, 86, 18, 13), 0, pi, false, mouth);
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
    canvas.drawCircle(Offset(x + 5, 58), 4, Paint()..color = Colors.white);
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

// ---------------------------------------------------------------------------
// Procedural accessories — drawn in the cat's canonical 120×120 head space so
// they sit exactly on the face. [centered] repositions the shape for
// standalone display (shop cards, pickers) where there is no head behind it.
// ---------------------------------------------------------------------------

class _GlassesPainter extends CustomPainter {
  const _GlassesPainter({this.centered = false});
  final bool centered;

  @override
  void paint(Canvas canvas, Size size) {
    _scaleTo(canvas, size, 120, 120);
    // The eyes sit at y≈65 — near-centred already for standalone cards.
    const dy = 0.0;
    final rim = Paint()
      ..color = const Color(0xff2b2620)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    final lens = Paint()..color = const Color(0x30ffffff);
    for (final x in [35.0, 81.0]) {
      final r = Rect.fromCircle(center: Offset(x, 65 + dy), radius: 16);
      canvas.drawOval(r, lens);
      canvas.drawOval(r, rim);
    }
    canvas.drawLine(Offset(51, 61 + dy), Offset(65, 61 + dy), rim);
    canvas.drawLine(Offset(19, 62 + dy), Offset(9, 54 + dy), rim);
    canvas.drawLine(Offset(97, 62 + dy), Offset(107, 54 + dy), rim);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassesPainter old) => old.centered != centered;
}

class _BowtiePainter extends CustomPainter {
  const _BowtiePainter({this.centered = false});
  final bool centered;

  @override
  void paint(Canvas canvas, Size size) {
    _scaleTo(canvas, size, 120, 120);
    final cy = centered ? 60.0 : 106.0;
    final cloth = Paint()..color = const Color(0xffd84343);
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (final dir in [-1.0, 1.0]) {
      final wing = Path()
        ..moveTo(62 + 6 * dir, cy - 7)
        ..lineTo(62 + 28 * dir, cy - 16)
        ..lineTo(62 + 28 * dir, cy + 12)
        ..lineTo(62 + 6 * dir, cy + 7)
        ..close();
      canvas.drawPath(wing, cloth);
      canvas.drawPath(wing, line);
    }
    final knot = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(62, cy), width: 15, height: 15),
      const Radius.circular(4),
    );
    canvas.drawRRect(knot, cloth);
    canvas.drawRRect(knot, line);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BowtiePainter old) => old.centered != centered;
}

class _FlowerPainter extends CustomPainter {
  const _FlowerPainter({this.centered = false});
  final bool centered;

  @override
  void paint(Canvas canvas, Size size) {
    _scaleTo(canvas, size, 120, 120);
    final c = centered ? const Offset(60, 60) : const Offset(24, 14);
    final petal = Paint()..color = const Color(0xfff7f3ea);
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < 6; i++) {
      final a = i * pi / 3;
      final p = Offset(c.dx + 9 * cos(a), c.dy + 9 * sin(a));
      canvas.drawCircle(p, 7, petal);
      canvas.drawCircle(p, 7, line);
    }
    final heart = Paint()..color = gold;
    canvas.drawCircle(c, 6, heart);
    canvas.drawCircle(c, 6, line);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FlowerPainter old) => old.centered != centered;
}

/// Golden bell collar — trophy-road reward for reaching the Main Hall.
class _CollarPainter extends CustomPainter {
  const _CollarPainter({this.centered = false});
  final bool centered;

  @override
  void paint(Canvas canvas, Size size) {
    _scaleTo(canvas, size, 120, 120);
    final cy = centered ? 52.0 : 104.0;
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final band = Paint()..color = const Color(0xffc63b3b);
    final bandPath = Path()
      ..moveTo(28, cy - 4)
      ..quadraticBezierTo(60, cy + 12, 92, cy - 4)
      ..lineTo(92, cy + 5)
      ..quadraticBezierTo(60, cy + 21, 28, cy + 5)
      ..close();
    canvas.drawPath(bandPath, band);
    canvas.drawPath(bandPath, line);
    final bell = Rect.fromCircle(center: Offset(60, cy + 12), radius: 7);
    canvas.drawOval(bell, Paint()..color = gold);
    canvas.drawOval(bell, line);
    canvas.drawLine(
      Offset(56, cy + 12),
      Offset(64, cy + 12),
      Paint()
        ..color = ink
        ..strokeWidth = 1.6,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CollarPainter old) => old.centered != centered;
}

/// Chef's bib tied under the chin — Kitchen reward.
class _BibPainter extends CustomPainter {
  const _BibPainter({this.centered = false});
  final bool centered;

  @override
  void paint(Canvas canvas, Size size) {
    _scaleTo(canvas, size, 120, 120);
    final cy = centered ? 44.0 : 96.0;
    final cloth = Paint()..color = const Color(0xfffdf6e3);
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final bib = Path()
      ..moveTo(42, cy)
      ..quadraticBezierTo(60, cy + 8, 78, cy)
      ..lineTo(88, cy + 22)
      ..quadraticBezierTo(60, cy + 30, 32, cy + 22)
      ..close();
    canvas.drawPath(bib, cloth);
    canvas.drawPath(bib, line);
    final pocket = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(60, cy + 17), width: 22, height: 9),
      const Radius.circular(3),
    );
    canvas.drawRRect(
      pocket,
      Paint()..color = const Color(0xfff0e0c0),
    );
    canvas.drawRRect(pocket, line);
    for (final dir in [-1.0, 1.0]) {
      canvas.drawCircle(
        Offset(42 - 4 * dir, cy - 1),
        3,
        cloth,
      );
      canvas.drawCircle(Offset(42 - 4 * dir, cy - 1), 3, line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BibPainter old) => old.centered != centered;
}

/// Floppy nightcap with a pom — Bedroom reward.
class _NightcapPainter extends CustomPainter {
  const _NightcapPainter({this.centered = false});
  final bool centered;

  @override
  void paint(Canvas canvas, Size size) {
    _scaleTo(canvas, size, 120, 120);
    final cy = centered ? 52.0 : 8.0;
    final cloth = Paint()..color = const Color(0xff5b6bc0);
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    final cap = Path()
      ..moveTo(30, cy + 16)
      ..quadraticBezierTo(34, cy - 14, 62, cy - 10)
      ..quadraticBezierTo(88, cy - 8, 92, cy + 10)
      ..quadraticBezierTo(98, cy - 4, 104, cy + 12)
      ..lineTo(92, cy + 16);
    canvas.drawPath(cap, cloth);
    canvas.drawPath(cap, line);
    final brim = Path()
      ..moveTo(26, cy + 14)
      ..quadraticBezierTo(60, cy + 26, 94, cy + 14)
      ..lineTo(94, cy + 24)
      ..quadraticBezierTo(60, cy + 36, 26, cy + 24)
      ..close();
    canvas.drawPath(brim, Paint()..color = const Color(0xfffdf6e3));
    canvas.drawPath(brim, line);
    final pom = Paint()..color = const Color(0xfffdf6e3);
    canvas.drawCircle(Offset(104, cy + 13), 6.5, pom);
    canvas.drawCircle(Offset(104, cy + 13), 6.5, line);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NightcapPainter old) => old.centered != centered;
}

/// Three-pointed jester hat with bells — Playroom reward.
class _JesterPainter extends CustomPainter {
  const _JesterPainter({this.centered = false});
  final bool centered;

  @override
  void paint(Canvas canvas, Size size) {
    _scaleTo(canvas, size, 120, 120);
    final cy = centered ? 46.0 : 4.0;
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final red = Paint()..color = const Color(0xffd84343);
    final green = Paint()..color = const Color(0xff4e9c22);
    // Band across the head.
    final band = Path()
      ..moveTo(24, cy + 18)
      ..quadraticBezierTo(60, cy + 30, 96, cy + 18)
      ..lineTo(96, cy + 26)
      ..quadraticBezierTo(60, cy + 38, 24, cy + 26)
      ..close();
    canvas.drawPath(band, red);
    canvas.drawPath(band, line);
    // Three floppy points alternating colours, each ending in a bell.
    for (var i = 0; i < 3; i++) {
      final x0 = 30.0 + i * 26;
      final tip = Offset(x0 + 12, cy - 14 - (i == 1 ? 8 : 0));
      final point = Path()
        ..moveTo(x0, cy + 20)
        ..quadraticBezierTo(x0 + 4, cy, tip.dx, tip.dy)
        ..quadraticBezierTo(x0 + 22, cy + 4, x0 + 26, cy + 20)
        ..close();
      canvas.drawPath(point, i == 1 ? red : green);
      canvas.drawPath(point, line);
      canvas.drawCircle(tip, 4.5, Paint()..color = gold);
      canvas.drawCircle(tip, 4.5, line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_JesterPainter old) => old.centered != centered;
}

/// Knitted winter scarf with a hanging tail — Winter Garden reward.
class _ScarfPainter extends CustomPainter {
  const _ScarfPainter({this.centered = false});
  final bool centered;

  @override
  void paint(Canvas canvas, Size size) {
    _scaleTo(canvas, size, 120, 120);
    final cy = centered ? 52.0 : 103.0;
    final wool = Paint()..color = const Color(0xff3f6fb5);
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final wrap = Path()
      ..moveTo(24, cy - 3)
      ..quadraticBezierTo(60, cy + 11, 96, cy - 3)
      ..lineTo(96, cy + 8)
      ..quadraticBezierTo(60, cy + 22, 24, cy + 8)
      ..close();
    canvas.drawPath(wrap, wool);
    canvas.drawPath(wrap, line);
    // Knit stripes + hanging tail on the right side.
    for (var i = 0; i < 4; i++) {
      final x = 34.0 + i * 16;
      canvas.drawLine(
        Offset(x, cy + (i.isEven ? -1 : 1)),
        Offset(x + 8, cy + (i.isEven ? 6 : 8)),
        Paint()
          ..color = const Color(0xfffdf6e3)
          ..strokeWidth = 2.4,
      );
    }
    final tail = Path()
      ..moveTo(74, cy + 12)
      ..lineTo(88, cy + 12)
      ..lineTo(92, cy + 34)
      ..lineTo(78, cy + 36)
      ..close();
    canvas.drawPath(tail, wool);
    canvas.drawPath(tail, line);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScarfPainter old) => old.centered != centered;
}

/// Wide straw sun hat — Sunny Terrace reward.
class _SunhatPainter extends CustomPainter {
  const _SunhatPainter({this.centered = false});
  final bool centered;

  @override
  void paint(Canvas canvas, Size size) {
    _scaleTo(canvas, size, 120, 120);
    final cy = centered ? 54.0 : 10.0;
    final straw = Paint()..color = const Color(0xfff0d488);
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    final dome = Path()
      ..moveTo(38, cy + 10)
      ..quadraticBezierTo(42, cy - 14, 62, cy - 12)
      ..quadraticBezierTo(80, cy - 10, 82, cy + 10)
      ..close();
    canvas.drawPath(dome, straw);
    canvas.drawPath(dome, line);
    final brim = Path()
      ..moveTo(14, cy + 12)
      ..quadraticBezierTo(60, cy + 26, 106, cy + 12)
      ..quadraticBezierTo(60, cy + 20, 14, cy + 12)
      ..close();
    canvas.drawPath(brim, straw);
    canvas.drawPath(brim, line);
    canvas.drawLine(
      Offset(40, cy + 8),
      Offset(80, cy + 8),
      Paint()
        ..color = const Color(0xffd84343)
        ..strokeWidth = 3.4,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SunhatPainter old) => old.centered != centered;
}

/// Royal purple cape with a gold clasp — Royal Salon reward.
class _CapePainter extends CustomPainter {
  const _CapePainter({this.centered = false});
  final bool centered;

  @override
  void paint(Canvas canvas, Size size) {
    _scaleTo(canvas, size, 120, 120);
    final cy = centered ? 44.0 : 92.0;
    final cloth = Paint()..color = const Color(0xff6a3aa0);
    final trim = Paint()..color = const Color(0xfffdf6e3);
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final cape = Path()
      ..moveTo(24, cy)
      ..quadraticBezierTo(60, cy + 12, 96, cy)
      ..lineTo(104, cy + 28)
      ..quadraticBezierTo(60, cy + 38, 16, cy + 28)
      ..close();
    canvas.drawPath(cape, cloth);
    canvas.drawPath(cape, line);
    canvas.drawLine(
      Offset(26, cy + 3),
      Offset(94, cy + 3),
      Paint()
        ..color = trim.color
        ..strokeWidth = 3.2,
    );
    final clasp = Rect.fromCircle(center: Offset(60, cy + 5), radius: 5);
    canvas.drawOval(clasp, Paint()..color = gold);
    canvas.drawOval(clasp, line);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CapePainter old) => old.centered != centered;
}

/// Tilted artist beret — Atelier reward.
class _BeretPainter extends CustomPainter {
  const _BeretPainter({this.centered = false});
  final bool centered;

  @override
  void paint(Canvas canvas, Size size) {
    _scaleTo(canvas, size, 120, 120);
    final cy = centered ? 54.0 : 8.0;
    final felt = Paint()..color = const Color(0xffb33a5b);
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    final beret = Path()
      ..moveTo(24, cy + 14)
      ..quadraticBezierTo(26, cy - 6, 58, cy - 8)
      ..quadraticBezierTo(94, cy - 10, 96, cy + 16)
      ..quadraticBezierTo(60, cy + 24, 24, cy + 14)
      ..close();
    canvas.drawPath(beret, felt);
    canvas.drawPath(beret, line);
    canvas.drawOval(
      Rect.fromCircle(center: Offset(62, cy - 8), radius: 3.5),
      felt,
    );
    canvas.drawOval(
      Rect.fromCircle(center: Offset(62, cy - 8), radius: 3.5),
      line,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BeretPainter old) => old.centered != centered;
}

/// Champion medal on a ribbon — Trophy Hall reward.
class _MedalPainter extends CustomPainter {
  const _MedalPainter({this.centered = false});
  final bool centered;

  @override
  void paint(Canvas canvas, Size size) {
    _scaleTo(canvas, size, 120, 120);
    final cy = centered ? 56.0 : 102.0;
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final ribbon = Path()
      ..moveTo(46, cy - 8)
      ..lineTo(56, cy + 8)
      ..lineTo(60, cy + 4)
      ..lineTo(64, cy + 8)
      ..lineTo(74, cy - 8)
      ..lineTo(66, cy - 10)
      ..lineTo(60, cy - 2)
      ..lineTo(54, cy - 10)
      ..close();
    canvas.drawPath(ribbon, Paint()..color = const Color(0xffd84343));
    canvas.drawPath(ribbon, line);
    final medal = Rect.fromCircle(center: Offset(60, cy + 14), radius: 8);
    canvas.drawOval(medal, Paint()..color = gold);
    canvas.drawOval(medal, line);
    canvas.drawCircle(Offset(60, cy + 14), 3.2, Paint()..color = ink);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MedalPainter old) => old.centered != centered;
}

/// Small glowing crown of light — Cat Sanctuary reward.
class _HaloCrownPainter extends CustomPainter {
  const _HaloCrownPainter({this.centered = false});
  final bool centered;

  @override
  void paint(Canvas canvas, Size size) {
    _scaleTo(canvas, size, 120, 120);
    final cy = centered ? 52.0 : 6.0;
    // Soft halo from two stacked alpha fills — cheap, no MaskFilter blur.
    for (final (w, a) in [(78.0, 0x33), (58.0, 0x55)]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(60, cy + 8), width: w, height: 20),
        Paint()..color = Color.fromARGB(a, 0xff, 0xe2, 0x7a),
      );
    }
    final band = Path()
      ..moveTo(34, cy + 10)
      ..quadraticBezierTo(60, cy + 20, 86, cy + 10)
      ..lineTo(86, cy + 16)
      ..quadraticBezierTo(60, cy + 26, 34, cy + 16)
      ..close();
    canvas.drawPath(band, Paint()..color = const Color(0xffffe27a));
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(band, line);
    for (final x in [40.0, 60.0, 80.0]) {
      canvas.drawCircle(Offset(x, cy + 6), 4, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(x, cy + 6), 4, line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HaloCrownPainter old) => old.centered != centered;
}

/// Classic gold crown — Golden Palace reward.
class _GoldCrownPainter extends CustomPainter {
  const _GoldCrownPainter({this.centered = false});
  final bool centered;

  @override
  void paint(Canvas canvas, Size size) {
    _scaleTo(canvas, size, 120, 120);
    final cy = centered ? 50.0 : 2.0;
    final metal = Paint()..color = gold;
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    final crown = Path()
      ..moveTo(28, cy + 26)
      ..lineTo(24, cy)
      ..lineTo(40, cy + 12)
      ..lineTo(60, cy - 4)
      ..lineTo(80, cy + 12)
      ..lineTo(96, cy)
      ..lineTo(92, cy + 26)
      ..close();
    canvas.drawPath(crown, metal);
    canvas.drawPath(crown, line);
    for (final x in [38.0, 60.0, 82.0]) {
      canvas.drawCircle(
        Offset(x, cy + 19),
        3.4,
        Paint()..color = const Color(0xffd84343),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GoldCrownPainter old) => old.centered != centered;
}

/// The Supreme Crown — jewelled, glows above every other reward.
class _SupremeCrownPainter extends CustomPainter {
  const _SupremeCrownPainter({this.centered = false});
  final bool centered;

  @override
  void paint(Canvas canvas, Size size) {
    _scaleTo(canvas, size, 120, 120);
    final cy = centered ? 46.0 : 0.0;
    // Same cheap halo trick as the light crown — no MaskFilter blur.
    for (final (w, a) in [(94.0, 0x2e), (70.0, 0x50)]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(60, cy + 10), width: w, height: 26),
        Paint()..color = Color.fromARGB(a, 0xff, 0xc6, 0x3c),
      );
    }
    final metal = Paint()..color = gold;
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6;
    final crown = Path()
      ..moveTo(26, cy + 30)
      ..lineTo(20, cy + 4)
      ..lineTo(38, cy + 14)
      ..lineTo(50, cy - 6)
      ..lineTo(60, cy + 6)
      ..lineTo(70, cy - 6)
      ..lineTo(82, cy + 14)
      ..lineTo(100, cy + 4)
      ..lineTo(94, cy + 30)
      ..close();
    canvas.drawPath(crown, metal);
    canvas.drawPath(crown, line);
    final jewel = Rect.fromCircle(center: Offset(60, cy + 19), radius: 5.5);
    canvas.drawOval(jewel, Paint()..color = const Color(0xffe83a3a));
    canvas.drawOval(jewel, line);
    for (final x in [36.0, 84.0]) {
      canvas.drawCircle(
        Offset(x, cy + 21),
        3.4,
        Paint()..color = const Color(0xff3f6fb5),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SupremeCrownPainter old) => old.centered != centered;
}

/// Procedural accessory painters by sprite id. Anything not listed here is
/// a real PNG in `assets/generated/` and renders through [sprite].
CustomPainter? _proceduralAccessory(String name, {bool centered = false}) =>
    switch (name) {
      'acc_glasses' => _GlassesPainter(centered: centered),
      'acc_bowtie' => _BowtiePainter(centered: centered),
      'acc_flower' => _FlowerPainter(centered: centered),
      'acc_collar' => _CollarPainter(centered: centered),
      'acc_bib' => _BibPainter(centered: centered),
      'acc_nightcap' => _NightcapPainter(centered: centered),
      'acc_jester' => _JesterPainter(centered: centered),
      'acc_scarf' => _ScarfPainter(centered: centered),
      'acc_sunhat' => _SunhatPainter(centered: centered),
      'acc_royal_cape' => _CapePainter(centered: centered),
      'acc_beret' => _BeretPainter(centered: centered),
      'acc_medal' => _MedalPainter(centered: centered),
      'acc_halo_crown' => _HaloCrownPainter(centered: centered),
      'acc_gold_crown' => _GoldCrownPainter(centered: centered),
      'acc_supreme_crown' => _SupremeCrownPainter(centered: centered),
      _ => null,
    };

/// Renders any accessory id: procedural ids paint in the cat's 120×120
/// head space, PNG ids load from `assets/generated/`. Pass
/// `centered: false` when overlaying the accessory on the cat head and
/// `true` for standalone cards.
Widget accessoryArt(
  String name, {
  double size = 40,
  bool centered = true,
}) {
  final painter = _proceduralAccessory(name, centered: centered);
  if (painter != null) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: painter),
    );
  }
  return sprite(name, size: size);
}

/// Accessory overlay aligned on the cat head (120×120 canonical space):
/// PNG accessories float top-centre as before, procedural ones paint
/// full-size so glasses/bowtie/flower land exactly on the face.
Widget catAccessoryOverlay(String name, {required double size}) {
  if (_proceduralAccessory(name) != null) {
    return accessoryArt(name, size: size, centered: false);
  }
  return Align(
    alignment: Alignment.topCenter,
    child: sprite(name, size: size * .7),
  );
}

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
        CustomPaint(painter: CatLayersPainter(spec, onlyLayers: onlyLayers)),
        if (showAccessory && spec.accessory.isNotEmpty)
          catAccessoryOverlay(spec.accessory, size: size),
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
          catAccessoryOverlay(player.accessory, size: size),
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
// Always a cat: rendered by the same layer stack as the duel cats plus a
// torso so the head reads as part of a body, not a pasted-on disc. No photo,
// no network, no cost.
// ---------------------------------------------------------------------------

/// Avatar-only power asset ids shown by the cat creator. These are profile
/// flair, separate from the three equal-strength duel powers in `catalog`.
const avatarPowerIds = [
  'power_zoomies',
  'power_shadow_pounce',
  'power_laser_chase',
];
const avatarPowerNames = ['Zoomies', 'Shadow Pounce', 'Laser Chase'];

/// Avatar ear variants: the four cat styles plus a bandaged-ear flair option.
const avatarEarCount = 5;

/// Shared-preferences key for the locally stored avatar spec JSON.
const avatarSpecKey = 'avatar_spec_v1';

/// Visual description of the player's avatar — always a cat. Every field is
/// a small index or an accessory sprite id so the whole spec serializes to a
/// compact JSON object that `Player`/`CloudProfile` can persist later.
class AvatarSpec {
  const AvatarSpec({
    this.fur = 0,
    this.pattern = 0,
    this.eyes = 0,
    this.ears = 0,
    this.accessory = '',
    this.power = 'power_zoomies',
  });

  /// Fur palette index into [catFurColours].
  final int fur;

  /// Pattern index in `0..[catPatternCount)` (same set as the cats).
  final int pattern;

  /// Iris palette index into [catEyeColours].
  final int eyes;

  /// Ear style index in `0..[avatarEarCount)`; cat indices 0-3 match
  /// [catEarCount], index 4 is the bandaged-ear flair option.
  final int ears;

  /// Accessory sprite id from `assets/generated/` ('' = none). Only ids from
  /// [accessories] are accepted so a bad save can never request a missing
  /// asset.
  final String accessory;

  /// Avatar power asset id from [avatarPowerIds].
  final String power;

  Color get furColor => catFurColours[_clampIndex(fur, catFurColours.length)];
  Color get eyeColor => catEyeColours[_clampIndex(eyes, catEyeColours.length)];

  AvatarSpec copyWith({
    int? fur,
    int? pattern,
    int? eyes,
    int? ears,
    String? accessory,
    String? power,
  }) => AvatarSpec(
    fur: fur ?? this.fur,
    pattern: pattern ?? this.pattern,
    eyes: eyes ?? this.eyes,
    ears: ears ?? this.ears,
    accessory: accessory ?? this.accessory,
    power: power ?? this.power,
  );

  /// Compact JSON form proposed for `Player.avatar`/`CloudProfile.avatar`.
  Map<String, Object?> toJson() => {
    'f': _clampIndex(fur, catFurColours.length),
    'p': _clampIndex(pattern, catPatternCount),
    'e': _clampIndex(eyes, catEyeColours.length),
    'r': _clampIndex(ears, avatarEarCount),
    'a': accessories.contains(accessory) ? accessory : '',
    'w': avatarPowerIds.contains(power) ? power : avatarPowerIds.first,
  };

  String toJsonString() => jsonEncode(toJson());

  /// Tolerant parse for local/cloud data: bad or out-of-range values fall
  /// back to defaults instead of throwing, so a corrupt save cannot brick
  /// the avatar. Unknown accessory ids are dropped. A legacy `'s'` species
  /// field is ignored — the avatar is always a cat.
  factory AvatarSpec.fromJson(Map<String, Object?> json) {
    int pick(String key, int fallback, int count) {
      final v = json[key];
      return v is int && v >= 0 && v < count ? v : fallback;
    }

    final a = json['a'];
    final w = json['w'];
    return AvatarSpec(
      fur: pick('f', 0, catFurColours.length),
      pattern: pick('p', 0, catPatternCount),
      eyes: pick('e', 0, catEyeColours.length),
      ears: pick('r', 0, avatarEarCount),
      accessory: a is String && accessories.contains(a) ? a : '',
      power: w is String && avatarPowerIds.contains(w)
          ? w
          : avatarPowerIds.first,
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
      other.fur == fur &&
      other.pattern == pattern &&
      other.eyes == eyes &&
      other.ears == ears &&
      other.accessory == accessory &&
      other.power == power;

  @override
  int get hashCode => Object.hash(fur, pattern, eyes, ears, accessory, power);
}

/// Loads the locally stored avatar spec; a missing or corrupt value yields
/// the default spec. This is lane-3 local persistence until the orchestrator
/// adds `Player.avatar`/`CloudProfile.avatar` (see docs/requests.md).
AvatarSpec loadAvatarSpec(SharedPreferences prefs) =>
    AvatarSpec.fromJsonString(prefs.getString(avatarSpecKey));

Future<void> saveAvatarSpec(SharedPreferences prefs, AvatarSpec spec) =>
    prefs.setString(avatarSpecKey, spec.toJsonString());

/// Player-backed avatar store. [Player.avatarSpec] is canonical; the prefs
/// key stays as a migration fallback for saves made before the field.
AvatarSpec avatarSpecFor(Player p) {
  final spec = p.avatarSpec;
  return spec.isEmpty
      ? loadAvatarSpec(p.prefs)
      : AvatarSpec.fromJsonString(spec);
}

Future<void> saveAvatarSpecFor(Player p, AvatarSpec spec) async {
  p.avatarSpec = spec.toJsonString();
  await saveAvatarSpec(p.prefs, spec);
  await p.save();
}

/// Preset cat artworks offered as the player's avatar in the profile picker
/// (the three real sprites — never typed or uploaded images) plus
/// `'my_cat'`, which renders the player's own customized cat live.
const avatarArtChoices = ['cat_tzuki', 'cat_bubble', 'cat_custom', 'my_cat'];

/// Whether a cat name uses the player's custom spec rather than a preset
/// identity — mirrors [catSpecFor].
bool isCustomCat(String cat) {
  final key = cat.toLowerCase();
  return key != 'tzuki' && key != 'bubble';
}

String _catBodyAsset(String cat) => switch (cat.toLowerCase()) {
  'tzuki' => 'cat_tzuki',
  'bubble' => 'cat_bubble',
  _ => 'cat_custom',
};

/// Real sprite art for a cat — this is what every screen shows now that
/// the hand-drawn cat painters are retired. Full-body cats get the
/// Brawl-Stars-style dimensional treatment (rim light, ground shadow,
/// top sheen, breathing sway); [portrait] picks the round `avatar_*`
/// bust which is already dimensional art. The custom cat still answers
/// the editor: tinted by the chosen fur and wearing the accessory.
Widget realCatSprite(
  String cat, {
  double height = 210,
  bool portrait = false,
  Color? furTint,
  String accessory = '',
}) {
  final body = _catBodyAsset(cat);
  final asset = portrait ? 'avatar_${body.substring(4)}' : body;
  Widget img = arenaImage(
    asset,
    fit: BoxFit.contain,
    fallback: const Center(
      child: Icon(Icons.pets, color: Color(0xffffd166), size: 40),
    ),
  );
  if (furTint != null) {
    img = ColorFiltered(
      colorFilter: ColorFilter.mode(furTint, BlendMode.modulate),
      child: img,
    );
  }
  if (!portrait) {
    return _DepthCat(
      asset: asset,
      tinted: img,
      accessory: accessory,
      height: height,
    );
  }
  return SizedBox(
    width: height,
    height: height,
    child: Stack(
      fit: StackFit.expand,
      children: [
        img,
        if (accessory.isNotEmpty)
          Align(
            alignment: Alignment.topCenter,
            child: FractionallySizedBox(
              widthFactor: 0.64,
              heightFactor: 0.6,
              child: FittedBox(
                fit: BoxFit.contain,
                child: catAccessoryOverlay(accessory, size: 120),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Pseudo-3D cat: soft ground shadow, warm rim light leaking from the
/// top-left silhouette, a top sheen and a slow breathing sway — the
/// cheap tricks that make a 2D sprite read as a dimensional character.
class _DepthCat extends StatefulWidget {
  const _DepthCat({
    required this.asset,
    required this.tinted,
    required this.accessory,
    required this.height,
  });

  final String asset;
  final Widget tinted;
  final String accessory;
  final double height;

  @override
  State<_DepthCat> createState() => _DepthCatState();
}

class _DepthCatState extends State<_DepthCat>
    with SingleTickerProviderStateMixin {
  // One-shot spawn bounce (plays once, then rests): the cat pops in
  // like a brawler landing on stage, so screens stay settle-able.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height;
    return SizedBox(
      width: h,
      height: h,
      child: Stack(
        children: [
          // Contact shadow — grounds the cat like a figure on a stage.
          Positioned(
            left: h * 0.14,
            right: h * 0.14,
            bottom: h * 0.018,
            height: h * 0.075,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x66000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
          // Rim light: the same sprite tinted warm and nudged up-left so
          // a bright edge leaks from behind the silhouette.
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(-h * 0.013, -h * 0.013),
              child: Opacity(
                opacity: 0.55,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Color(0xffffe9b0),
                    BlendMode.srcIn,
                  ),
                  child: arenaImage(widget.asset, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          // Main sprite + top sheen + spawn bounce.
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _intro,
              builder: (context, _) {
                final t = Curves.easeOutBack.transform(_intro.value);
                return Transform.scale(
                  scale: 0.82 + 0.18 * t,
                  alignment: Alignment.bottomCenter,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      widget.tinted,
                      // Sheen on the top ~40%: a screen-blended copy,
                      // clipped so only head and shoulders catch light.
                      Align(
                        alignment: Alignment.topCenter,
                        heightFactor: 0.42,
                        child: ClipRect(
                          child: ColorFiltered(
                            colorFilter: const ColorFilter.mode(
                              Color(0x3dffffff),
                              BlendMode.screen,
                            ),
                            child: arenaImage(
                              widget.asset,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (widget.accessory.isNotEmpty)
            Align(
              alignment: Alignment.topCenter,
              child: FractionallySizedBox(
                widthFactor: 0.52,
                heightFactor: 0.48,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: catAccessoryOverlay(widget.accessory, size: 120),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The player's equipped cat as real sprite art. Preset cats keep their
/// identity; the custom cat is tinted by [Player.fur] and wears
/// [Player.accessory]. Eyes/ears/pattern stay stored on the profile.
Widget realCatArt(Player p, {double height = 210, bool portrait = false}) =>
    realCatSprite(
      p.cat,
      height: height,
      portrait: portrait,
      furTint: isCustomCat(p.cat)
          ? catFurColours[_clampIndex(p.fur, catFurColours.length)]
          : null,
      accessory: p.accessory,
    );

/// The player's avatar: `'my_cat'` shows the player's own cat as real
/// sprite art (fur tint + accessory — it updates when the cat is edited),
/// the `cat_x` presets resolve to the round portraits, and an empty choice
/// shows the equipped cat's portrait.
Widget playerAvatarArt(Player p, {double size = 46}) {
  if (p.avatarArt == 'my_cat') {
    return realCatArt(p, height: size, portrait: true);
  }
  if (p.avatarArt.isEmpty) return catPortrait(p.cat, size: size);
  // 'cat_x' choices resolve to the round avatar_x portraits.
  final art = p.avatarArt.startsWith('cat_')
      ? 'avatar_${p.avatarArt.substring(4)}'
      : p.avatarArt;
  return Image.asset(
    'assets/images/$art.png',
    width: size,
    height: size,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => catPortrait('custom', size: size),
  );
}

/// Round cat portrait (`assets/images/avatar_tzuki|bubble|custom.png`) for
/// a cat name — used in duel medallions, the profile, friends and the
/// leaderboard. Unknown cats fall back to the custom portrait.
Widget catPortrait(String cat, {double size = 46}) {
  final key = cat.toLowerCase();
  final name = key == 'tzuki' || key == 'bubble'
      ? 'avatar_$key'
      : 'avatar_custom';
  return ClipOval(
    child: Image.asset(
      'assets/images/$name.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        width: size,
        height: size,
        color: const Color(0xff5d4037),
        child: Icon(
          Icons.pets,
          size: size * 0.55,
          color: const Color(0xffffd166),
        ),
      ),
    ),
  );
}

// --- avatar geometry (canonical 120x120 space, like the cat head) -----------

/// Shoulder/chest silhouette that grounds the avatar head: a soft dome that
/// fans out below the chin so the avatar reads as a bust, not a floating
/// disc. The bottom is clipped by the canvas edge.
Path _avatarTorsoPath() => Path()
  ..moveTo(6, 122)
  ..cubicTo(6, 98, 30, 86, 62, 86)
  ..cubicTo(94, 86, 118, 98, 118, 122)
  ..close();

/// Pink bandage wrapped over the left ear area (ear option 4).
void _paintBandage(Canvas canvas) {
  const center = Offset(30, 34);
  final bandage = Paint()..color = const Color(0xffffb3c7);
  final line = Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final rect = RRect.fromRectAndRadius(
    Rect.fromCenter(center: center, width: 20, height: 13),
    const Radius.circular(6),
  );
  canvas.drawRRect(rect, bandage);
  canvas.drawRRect(rect, line);
  for (final dx in [-11.0, 8.0]) {
    canvas.drawRect(
      Rect.fromLTWH(center.dx + dx, center.dy - 6, 5, 12),
      bandage,
    );
    canvas.drawRect(Rect.fromLTWH(center.dx + dx, center.dy - 6, 5, 12), line);
  }
}

/// Paints an [AvatarSpec] in the canonical 120x120 space. The avatar is
/// always a cat: a fur torso anchors the bottom of the frame and the cat
/// layer stack (ears, head, pattern, muzzle, eyes) is drawn slightly smaller
/// and raised so it sits on the shoulders like a bust.
class AvatarPainter extends CustomPainter {
  const AvatarPainter(this.spec);
  final AvatarSpec spec;

  @override
  void paint(Canvas canvas, Size size) {
    final fur = spec.furColor;
    final bandaged = spec.ears == 4;
    final cat = CatSpec(
      fur: fur,
      pattern: _clampIndex(spec.pattern, catPatternCount),
      eyes: spec.eyeColor,
      ears: bandaged ? 0 : _clampIndex(spec.ears, catEarCount),
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // Torso behind the head, in canonical space.
    canvas.save();
    canvas.scale(size.width / 120, size.height / 120);
    final torso = _avatarTorsoPath();
    canvas.drawPath(torso, Paint()..color = fur);
    canvas.drawPath(
      torso,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    // Cream chest patch under the chin, echoing the body painter's belly.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(62, 128), width: 54, height: 40),
      Paint()..color = const Color(0xffffeddd),
    );
    for (final x in [45.0, 79.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 118), width: 28, height: 15),
        Paint()..color = const Color(0xffffeddd),
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 118), width: 28, height: 15),
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    canvas.restore();
    // Head stack: scaled down and lifted so the chin overlaps the shoulders.
    const headScale = 0.86;
    canvas.translate(
      size.width * (1 - headScale) * 62 / 120,
      size.height * (108 - 122 * headScale) / 120,
    );
    canvas.scale(headScale);
    CatLayersPainter(cat).paint(canvas, size);
    canvas.restore();
    if (bandaged) {
      canvas.save();
      canvas.translate(
        size.width * (1 - headScale) * 62 / 120,
        size.height * (108 - 122 * headScale) / 120,
      );
      canvas.scale(headScale);
      canvas.scale(size.width / 120, size.height / 120);
      _paintBandage(canvas);
      canvas.restore();
    }
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
          _proceduralAccessory(spec.accessory) != null
              ? Transform.translate(
                  offset: Offset(
                    size * (1 - 0.86) * 62 / 120,
                    size * (108 - 122 * 0.86) / 120,
                  ),
                  child: Transform.scale(
                    scale: 0.86,
                    child: accessoryArt(
                      spec.accessory,
                      size: size,
                      centered: false,
                    ),
                  ),
                )
              : Align(
                  alignment: Alignment.topCenter,
                  child: sprite(spec.accessory, size: size * .7),
                ),
      ],
    ),
  );
}
