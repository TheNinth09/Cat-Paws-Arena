import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as im;

void main(List<String> args) {
  if (args.contains('--icons-only')) {
    generateLauncherIcons();
    return;
  }
  if (args.contains('--images-only')) {
    generateImages();
    return;
  }
  generateImages();
  Directory('assets/generated').createSync(recursive: true);
  final sheets = <String, Map<String, List<int>>>{
    'tiles_obstacles': {
      'tile_star': [50, 120, 570, 550],
      'tile_fish': [740, 220, 570, 400],
      'tile_mouse': [1400, 120, 600, 550],
      'tile_paw': [50, 760, 580, 530],
      'tile_yarn': [750, 760, 550, 530],
      'obs_cardboard_box': [570, 1450, 430, 470],
      'obs_tangled_yarn': [1040, 1450, 460, 480],
      'obs_slipper': [1530, 1450, 470, 480],
    },
    'ui_emotes': {
      'icon_paw_coin': [30, 50, 470, 510],
      'icon_trophy': [530, 65, 490, 490],
      'icon_chest': [1050, 55, 490, 500],
      'icon_golden_fish': [1570, 55, 460, 500],
      'btn_play_paw': [40, 690, 660, 580],
      'btn_green': [740, 840, 600, 300],
      'btn_surrender_red': [1390, 840, 620, 300],
      'emote_laugh': [60, 1370, 630, 610],
      'emote_angry': [710, 1370, 640, 610],
      'emote_love': [1350, 1370, 680, 610],
    },
    'powers_accessories': {
      'vfx_zoomies': [30, 100, 670, 620],
      'vfx_shadow_pounce': [730, 100, 620, 620],
      'vfx_laser_chase': [1370, 100, 640, 620],
      'acc_pirate_bandana': [100, 970, 600, 440],
      'acc_witch_hat': [750, 950, 600, 480],
      'acc_pink_bow': [1410, 1030, 520, 360],
      'acc_ninja_headband': [1090, 1550, 850, 370],
    },
  };
  for (final sheet in sheets.entries) {
    final source = im.decodeImage(
      File('assets/sprites_${sheet.key}.png.jpg').readAsBytesSync(),
    )!;
    for (final entry in sheet.value.entries) {
      final r = entry.value;
      final crop = im
          .copyCrop(source, x: r[0], y: r[1], width: r[2], height: r[3])
          .convert(numChannels: 4);
      for (final p in crop) {
        final low = min(p.r, min(p.g, p.b));
        if (low >= 248) {
          p.a = 0;
        } else if (low > 235) {
          p.a = ((248 - low) / 13 * 255).round();
        }
      }
      File('assets/generated/${entry.key}.png')
          .writeAsBytesSync(im.encodePng(im.copyResize(crop, width: 256)));
    }
  }
  generateLauncherIcons();
  final bytes = BytesBuilder();
  const rate = 22050, seconds = 2;
  final data = ByteData(rate * seconds * 2);
  for (var i = 0; i < rate * seconds; i++) {
    final t = i / rate;
    final wave =
        (sin(2 * pi * 85 * t) + 0.4 * sin(2 * pi * 170 * t)) *
        (0.5 + 0.5 * sin(2 * pi * 26 * t));
    data.setInt16(
      i * 2,
      (wave * 1800 * sin(pi * t / seconds)).round(),
      Endian.little,
    );
  }
  void text(String s) => bytes.add(s.codeUnits);
  void number(int n, int size) {
    final d = ByteData(size);
    if (size == 4) {
      d.setUint32(0, n, Endian.little);
    } else {
      d.setUint16(0, n, Endian.little);
    }
    bytes.add(d.buffer.asUint8List());
  }

  text('RIFF');
  number(36 + data.lengthInBytes, 4);
  text('WAVEfmt ');
  number(16, 4);
  number(1, 2);
  number(1, 2);
  number(rate, 4);
  number(rate * 2, 4);
  number(2, 2);
  number(16, 2);
  text('data');
  number(data.lengthInBytes, 4);
  bytes.add(data.buffer.asUint8List());
  File('assets/generated/purr.wav').writeAsBytesSync(bytes.toBytes());
}

