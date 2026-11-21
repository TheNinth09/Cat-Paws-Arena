import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cat_paws_arena/cat_avatar.dart';
import 'package:cat_paws_arena/cats_screen.dart';
import 'package:cat_paws_arena/profile.dart';
import 'package:cat_paws_arena/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'artwork_test_support.dart';

class _CatRender {
  const _CatRender(this.width, this.height, this.png, this.rgba);
  final int width, height;
  final Uint8List png, rgba;
}

/// Renders [child] inside a repaint boundary and returns the captured PNG
/// and raw RGBA pixels. The boundary isolates the cat, so the background
/// stays transparent.
Future<_CatRender> _renderCat(
  WidgetTester tester,
  Widget child, {
  double pixelRatio = 1,
}) async {
  final key = UniqueKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: RepaintBoundary(key: key, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final render = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final result = _CatRender(
      image.width,
      image.height,
      png!.buffer.asUint8List(),
      rgba!.buffer.asUint8List(),
    );
    image.dispose();
    return result;
  });
  return render!;
}

int _alphaAt(_CatRender render, int x, int y) =>
    render.rgba[(y * render.width + x) * 4 + 3];

void main() {
  testWidgets('runtime bundle contains only sprites and fonts', (tester) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final artwork = manifest.listAssets().where(
      (name) => name.startsWith('assets/'),
    );
    expect(artwork, isNotEmpty);
    expect(
      artwork.where(
        (name) =>
            !name.startsWith('assets/generated/') &&
            !name.startsWith('assets/images/') &&
            !name.startsWith('assets/audio/') &&
            !name.startsWith('assets/fonts/'),
      ),
      isEmpty,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Image(image: AssetImage('assets/images/studio_logo.png')),
          ),
        ),
      ),
    );
    expectCleanArtwork(tester);
  });

  testWidgets('Tzuki and Bubble render from layers at 48, 120 and 320 px', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final player = Player(prefs);
    for (final cat in ['Tzuki', 'Bubble']) {
      player.cat = cat;
      for (final size in [48.0, 120.0, 320.0]) {
        final render = await _renderCat(tester, CatAvatar(player, size: size));
        expect(render.width, size.round(), reason: '$cat at $size');
        expect(render.height, size.round(), reason: '$cat at $size');
        expect(
          render.png.length,
          greaterThan(200),
          reason: '$cat at $size produced a real image',
        );
        // The avatar must be painted by the layer compositor.
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint && widget.painter is CatLayersPainter,
          ),
          findsWidgets,
          reason: '$cat at $size uses layered rendering',
        );
        // Transparent corner, opaque centre: the cat is really drawn.
        expect(_alphaAt(render, 0, 0), 0, reason: '$cat at $size corner');
        expect(
          _alphaAt(render, render.width ~/ 2, render.height * 3 ~/ 5),
          255,
          reason: '$cat at $size centre',
        );
      }
    }
  });

  testWidgets('swapping the ear layer changes nothing else', (tester) async {
    const specTwoEars = CatSpec(
      fur: Color(0xff99938b),
      pattern: 1,
      eyes: Color(0xff69f0ae),
      ears: 0,
    );
    const specLeftEar = CatSpec(
      fur: Color(0xff99938b),
      pattern: 1,
      eyes: Color(0xff69f0ae),
      ears: 1,
    );
    final withoutEars = CatLayerKind.values
        .where((kind) => kind != CatLayerKind.ears)
        .toSet();
    final onlyEars = {CatLayerKind.ears};

    // Every non-ear layer is pixel-identical between the two specs.
    final baseA = await _renderCat(
      tester,
      CatSpecAvatar(specTwoEars, onlyLayers: withoutEars),
    );
    final baseB = await _renderCat(
      tester,
      CatSpecAvatar(specLeftEar, onlyLayers: withoutEars),
    );
    expect(baseA.rgba, baseB.rgba);

    // The ear layer itself does change.
    final earsA = await _renderCat(
      tester,
      CatSpecAvatar(specTwoEars, onlyLayers: onlyEars),
    );
    final earsB = await _renderCat(
      tester,
      CatSpecAvatar(specLeftEar, onlyLayers: onlyEars),
    );
    expect(earsA.rgba, isNot(earsB.rgba));

    // The full cat changes, and only inside the ear region (top-right of
    // the head, above the eyes).
    final fullA = await _renderCat(tester, CatSpecAvatar(specTwoEars));
    final fullB = await _renderCat(tester, CatSpecAvatar(specLeftEar));
    expect(fullA.rgba, isNot(fullB.rgba));
    var diffs = 0, outside = 0;
    for (var y = 0; y < fullA.height; y++) {
      for (var x = 0; x < fullA.width; x++) {
        final i = (y * fullA.width + x) * 4;
        if (fullA.rgba[i] != fullB.rgba[i] ||
            fullA.rgba[i + 1] != fullB.rgba[i + 1] ||
            fullA.rgba[i + 2] != fullB.rgba[i + 2] ||
            fullA.rgba[i + 3] != fullB.rgba[i + 3]) {
          diffs++;
          if (y > fullA.height * 0.4 || x < fullA.width * 0.5) outside++;
        }
      }
    }
    expect(diffs, greaterThan(0));
    expect(outside, 0, reason: 'ear swap must not touch the rest of the cat');
  });

  test('rewards, daily limits, purchases, tiers and persistence', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final p = Player(prefs);
    expect(p.claimDaily(), true);
    expect(p.claimDaily(), false);
    expect(p.coins, 505);
    expect(p.buy('hat', 300), true);
    expect(p.buy('hat', 300), false);
    expect(p.buy('expensive', 999), false);
    p.result(-1);
    expect(p.trophies, 0);
    p.trophies = 990;
    p.result(1);
    expect(p.tier, 1);
    expect(p.trophies, 1020);
    expect(p.coins, 355);
    p.result(0);
    expect(p.trophies, 1020);
    await p.save();
    final restored = Player(prefs);
    expect(restored.coins, p.coins);
    expect(restored.owned, contains('hat'));
    expect(restored.daily, p.daily);
  });

  test('preset cat names cover at least 200 unique entries', () {
    expect(catPresetNames.length, greaterThanOrEqualTo(200));
    expect(catPresetNames.toSet().length, catPresetNames.length);
  });

  testWidgets('all 480 creator combinations render without exceptions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Wrap(
              children: [
                for (var fur = 0; fur < catFurColours.length; fur++)
                  for (var pattern = 0; pattern < catPatternCount; pattern++)
                    for (var eyes = 0; eyes < catEyeColours.length; eyes++)
                      for (var ears = 0; ears < catEarCount; ears++)
                        CatSpecAvatar(
                          CatSpec.custom(
                            fur: fur,
                            pattern: pattern,
                            eyes: eyes,
                            ears: ears,
                          ),
                          size: 24,
                        ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byType(CatSpecAvatar),
      findsNWidgets(
        catFurColours.length *
            catPatternCount *
            catEyeColours.length *
            catEarCount,
      ),
    );
  });

  testWidgets('a fixed sample of 30 combinations produces real images', (
    tester,
  ) async {
    final signatures = <int>{};
    for (var i = 0; i < 30; i++) {
      final spec = CatSpec.custom(
        fur: i % catFurColours.length,
        pattern: (i * 7) % catPatternCount,
        eyes: (i * 3) % catEyeColours.length,
        ears: (i * 5) % catEarCount,
      );
      final render = await _renderCat(tester, CatSpecAvatar(spec, size: 64));
      expect(render.png.length, greaterThan(200), reason: 'combo $i');
      expect(
        _alphaAt(render, render.width ~/ 2, render.height * 3 ~/ 5),
        255,
        reason: 'combo $i centre is painted',
      );
      signatures.add(render.rgba.fold(0, (h, b) => (h * 31 + b) & 0x7fffffff));
    }
    expect(
      signatures.length,
      greaterThan(10),
      reason: 'the sample must cover visually distinct cats',
    );
  });

  testWidgets('creator builds a cat, saves it, and restores on reopen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final player = Player(prefs);
    tester.view.physicalSize = const Size(900, 1900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: CatsScreen(player: player, onShop: () {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('CUSTOM'));
    await tester.pumpAndSettle();
    expect(find.text('BLANĂ'), findsOneWidget);

    await tester.tap(find.text('Negru'));
    await tester.pumpAndSettle();
    expect(player.fur, 4);

    await tester.tap(find.text('Calico'));
    await tester.pumpAndSettle();
    expect(player.pattern, 3);

    await tester.tap(find.text('Albaștri'));
    await tester.pumpAndSettle();
    expect(player.eyes, 1);

    await tester.tap(find.text('Smocuri'));
    await tester.pumpAndSettle();
    expect(player.ears, 3);

    await tester.tap(find.text('Shadow Pounce'));
    await tester.pumpAndSettle();
    expect(player.power, 1);

    await tester.tap(find.text('ECHIPEAZĂ ȘI SALVEAZĂ'));
    await tester.pumpAndSettle();
    expect(player.cat, 'Custom');

    final savedName = prefs.getString(catCustomNameKey);
    expect(savedName, isNotNull);
    expect(catPresetNames, contains(savedName));

    final restored = Player(prefs);
    expect(restored.cat, 'Custom');
    expect(restored.fur, 4);
    expect(restored.pattern, 3);
    expect(restored.eyes, 1);
    expect(restored.ears, 3);
    expect(restored.power, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: CatsScreen(player: restored, onShop: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('CUSTOM'), findsOneWidget);
    expect(find.text(savedName!), findsOneWidget);
  });

  testWidgets('share card renders to a fixed-size PNG', (tester) async {
    const spec = CatSpec(
      fur: Color(0xff292b3c),
      pattern: 1,
      eyes: Color(0xffffc63c),
      ears: 0,
    );
    final render = await _renderCat(
      tester,
      const CatShareCard(spec: spec, catName: 'Luna', room: 'Living'),
      pixelRatio: 3,
    );
    expect(render.width, 1080);
    expect(render.height, 1350);
    expect(render.png.length, greaterThan(1000));
  });

  testWidgets('share card holds only cat, name, room and game name', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final player = Player(prefs);
    player.name = 'Alex';
    player.photo = 'aGVsbG8='; // would decode to bytes if ever rendered
    final spec = catSpecForPlayer(player);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CatShareCard(spec: spec, catName: 'Luna', room: player.room),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final texts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(CatShareCard),
            matching: find.byType(Text),
          ),
        )
        .map((text) => text.data)
        .toSet();
    expect(texts, {'Luna', 'CAMERA • ${player.room}', 'Cat Paws Arena'});
    expect(find.text('Alex'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is MemoryImage,
      ),
      findsNothing,
      reason: 'the card must not contain a photo',
    );
  });

  test('avatar spec serializes and validates safely', () {
    const spec = AvatarSpec(
      fur: 4,
      pattern: 3,
      eyes: 1,
      ears: 3,
      accessory: 'acc_pirate_bandana',
      power: 'power_shadow_pounce',
    );
    final restored = AvatarSpec.fromJsonString(spec.toJsonString());
    expect(restored, spec);

    // Out-of-range values and unknown accessories fall back safely; a
    // legacy 's' species field is ignored — the avatar is always a cat.
    final bad = AvatarSpec.fromJson(const {
      's': 99,
      'f': -2,
      'p': 42,
      'e': 7,
      'r': 8,
      'a': 'not_a_sprite',
      'w': 'not_a_power',
    });
    expect(bad, const AvatarSpec());
    expect(AvatarSpec.fromJsonString('not json'), const AvatarSpec());
    expect(AvatarSpec.fromJsonString(null), const AvatarSpec());
  });

  test('legacy avatar JSON with a species field keeps the other fields', () {
    // Saves written before the species system was removed carried a
    // species index in 's'. It must parse without crashing and without
    // losing any other field; new serializations no longer write 's'.
    final spec = AvatarSpec.fromJsonString(
      '{"s":2,"f":4,"p":3,"e":1,"r":4,"a":"","w":"power_laser_chase"}',
    );
    expect(spec.fur, 4);
    expect(spec.pattern, 3);
    expect(spec.eyes, 1);
    expect(spec.ears, 4);
    expect(spec.power, 'power_laser_chase');
    expect(spec.toJson().containsKey('s'), isFalse);
  });

  testWidgets('avatar renders as a cat bust anchored to its shoulders', (
    tester,
  ) async {
    const spec = AvatarSpec(fur: 1, pattern: 2, eyes: 3, ears: 0);
    final render = await _renderCat(tester, AvatarAvatar(spec, size: 96));
    // Transparent corner, painted head centre and a painted bottom band —
    // the torso proves the head is anchored to a body, not pasted-on.
    expect(_alphaAt(render, 0, 0), 0);
    expect(_alphaAt(render, render.width ~/ 2, render.height * 3 ~/ 5), 255);
    expect(_alphaAt(render, render.width ~/ 2, render.height - 4), 255);
  });

  testWidgets('every avatar combination renders without exceptions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Wrap(
              children: [
                for (var fur = 0; fur < catFurColours.length; fur++)
                  for (var pattern = 0; pattern < catPatternCount; pattern++)
                    for (var eyes = 0; eyes < catEyeColours.length; eyes++)
                      for (var ears = 0; ears < avatarEarCount; ears++)
                        AvatarAvatar(
                          AvatarSpec(
                            fur: fur,
                            pattern: pattern,
                            eyes: eyes,
                            ears: ears,
                          ),
                          size: 24,
                        ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byType(AvatarAvatar),
      findsNWidgets(
        catFurColours.length *
            catPatternCount *
            catEyeColours.length *
            avatarEarCount,
      ),
    );
  });

  testWidgets('a fixed sample of avatar combinations produces images', (
    tester,
  ) async {
    for (var i = 0; i < 24; i++) {
      final spec = AvatarSpec(
        fur: (i * 5) % catFurColours.length,
        pattern: (i * 3) % catPatternCount,
        eyes: (i * 7) % catEyeColours.length,
        ears: (i * 2) % avatarEarCount,
      );
      final render = await _renderCat(tester, AvatarAvatar(spec, size: 64));
      expect(render.png.length, greaterThan(200), reason: 'avatar $i');
      expect(
        _alphaAt(render, render.width ~/ 2, render.height * 3 ~/ 5),
        255,
        reason: 'avatar $i centre is painted',
      );
    }
  });

  testWidgets('profile avatar picker offers the three cat arts and persists', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final player = Player(prefs);
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: ProfileScreen(player: player)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile-avatar-pick')));
    await tester.pumpAndSettle();
    for (final label in ['TZUKI', 'BUBBLE', 'CUSTOM', 'PISICA EDITATĂ']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('BUBBLE'));
    await tester.pumpAndSettle();
    expect(player.avatarArt, 'cat_bubble');
    expect(Player(prefs).avatarArt, 'cat_bubble');

    await tester.tap(find.byKey(const ValueKey('profile-avatar-pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PISICA EDITATĂ'));
    await tester.pumpAndSettle();
    expect(player.avatarArt, 'my_cat');
  });
}
