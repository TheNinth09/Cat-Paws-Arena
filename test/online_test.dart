import 'dart:math';

import 'package:cat_paws_arena/online/cloud_profile.dart';
import 'package:cat_paws_arena/online/emotes.dart';
import 'package:cat_paws_arena/online/fake_backend.dart';
import 'package:cat_paws_arena/online/online_account.dart';
import 'package:cat_paws_arena/online/online_backend.dart';
import 'package:cat_paws_arena/online/online_errors.dart';
import 'package:cat_paws_arena/online/room_code.dart';
import 'package:cat_paws_arena/online/rooms.dart';
import 'package:cat_paws_arena/profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Matcher throwsOnline(OnlineErrorCode code) =>
    throwsA(isA<OnlineException>().having((e) => e.code, 'code', code));

Future<Player> freshPlayer() async {
  SharedPreferences.setMockInitialValues({});
  return Player(await SharedPreferences.getInstance());
}

void main() {
  group('room codes', () {
    test('generated codes use six characters from the alphabet', () {
      final rng = Random(7);
      for (var i = 0; i < 2000; i++) {
        final code = RoomCode.generate(rng);
        expect(code, hasLength(6));
        expect(code.split('').every(RoomCode.alphabet.contains), isTrue);
        expect(RoomCode.isValid(code), isTrue);
      }
    });

    test('alphabet has no look-alike characters', () {
      expect(RoomCode.alphabet, hasLength(31));
      for (final c in ['I', 'L', 'O', '0', '1']) {
        expect(RoomCode.alphabet.contains(c), isFalse, reason: c);
      }
    });

    test('every alphabet character appears', () {
      final rng = Random(1);
      final seen = <String>{};
      for (var i = 0; i < 500; i++) {
        seen.addAll(RoomCode.generate(rng).split(''));
      }
      expect(seen, RoomCode.alphabet.split('').toSet());
    });

    test('normalize accepts typing variants and rejects bad codes', () {
      expect(RoomCode.normalize(' abc-23k '), 'ABC23K');
      expect(RoomCode.normalize('ABC 23K'), 'ABC23K');
      for (final bad in ['', 'ABC23', 'ABC23KX', 'ABC0DE', 'ABCIDE', 'AB-C2']) {
        expect(RoomCode.normalize(bad), isNull, reason: bad);
      }
    });
  });

  group('rooms over the fake transport', () {
    late DateTime now;
    late FakeCloud cloud;
    setUp(() {
      now = DateTime.utc(2026, 11, 15, 12);
      cloud = FakeCloud(clock: () => now);
    });

    test('a friend joins with the code and the room is consumed', () async {
      final rooms = RoomService(cloud, random: Random(3));
      final room = await rooms.createRoom('host');
      expect(room.expiresAt, now.add(const Duration(hours: 24)));
      final joined = await rooms.joinRoom(room.code.toLowerCase(), 'guest');
      expect(joined.hostUid, 'host');
      expect(joined.guestUid, 'guest');
      expect(
        () => rooms.joinRoom(room.code, 'third'),
        throwsOnline(OnlineErrorCode.roomNotFound),
      );
    });

    test('expired, own, unknown and malformed rooms are refused', () async {
      final rooms = RoomService(cloud, random: Random(4));
      final own = await rooms.createRoom('host');
      await expectLater(
        rooms.joinRoom(own.code, 'host'),
        throwsOnline(OnlineErrorCode.ownRoom),
      );
      await expectLater(
        rooms.joinRoom('OI01LL', 'guest'),
        throwsOnline(OnlineErrorCode.invalidRoomCode),
      );
      await expectLater(
        rooms.joinRoom('ZZZZZZ', 'guest'),
        throwsOnline(OnlineErrorCode.roomNotFound),
      );
      now = now.add(const Duration(hours: 24));
      await expectLater(
        rooms.joinRoom(own.code, 'guest'),
        throwsOnline(OnlineErrorCode.roomExpired),
      );
      expect(cloud.rooms, isEmpty);
    });

    test('two friends joining at once: only one gets the room', () async {
      final rooms = RoomService(cloud, random: Random(5));
      final room = await rooms.createRoom('host');
      final results = await Future.wait([
        for (final guest in ['g1', 'g2', 'g3'])
          rooms
              .joinRoom(room.code, guest)
              .then<Object>((j) => j, onError: (Object e) => e),
      ]);
      expect(results.whereType<JoinedRoom>(), hasLength(1));
      expect(
        results.whereType<OnlineException>().map((e) => e.code),
        everyElement(OnlineErrorCode.roomNotFound),
      );
    });

    test('a code collision picks a new code', () async {
      final first = await RoomService(cloud, random: Random(9)).createRoom('a');
      final second = await RoomService(
        cloud,
        random: Random(9),
      ).createRoom('b');
      expect(second.code, isNot(first.code));
      expect(cloud.rooms, hasLength(2));
    });

    test('gives up after repeated collisions', () async {
      await RoomService(cloud, random: _Fixed()).createRoom('a');
      await expectLater(
        RoomService(cloud, random: _Fixed()).createRoom('b'),
        throwsOnline(OnlineErrorCode.roomCodeExhausted),
      );
    });
  });

  group('account and cloud save', () {
    test('reinstall plus Google sign-in restores cat and progress', () async {
      final cloud = FakeCloud();
      final player = await freshPlayer();
      player
        ..name = 'Typed Name'
        ..photo = '/data/photo.png'
        ..trophies = 840
        ..coins = 1210
        ..cat = 'Custom'
        ..accessory = 'bow'
        ..fur = 3
        ..eyes = 2
        ..ears = 0
        ..pattern = 1
        ..power = 2
        ..owned = {'bow', 'daily_combo'}
        ..claims = {300, 800}
        ..daily = '2026-11-15'
        ..music = false
        ..english = true;
      await player.save();

      final account = OnlineAccount(FakeAuth(cloud), cloud);
      final anon = await account.start();
      expect(anon.isAnonymous, isTrue);
      final saved = await account.save(CloudProfile.fromPlayer(player));
      expect(saved.revision, 1);
      const google = GoogleCredential('google-123');
      final linked = await account.linkGoogle(google);
      expect(linked.uid, anon.uid);
      expect(linked.googleLinked, isTrue);

      final stored = cloud.profiles[anon.uid]!;
      expect(stored.containsKey('name'), isFalse);
      expect(stored.containsKey('photo'), isFalse);
      expect(stored.values.whereType<String>(), isNot(contains('Typed Name')));

      // Reinstall: empty local storage, new auth state, same cloud.
      final reinstalled = await freshPlayer();
      expect(reinstalled.trophies, 0);
      final again = OnlineAccount(FakeAuth(cloud), cloud);
      final restored = await again.restoreWithGoogle(google);
      expect(again.user!.uid, anon.uid);
      await restored!.applyTo(reinstalled);

      expect(reinstalled.trophies, 840);
      expect(reinstalled.coins, 1210);
      expect(reinstalled.cat, 'Custom');
      expect(reinstalled.accessory, 'bow');
      expect([reinstalled.fur, reinstalled.eyes, reinstalled.ears], [3, 2, 0]);
      expect([reinstalled.pattern, reinstalled.power], [1, 2]);
      expect(reinstalled.owned, {'bow', 'daily_combo'});
      expect(reinstalled.claims, {300, 800});
      expect(reinstalled.daily, '2026-11-15');
      expect(reinstalled.music, isFalse);
      expect(reinstalled.english, isTrue);
      expect(reinstalled.name, 'Alex');
      expect(reinstalled.photo, isNull);

      final reloaded = Player(reinstalled.prefs);
      expect(reloaded.trophies, 840);
      expect(reloaded.cat, 'Custom');
    });

    test('revisions increase on every save', () async {
      final cloud = FakeCloud();
      final account = OnlineAccount(FakeAuth(cloud), cloud);
      await account.start();
      final profile = CloudProfile.fromPlayer(await freshPlayer());
      expect((await account.save(profile)).revision, 1);
      expect((await account.save(profile)).revision, 2);
      expect((await account.load())!.revision, 2);
    });

    test('a Google account cannot be linked to two players', () async {
      final cloud = FakeCloud();
      const google = GoogleCredential('g');
      final first = OnlineAccount(FakeAuth(cloud), cloud);
      await first.start();
      await first.linkGoogle(google);
      final second = OnlineAccount(FakeAuth(cloud), cloud);
      await second.start();
      await expectLater(
        second.linkGoogle(google),
        throwsOnline(OnlineErrorCode.credentialInUse),
      );
    });

    test('Google sign-in without a link is refused', () async {
      final cloud = FakeCloud();
      await expectLater(
        OnlineAccount(
          FakeAuth(cloud),
          cloud,
        ).restoreWithGoogle(const GoogleCredential('none')),
        throwsOnline(OnlineErrorCode.noLinkedAccount),
      );
    });

    test('anonymous reinstall without Google starts a new account', () async {
      final cloud = FakeCloud();
      final a = await OnlineAccount(FakeAuth(cloud), cloud).start();
      final b = await OnlineAccount(FakeAuth(cloud), cloud).start();
      expect(b.uid, isNot(a.uid));
    });

    test('save without signing in is refused', () async {
      final cloud = FakeCloud();
      final profile = CloudProfile.fromPlayer(await freshPlayer());
      await expectLater(
        OnlineAccount(FakeAuth(cloud), cloud).save(profile),
        throwsOnline(OnlineErrorCode.notSignedIn),
      );
    });

    test('deleting the account removes cloud data, link and rooms', () async {
      final cloud = FakeCloud();
      const google = GoogleCredential('g-del');
      final account = OnlineAccount(FakeAuth(cloud), cloud);
      final user = await account.start();
      await account.save(CloudProfile.fromPlayer(await freshPlayer()));
      await account.linkGoogle(google);
      await RoomService(cloud).createRoom(user.uid);
      await RoomService(cloud).createRoom('someone-else');

      await account.deleteAccount();
      expect(account.user, isNull);
      expect(cloud.profiles, isEmpty);
      expect(cloud.googleToUid, isEmpty);
      expect(cloud.users.contains(user.uid), isFalse);
      expect(cloud.rooms.values.map((r) => r.hostUid), ['someone-else']);
      await expectLater(
        OnlineAccount(FakeAuth(cloud), cloud).restoreWithGoogle(google),
        throwsOnline(OnlineErrorCode.noLinkedAccount),
      );
    });
  });

  group('cloud save parsing', () {
    Future<Map<String, Object?>> valid() async =>
        CloudProfile.fromPlayer(await freshPlayer()).toJson();

    test('round trips', () async {
      final json = await valid();
      expect(CloudProfile.fromJson(json).toJson(), json);
    });

    test('rejects unknown keys such as a typed name', () async {
      final json = await valid()
        ..['name'] = 'Alex';
      expect(
        () => CloudProfile.fromJson(json),
        throwsOnline(OnlineErrorCode.invalidCloudSave),
      );
    });

    test('rejects wrong types, negatives and unknown schema', () async {
      final cases = <String, Object?>{
        'schemaVersion': 2,
        'trophies': -1,
        'coins': '5',
        'sfx': 1,
        'owned': 'bow',
        'claims': ['300'],
        'cat': 'x' * 65,
        'daily': 'a\nb',
      };
      for (final e in cases.entries) {
        final json = await valid()
          ..[e.key] = e.value;
        expect(
          () => CloudProfile.fromJson(json),
          throwsOnline(OnlineErrorCode.invalidCloudSave),
          reason: e.key,
        );
      }
    });
  });

  test('only preset emotes are accepted', () {
    for (final emote in Emote.values) {
      expect(Emote.fromWire(emote.wire), emote);
    }
    expect(Emote.values.map((e) => e.wire).toSet(), hasLength(6));
    for (final text in ['hi there', 'HELLO', '', null, 3]) {
      expect(Emote.fromWire(text), isNull);
    }
  });
}

class _Fixed implements Random {
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}