void generateLauncherIcons() {
  final icon = im.decodeImage(File('assets/app_icon.png').readAsBytesSync())!;
  const root = 'android/app/src/main/res';
  for (final entry in {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  }.entries) {
    final size = entry.value;
    final folder = '$root/mipmap-${entry.key}';
    File('$folder/ic_launcher.png').writeAsBytesSync(
      im.encodePng(
        im.copyResize(
          icon,
          width: size,
          height: size,
          interpolation: im.Interpolation.average,
        ),
      ),
    );
    final canvasSize = (size * 108 / 48).round();
    final foreground = im.Image(
      width: canvasSize,
      height: canvasSize,
      numChannels: 4,
    );
    im.compositeImage(
      foreground,
      im.copyResize(
        icon,
        width: canvasSize,
        height: canvasSize,
        interpolation: im.Interpolation.average,
      ),
    );
    File('$folder/ic_launcher_foreground.png')
        .writeAsBytesSync(im.encodePng(foreground));
  }
  final pixel = icon.getPixel(icon.width ~/ 2, 0);
  final color = [
    pixel.r,
    pixel.g,
    pixel.b,
  ].map((v) => v.toInt().toRadixString(16).padLeft(2, '0')).join();
  Directory('$root/mipmap-anydpi-v26').createSync(recursive: true);
  File('$root/mipmap-anydpi-v26/ic_launcher.xml')
      .writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
''');
  File('$root/values/ic_launcher_background.xml')
      .writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#$color</color>
</resources>
''');
}

/// Final sprites written to `assets/images/` — the paths other lanes
/// code against. The bool marks cutout sprites that need the white
/// studio background removed; backgrounds, power icons and the
/// splash keep their full frame. Sources stay in `assets/` and are
/// reference-only (never shipped in the runtime bundle).
const _kImageTargets = <String, bool>{
  'cat_tzuki': true,
  'cat_bubble': true,
  'cat_cushion': true,
  'tile_star': true,
  'tile_fish': true,
  'tile_mouse': true,
  'tile_paw': true,
  'tile_yarn': true,
  'tile_box': true,
  'milestone_chest': true,
  'trophy_gold_fish': true,
  'daily_gift': true,
  'paws_daily_5': true,
  'paws_pack_coins': true,
  'paws_pack_bag': true,
  'paws_pack_chest': true,
  'shop_paws_small': true,
  'shop_paws_medium': true,
  'shop_paws_mega': true,
  'special_fish_rocket': true,
  'special_yarn_bomb': true,
  'special_mouse_copter': true,
  'special_rainbow_paw': true,
  'btn_emote': true,
  'emote_happy': true,
  'emote_cheer': true,
  'emote_surprised': true,
  'emote_laugh': true,
  'icon_friends': true,
  'icon_leaderboard': true,
  'icon_cloud_account': true,
  'icon_achievements': true,
  'icon_bandages': true,
  'icon_accessories': true,
  'icon_music': true,
  'icon_sfx': true,
  'icon_haptics': true,
  'icon_language': true,
  'icon_events': true,
  'icon_team': true,
  'bg_living_room': false,
  'bg_main_hall': false,
  'bg_hallway': false,
  'bg_kitchen': false,
  'bg_bedroom': false,
  'power_zoomies': false,
  'power_shadow_pounce': false,
  'power_laser_chase': false,
};

