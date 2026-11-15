import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cat_paws_arena/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cat_paws_arena/profile.dart';

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

  test('rewards, daily limits, purchases, tiers and persistence', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final p = Player(prefs);
    expect(p.claimDaily(), true);
    expect(p.claimDaily(), false);
    expect(p.coins, 700);
    expect(p.buy('hat', 300), true);
    expect(p.buy('hat', 300), false);
    expect(p.buy('expensive', 999), false);
    p.result(-1);
    expect(p.trophies, 0);
    p.trophies = 290;
    p.result(1);
    expect(p.tier, 1);
    expect(p.trophies, 320);
    expect(p.coins, 550);
    p.result(0);
    expect(p.trophies, 320);
    await p.save();
    final restored = Player(prefs);
    expect(restored.coins, p.coins);
    expect(restored.owned, contains('hat'));
    expect(restored.daily, p.today);
  });
}
