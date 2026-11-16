import 'package:flutter/foundation.dart';

import 'fake_backend.dart';
import 'firebase_backend.dart';
import 'match_store.dart';
import 'match_sync.dart';
import 'online_account.dart';
import 'online_backend.dart';
import 'rooms.dart';

/// `flutter run --dart-define=CPA_ONLINE_BACKEND=firebase`. Absent means
/// online is off and the app keeps showing it as unavailable.
const onlineBackendDefine = String.fromEnvironment('CPA_ONLINE_BACKEND');

enum OnlineMode {
  none,
  fake,
  firebase;

  /// `fake` is refused in release builds, so a fake never ships as online.
  static OnlineMode parse(String value, {required bool release}) =>
      switch (value) {
        'firebase' => firebase,
        'fake' when !release => fake,
        _ => none,
      };

  static OnlineMode get configured =>
      parse(onlineBackendDefine, release: kReleaseMode);
}

/// The online backends picked by the configured flag.
class OnlineServices {
  OnlineServices._(this.mode, this.auth, this.store, this.google, this.push);

  final OnlineMode mode;
  final AuthBackend auth;
  final CloudStore store;
  final GoogleAccountPicker google;

  /// Null in `fake` mode.
  final PushRegistration? push;

  late final account = OnlineAccount(auth, store);
  late final rooms = RoomService(store);

  /// Both stores implement [MatchStore].
  MatchStore get matches => store as MatchStore;

  /// Opens (or resumes after a restart) a friend match for the signed-in
  /// player.
  Future<MatchSession> openMatch(String matchId) =>
      MatchSession.open(matches, matchId, account.user!.uid);

  /// Returns null when online is off. Firebase is initialized only in
  /// `firebase` mode, so other builds never contact Firebase. Signs in
  /// anonymously.
  static Future<OnlineServices?> start([OnlineMode? mode]) async {
    switch (mode ?? OnlineMode.configured) {
      case OnlineMode.none:
        return null;
      case OnlineMode.fake:
        final cloud = FakeCloud();
        final services = OnlineServices._(
          OnlineMode.fake,
          FakeAuth(cloud),
          cloud,
          FakeGooglePicker(),
          null,
        );
        await services.account.start();
        return services;
      case OnlineMode.firebase:
        await initializeFirebase();
        final store = FirestoreCloudStore();
        final services = OnlineServices._(
          OnlineMode.firebase,
          FirebaseAuthBackend(),
          store,
          PlatformGooglePicker(),
          FcmPushRegistration(),
        );
        final user = await services.account.start();
        await store.syncClock(user.uid);
        return services;
    }
  }
}