void generateImages() {
  Directory('assets/images').createSync(recursive: true);
  for (final entry in _kImageTargets.entries) {
    final sourceFile = File('assets/${entry.key}.png');
    if (!sourceFile.existsSync()) {
      // Missing new source: keep any existing runtime art at the
      // destination untouched (e.g. tile_paw has no new download yet).
      stdout.writeln('images/${entry.key}.png SKIPPED (no source)');
      continue;
    }
    final source = im.decodeImage(sourceFile.readAsBytesSync())!;
    final im.Image out;
    if (entry.value) {
      out = im.copyResize(
        _removeWhiteBackground(source),
        width: 512,
        interpolation: im.Interpolation.average,
      );
    } else if (entry.key.startsWith('bg_')) {
      out = im.copyResize(
        source,
        width: 1080,
        interpolation: im.Interpolation.average,
      );
    } else {
      out = im.copyResize(
        source,
        width: 512,
        interpolation: im.Interpolation.average,
      );
    }
    File('assets/images/${entry.key}.png').writeAsBytesSync(im.encodePng(out));
    stdout.writeln('images/${entry.key}.png ${out.width}x${out.height}');
  }
  // cat_run has no downloaded source — keep the procedural runner.
  final run = im.copyResize(
    _drawCatSprite('cat_run'),
    width: 512,
    interpolation: im.Interpolation.average,
  );
  File('assets/images/cat_run.png').writeAsBytesSync(im.encodePng(run));
  stdout.writeln('images/cat_run.png ${run.width}x${run.height}');
  final splash = im.decodeImage(
    File('assets/splash_screen.png').readAsBytesSync(),
  )!;
  final splashOut = im.copyResize(
    splash,
    width: 1080,
    interpolation: im.Interpolation.average,
  );
  File('assets/images/splash_screen.png')
      .writeAsBytesSync(im.encodePng(splashOut));
  stdout.writeln(
    'images/splash_screen.png ${splashOut.width}x${splashOut.height}',
  );
}

/// Removes the near-white studio background by flood-filling from the
/// image edges only, so white artwork inside the sprite is preserved.
/// Exterior pixels become fully transparent; the 1px rim on the
/// artwork side keeps a soft alpha derived from how white each pixel
/// is, retaining anti-aliased edges.
im.Image _removeWhiteBackground(im.Image source) {
  const bgMin = 240; // min(r,g,b) at or above this is background
  const rimMin = 200; // lighter rim pixels get partial alpha
  final img = source.convert(numChannels: 4);
  final w = img.width;
  final h = img.height;
  final n = w * h;
  final px = img.toUint8List();
  if (px.length < n * 4) {
    throw StateError('unexpected pixel buffer for ${w}x$h');
  }
  final mins = Uint8List(n);
  for (var i = 0; i < n; i++) {
    final o = i * 4;
    final r = px[o];
    final g = px[o + 1];
    final b = px[o + 2];
    mins[i] = r < g ? (r < b ? r : b) : (g < b ? g : b);
  }
  final exterior = Uint8List(n);
  final queue = <int>[];
  void seed(int i) {
    if (exterior[i] == 0 && mins[i] >= bgMin) {
      exterior[i] = 1;
      queue.add(i);
    }
  }

  for (var x = 0; x < w; x++) {
    seed(x);
    seed((h - 1) * w + x);
  }
  for (var y = 0; y < h; y++) {
    seed(y * w);
    seed(y * w + w - 1);
  }
  var head = 0;
  while (head < queue.length) {
    final i = queue[head++];
    final x = i % w;
    final y = i ~/ w;
    if (x > 0) {
      seed(i - 1);
    }
    if (x < w - 1) {
      seed(i + 1);
    }
    if (y > 0) {
      seed(i - w);
    }
    if (y < h - 1) {
      seed(i + w);
    }
  }
  // Rim: artwork pixels (not exterior) touching the exterior get soft
  // alpha so anti-aliased edges blend instead of haloing.
  final rim = Uint8List(n);
  for (var i = 0; i < n; i++) {
    if (exterior[i] == 0) continue;
    final x = i % w;
    final y = i ~/ w;
    for (var dy = -1; dy <= 1; dy++) {
      final ny = y + dy;
      if (ny < 0 || ny >= h) continue;
      for (var dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        final nx = x + dx;
        if (nx < 0 || nx >= w) continue;
        final j = ny * w + nx;
        if (exterior[j] == 0) rim[j] = 1;
      }
    }
  }
  for (var i = 0; i < n; i++) {
    final m = mins[i];
    final int a;
    if (exterior[i] != 0) {
      a = 0;
    } else if (rim[i] != 0 && m >= rimMin && m < bgMin) {
      a = 255 - m;
    } else {
      continue;
    }
    px[i * 4 + 3] = a;
  }
  return img;
}

