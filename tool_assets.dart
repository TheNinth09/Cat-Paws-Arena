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
  final icon = im.decodeImage(File('assets/app_icon.jpg').readAsBytesSync())!;
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
        width: (canvasSize * 0.82).round(),
        height: (canvasSize * 0.82).round(),
        interpolation: im.Interpolation.average,
      ),
      center: true,
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
  'cat_custom': true,
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
  'zoomies_emblem': true,
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
      // Hard guarantee: every cutout keeps a fully transparent outer
      // ring. Some subjects (e.g. the cushion) are cropped by the source
      // frame — their AA slivers at the edge get zeroed here; centred
      // sprites are unaffected (verified: only cat_cushion had any).
      for (final p in out) {
        if (p.x < 4 ||
            p.x >= out.width - 4 ||
            p.y < 4 ||
            p.y >= out.height - 4) {
          p.a = 0;
        }
      }
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
