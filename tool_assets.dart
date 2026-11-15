import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as im;

void main(List<String> args) {
  if (args.contains('--icons-only')) {
    generateLauncherIcons();
    return;
  }
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
    final artSize = (canvasSize * 0.66).round();
    final foreground = im.Image(
      width: canvasSize,
      height: canvasSize,
      numChannels: 4,
    );
    im.compositeImage(
      foreground,
      im.copyResize(
        icon,
        width: artSize,
        height: artSize,
        interpolation: im.Interpolation.average,
      ),
      dstX: (canvasSize - artSize) ~/ 2,
      dstY: (canvasSize - artSize) ~/ 2,
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
