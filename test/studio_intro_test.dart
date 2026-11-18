import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cat_paws_arena/boot_screen.dart';
import 'package:cat_paws_arena/profile.dart';
import 'package:cat_paws_arena/studio_intro.dart';

void main() {
  testWidgets('studio intro fades in, holds, fades out then shows boot', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final player = Player(await SharedPreferences.getInstance());
    await tester.pumpWidget(MaterialApp(home: StudioIntro(player: player)));

    // Pure-black stage with the studio artwork fading in.
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, Colors.black);
    expect(
      find.image(const AssetImage('assets/images/studio_logo.png')),
      findsOneWidget,
    );
    final introFade = find.descendant(
      of: find.byType(StudioIntro),
      matching: find.byType(FadeTransition),
    );
    expect(
      tester.widget<FadeTransition>(introFade).opacity.value,
      lessThan(1),
    );

    // During the hold the artwork is fully opaque; the cue is fire-and-forget
    // (audioplayers has no platform channel in tests — caught by the widget).
    await tester.pump(const Duration(milliseconds: 800));
    expect(
      tester.widget<FadeTransition>(introFade).opacity.value,
      1,
    );

    // After the full sequence the app hands off to the splash/boot screen.
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(Boot), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