// ---------------------------------------------------------------------------
// Cat sprite painter. Clean, expressive 2D cartoon cats drawn procedurally
// on a transparent 2048px canvas and downsampled to 512 — the same warm
// ink-outline look as the tile_* artwork. No source images are consumed:
// the drawings below are the new artwork.
// ---------------------------------------------------------------------------

const _kCatCanvas = 2048;
const _kCatInk = 0x51312d;
const _kCatCream = 0xffeddd;
const _kCatEarPink = 0xeca7ad;
const _kCatNosePink = 0xe78e9c;
const _kCatPupil = 0x171b25;

class _CatPalette {
  const _CatPalette({
    required this.fur,
    required this.stripe,
    required this.iris,
    this.tabby = false,
    this.oneEar = false,
  });
  final int fur, stripe, iris;
  final bool tabby, oneEar;
}

im.Color _catColor(int hex, [int alpha = 255]) =>
    im.ColorRgba8(hex >> 16 & 0xff, hex >> 8 & 0xff, hex & 0xff, alpha);

im.Point _cp(num x, num y) => im.Point(x, y);

/// Samples an ellipse (optionally rotated) into a polygon.
List<im.Point> _catEllipse(
  num cx,
  num cy,
  num rx,
  num ry, {
  num rot = 0,
  int n = 72,
}) {
  final c = cos(rot), s = sin(rot);
  return [
    for (var i = 0; i < n; i++)
      (() {
        final t = i / n * 2 * pi;
        final ex = rx * cos(t), ey = ry * sin(t);
        return _cp(cx + ex * c - ey * s, cy + ex * s + ey * c);
      })(),
  ];
}

/// Samples a cubic bezier into a polyline point list.
List<im.Point> _catBezier(
  num x0,
  num y0,
  num x1,
  num y1,
  num x2,
  num y2,
  num x3,
  num y3, {
  int n = 28,
}) => [
  for (var i = 0; i <= n; i++)
    (() {
      final t = i / n, u = 1 - t;
      return _cp(
        u * u * u * x0 + 3 * u * u * t * x1 + 3 * u * t * t * x2 + t * t * t * x3,
        u * u * u * y0 + 3 * u * u * t * y1 + 3 * u * t * t * y2 + t * t * t * y3,
      );
    })(),
];

/// Miter-offsets a closed polygon outward by [w] px, giving a uniform ink
/// outline when the inflated copy is filled underneath.
List<im.Point> _catInflate(List<im.Point> pts, double w) {
  var cx = 0.0, cy = 0.0;
  for (final p in pts) {
    cx += p.x;
    cy += p.y;
  }
  cx /= pts.length;
  cy /= pts.length;
  final n = pts.length;
  final out = <im.Point>[];
  for (var i = 0; i < n; i++) {
    final a = pts[(i - 1 + n) % n], p = pts[i], b = pts[(i + 1) % n];
    var ex = p.x - a.x, ey = p.y - a.y;
    var fx = b.x - p.x, fy = b.y - p.y;
    final le = sqrt(ex * ex + ey * ey), lf = sqrt(fx * fx + fy * fy);
    if (le > 0) {
      ex /= le;
      ey /= le;
    }
    if (lf > 0) {
      fx /= lf;
      fy /= lf;
    }
    var nx = -ey - fy, ny = ex + fx;
    final nl = sqrt(nx * nx + ny * ny);
    if (nl < 1e-6) {
      nx = -ey;
      ny = ex;
    } else {
      nx /= nl;
      ny /= nl;
    }
    if (nx * (p.x - cx) + ny * (p.y - cy) < 0) {
      nx = -nx;
      ny = -ny;
    }
    final cosA = (nx * -ey + ny * ex).abs();
    out.add(_cp(p.x + nx * w / max(cosA, 0.35), p.y + ny * w / max(cosA, 0.35)));
  }
  return out;
}

