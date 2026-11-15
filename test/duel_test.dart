import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cat_paws_arena/main.dart';
import 'package:cat_paws_arena/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'artwork_test_support.dart';

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
            !name.startsWith('assets/fonts/'),
      ),
      isEmpty,
    );
    await tester.pumpWidget(const MaterialApp(home: StudioSplash()));
    expectCleanArtwork(tester);
  });

  testWidgets('VS, gameplay and result never render screen mockups', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final p = Player(await SharedPreferences.getInstance())
      ..name = 'UnNumeFoarteLungDeJucător';
    await tester.pumpWidget(MaterialApp(home: MatchScreen(player: p, mode: 0)));
    expectCleanArtwork(tester);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 100));
    expectCleanArtwork(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Renunță'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('RENUNȚĂ'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ÎNFRÂNGERE'), findsOneWidget);
    expectCleanArtwork(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
