import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void expectCleanArtwork(WidgetTester tester) {
  final assets = tester
      .widgetList<Image>(find.byType(Image))
      .map((image) => image.image)
      .whereType<AssetImage>()
      .map((image) => image.assetName);
  expect(
    assets.where(
      (name) =>
          !name.startsWith('assets/generated/') &&
          !name.startsWith('assets/images/'),
    ),
    isEmpty,
  );
}