/// Fills a closed polygon with an ink outline of [outline] px.
void _catFill(
  im.Image img,
  List<im.Point> pts,
  int rgb, {
  double outline = 15,
  int alpha = 255,
}) {
  if (outline > 0) {
    im.fillPolygon(
      img,
      vertices: _catInflate(pts, outline),
      color: _catColor(_kCatInk),
    );
  }
  im.fillPolygon(img, vertices: pts, color: _catColor(rgb, alpha));
}

void _catBlob(
  im.Image img,
  num cx,
  num cy,
  num rx,
  num ry,
  int rgb, {
  num rot = 0,
  double outline = 15,
  int alpha = 255,
}) => _catFill(
  img,
  _catEllipse(cx, cy, rx, ry, rot: rot),
  rgb,
  outline: outline,
  alpha: alpha,
);

/// Strokes a polyline with round joints and caps.
void _catStroke(im.Image img, List<im.Point> pts, num w, int rgb,
    {int alpha = 255}) {
  final c = _catColor(rgb, alpha);
  for (var i = 0; i + 1 < pts.length; i++) {
    im.drawLine(
      img,
      x1: pts[i].xi,
      y1: pts[i].yi,
      x2: pts[i + 1].xi,
      y2: pts[i + 1].yi,
      color: c,
      thickness: w,
      antialias: true,
    );
  }
  for (final p in pts) {
    im.fillCircle(img, x: p.xi, y: p.yi, radius: (w / 2).round(), color: c);
  }
}

/// Front-facing sitting cat — the shared Tzuki/Bubble body. [pal] carries
/// the identity colours; [oneEar] keeps Tzuki's signature missing ear.
im.Image _drawCatFront(_CatPalette pal) {
  final img = im.Image(width: _kCatCanvas, height: _kCatCanvas, numChannels: 4);

  // Tail curled around the right side, resting beside the front paws.
  final tail = _catBezier(1380, 1500, 1720, 1510, 1850, 1640, 1710, 1790, n: 40);
  _catStroke(img, tail, 150, _kCatInk);
  _catStroke(img, tail, 104, pal.fur);

  // Sitting body: narrow shoulders widening into haunches.
  final body = <im.Point>[
    ..._catBezier(880, 845, 660, 950, 545, 1250, 585, 1530),
    ..._catBezier(585, 1530, 615, 1705, 800, 1762, 1024, 1766).skip(1),
    ..._catBezier(1024, 1766, 1250, 1762, 1435, 1705, 1465, 1530).skip(1),
    ..._catBezier(1465, 1530, 1505, 1250, 1390, 950, 1170, 845).skip(1),
    ..._catBezier(1170, 845, 1095, 806, 955, 806, 880, 845).skip(1),
  ];
  _catFill(img, body, pal.fur, outline: 16);
  if (pal.tabby) {
    for (final (x0, y0, x1, y1) in [
      (610.0, 1080.0, 745.0, 1108.0),
      (600.0, 1180.0, 735.0, 1210.0),
      (1440.0, 1080.0, 1305.0, 1108.0),
      (1450.0, 1180.0, 1315.0, 1210.0),
    ]) {
      _catStroke(img, [_cp(x0, y0), _cp(x1, y1)], 30, pal.stripe);
    }
  }
  // Cream chest, then the two front leg columns and their paws.
  _catBlob(img, 1024, 1180, 195, 270, _kCatCream, outline: 0);
  for (final x in [930.0, 1120.0]) {
    _catStroke(img, [_cp(x, 1440), _cp(x, 1705)], 118, _kCatInk);
    _catStroke(img, [_cp(x, 1440), _cp(x, 1705)], 80, pal.fur);
    _catBlob(img, x, 1748, 90, 46, _kCatCream, outline: 10);
  }

  // Ears first so the head silhouette covers their bases.
  final earOuter = [
    [_cp(700, 335), _cp(615, 55), _cp(910, 295)],
    [_cp(1350, 335), _cp(1435, 55), _cp(1140, 295)],
  ];
  final earInner = [
    [_cp(724, 300), _cp(668, 120), _cp(860, 272)],
    [_cp(1326, 300), _cp(1382, 120), _cp(1190, 272)],
  ];
  for (var side = 0; side < 2; side++) {
    if (pal.oneEar && side == 1) continue;
    _catFill(img, earOuter[side], pal.fur, outline: 15);
    im.fillPolygon(img, vertices: earInner[side], color: _catColor(_kCatEarPink));
  }

  // Head.
  _catBlob(img, 1024, 660, 430, 400, pal.fur, outline: 16);
  if (pal.tabby) {
    for (final (x0, y0, x1, y1) in [
      (952.0, 318.0, 930.0, 425.0),
      (1024.0, 296.0, 1024.0, 412.0),
      (1096.0, 318.0, 1118.0, 425.0),
      (660.0, 560.0, 760.0, 585.0),
      (650.0, 628.0, 748.0, 655.0),
      (1390.0, 560.0, 1290.0, 585.0),
      (1400.0, 628.0, 1302.0, 655.0),
    ]) {
      _catStroke(img, [_cp(x0, y0), _cp(x1, y1)], 28, pal.stripe);
    }
  } else {
    // Soft sheen keeps the dark fur readable.
    _catBlob(img, 860, 460, 240, 150, 0x454a6e, outline: 0, alpha: 110);
  }

  // Eyes: white, iris, vertical pupil, double highlight.
  for (final ex in [820.0, 1230.0]) {
    _catBlob(img, ex, 640, 112, 128, 0xffffff, outline: 0);
    _catBlob(img, ex + 6, 648, 84, 102, pal.iris, outline: 0);
    _catBlob(img, ex + 12, 652, 34, 70, _kCatPupil, outline: 0);
    im.fillCircle(
      img,
      x: (ex - 20).round(),
      y: 600,
      radius: 26,
      color: _catColor(0xffffff),
    );
    im.fillCircle(
      img,
      x: (ex + 38).round(),
      y: 688,
      radius: 11,
      color: _catColor(0xffffff),
    );
  }

  // Muzzle, nose and mouth.
  _catBlob(img, 1024, 872, 182, 118, _kCatCream, outline: 0);
  _catFill(img, [_cp(972, 828), _cp(1076, 828), _cp(1024, 880)], _kCatNosePink,
      outline: 9);
  _catStroke(img, [_cp(1024, 880), _cp(1024, 902)], 10, _kCatInk);
  _catStroke(
      img, _catBezier(1024, 902, 992, 934, 950, 930, 918, 910, n: 10), 10, _kCatInk);
  _catStroke(
      img, _catBezier(1024, 902, 1056, 934, 1098, 930, 1130, 910, n: 10), 10,
      _kCatInk);

  // Whiskers — cream reads on both light and dark fur.
  final whisker = pal.fur == 0x2a2c40 ? _kCatCream : _kCatInk;
  for (final (x0, y0, x1, y1) in [
    (690.0, 798.0, 460.0, 756.0),
    (688.0, 842.0, 452.0, 850.0),
    (690.0, 882.0, 472.0, 942.0),
    (1360.0, 798.0, 1590.0, 756.0),
    (1362.0, 842.0, 1598.0, 850.0),
    (1360.0, 882.0, 1578.0, 942.0),
  ]) {
    _catStroke(img, [_cp(x0, y0), _cp(x1, y1)], 9, whisker, alpha: 215);
  }
  return img;
}

/// Side-view running cat for the duel power moment — faces right, the
/// direction `_CatRunner` sweeps across the board.
im.Image _drawCatRun(_CatPalette pal) {
  final img = im.Image(width: _kCatCanvas, height: _kCatCanvas, numChannels: 4);

  // Tail streaming behind, slight upward curl.
  final tail = _catBezier(520, 980, 300, 900, 120, 760, 170, 560, n: 40);
  _catStroke(img, tail, 100, _kCatInk);
  _catStroke(img, tail, 62, pal.fur);
  _catStroke(img, tail.sublist(tail.length - 8), 64, pal.stripe);

  // Hind legs kicked back, front legs reaching forward — a stretched gallop.
  for (final leg in [
    [_cp(700, 1180), _cp(430, 1360), _cp(310, 1540)],
    [_cp(760, 1220), _cp(520, 1420), _cp(430, 1600)],
  ]) {
    _catStroke(img, leg, 118, _kCatInk);
    _catStroke(img, leg, 80, pal.fur);
    _catBlob(img, leg.last.x, leg.last.y, 74, 44, _kCatCream,
        rot: -0.5, outline: 10);
  }
  for (final leg in [
    [_cp(1400, 1180), _cp(1660, 1380), _cp(1790, 1540)],
    [_cp(1460, 1220), _cp(1730, 1440), _cp(1880, 1600)],
  ]) {
    _catStroke(img, leg, 112, _kCatInk);
    _catStroke(img, leg, 76, pal.fur);
    _catBlob(img, leg.last.x, leg.last.y, 74, 44, _kCatCream,
        rot: 0.55, outline: 10);
  }

  // Body leaned slightly forward, rear haunch for power.
  _catBlob(img, 700, 1060, 300, 280, pal.fur, outline: 16);
  _catBlob(img, 1000, 1050, 560, 290, pal.fur, rot: -0.06, outline: 16);
  _catBlob(img, 1000, 1170, 380, 130, _kCatCream, rot: -0.04, outline: 0);
  if (pal.tabby) {
    for (final x0 in [720.0, 870.0, 1020.0, 1170.0, 1320.0]) {
      _catStroke(
          img,
          _catBezier(x0, 810, x0 + 15, 950, x0 - 10, 1050, x0 - 25, 1120, n: 8),
          30,
          pal.stripe);
    }
  }

  // Ears, then head overlapping the body front.
  _catFill(img, [_cp(1470, 520), _cp(1520, 255), _cp(1680, 460)], pal.fur,
      outline: 14);
  _catFill(img, [_cp(1650, 500), _cp(1745, 265), _cp(1855, 480)], pal.fur,
      outline: 14);
  im.fillPolygon(img,
      vertices: [_cp(1506, 496), _cp(1534, 316), _cp(1636, 452)],
      color: _catColor(_kCatEarPink));
  im.fillPolygon(img,
      vertices: [_cp(1678, 478), _cp(1732, 326), _cp(1812, 466)],
      color: _catColor(_kCatEarPink));
  _catBlob(img, 1600, 720, 300, 290, pal.fur, outline: 16);

  // Eye, muzzle, nose, mouth.
  _catBlob(img, 1655, 690, 62, 74, 0xffffff, outline: 0);
  _catBlob(img, 1662, 694, 44, 56, pal.iris, outline: 0);
  _catBlob(img, 1668, 698, 17, 38, _kCatPupil, outline: 0);
  im.fillCircle(img, x: 1642, y: 668, radius: 14, color: _catColor(0xffffff));
  _catBlob(img, 1800, 800, 92, 62, _kCatCream, outline: 0);
  _catFill(img, [_cp(1868, 762), _cp(1920, 786), _cp(1868, 812)], _kCatNosePink,
      outline: 8);
  _catStroke(img, _catBezier(1870, 812, 1850, 846, 1820, 856, 1790, 850, n: 8),
      9, _kCatInk);
  for (final (y0, y1) in [(780.0, 730.0), (800.0, 800.0)]) {
    _catStroke(img, [_cp(1850, y0), _cp(2020, y1)], 7, _kCatCream, alpha: 210);
  }
  return img;
}

im.Image _drawCatSprite(String name) {
  switch (name) {
    case 'cat_tzuki':
      return _drawCatFront(
        const _CatPalette(
          fur: 0x99938b,
          stripe: 0x6f675c,
          iris: 0x69f0ae,
          tabby: true,
          oneEar: true,
        ),
      );
    case 'cat_bubble':
      return _drawCatFront(
        const _CatPalette(fur: 0x2a2c40, stripe: 0x1c1e2e, iris: 0xffc63c),
      );
    case 'cat_run':
      return _drawCatRun(
        const _CatPalette(
          fur: 0x99938b,
          stripe: 0x6f675c,
          iris: 0x69f0ae,
          tabby: true,
        ),
      );
  }
  throw ArgumentError('unknown cat sprite: $name');
}
