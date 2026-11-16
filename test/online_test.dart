import 'dart:io';
import 'dart:math';

import 'package:arena_engine/arena_engine.dart';
import 'package:cat_paws_arena/catalog.dart';
import 'package:cat_paws_arena/online/cloud_profile.dart';
import 'package:cat_paws_arena/online/emotes.dart';
import 'package:cat_paws_arena/online/fake_backend.dart';
import 'package:cat_paws_arena/online/online_account.dart';
import 'package:cat_paws_arena/online/online_backend.dart';
import 'package:cat_paws_arena/online/match_store.dart';
import 'package:cat_paws_arena/online/match_sync.dart';
import 'package:cat_paws_arena/online/online_config.dart';
import 'package:cat_paws_arena/online/online_errors.dart';
import 'package:cat_paws_arena/online/parent_gate.dart';
import 'package:cat_paws_arena/online/room_code.dart';
import 'package:cat_paws_arena/online/rooms.dart';
import 'package:cat_paws_arena/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Matcher throwsOnline(OnlineErrorCode code) =>
    throwsA(isA<OnlineException>().having((e) => e.code, 'code', code));

/// What a grown-up gets by answering the gate.
ParentGateApproval approve() {
  final challenge = ParentGateChallenge.random(Random(1));
  return challenge.answer('${challenge.a * challenge.b}')!;
}

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
      expect(joined.matchId, room.matchId);
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
      final linked = await account.linkGoogle(google, approve());
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
      final restored = await again.restoreWithGoogle(google, approve());
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
      await first.linkGoogle(google, approve());
      final second = OnlineAccount(FakeAuth(cloud), cloud);
      await second.start();
      await expectLater(
        second.linkGoogle(google, approve()),
        throwsOnline(OnlineErrorCode.credentialInUse),
      );
    });

    test('Google sign-in without a link is refused', () async {
      final cloud = FakeCloud();
      await expectLater(
        OnlineAccount(
          FakeAuth(cloud),
          cloud,
        ).restoreWithGoogle(const GoogleCredential('none'), approve()),
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
      await account.linkGoogle(google, approve());
      final played = await RoomService(cloud).createRoom(user.uid);
      await RoomService(cloud).joinRoom(played.code, 'friend');
      await RoomService(cloud).createRoom(user.uid);
      await RoomService(cloud).createRoom('someone-else');

      await account.deleteAccount(freshGoogle: google);
      expect(account.user, isNull);
      expect(cloud.profiles, isEmpty);
      expect(cloud.googleToUid, isEmpty);
      expect(cloud.users.contains(user.uid), isFalse);
      expect(cloud.rooms.values.map((r) => r.hostUid), ['someone-else']);
      final match = cloud.matches[played.matchId]!;
      expect([match.hostUid, match.guestUid], ['deleted', 'friend']);
      await expectLater(
        OnlineAccount(
          FakeAuth(cloud),
          cloud,
        ).restoreWithGoogle(google, approve()),
        throwsOnline(OnlineErrorCode.noLinkedAccount),
      );
    });
  });

  group('account deletion refused', () {
    test('a stale Google session deletes nothing', () async {
      final cloud = FakeCloud();
      final auth = FakeAuth(cloud);
      final account = OnlineAccount(auth, cloud);
      final user = await account.start();
      await account.save(CloudProfile.fromPlayer(await freshPlayer()));
      await account.linkGoogle(const GoogleCredential('g-old'), approve());
      final room = await RoomService(cloud).createRoom(user.uid);
      auth.requireRecentLogin = true;
      await expectLater(
        account.deleteAccount(),
        throwsOnline(OnlineErrorCode.requiresRecentLogin),
      );
      expect(cloud.profiles.keys, [user.uid]);
      expect(cloud.rooms.keys, [room.code]);
      expect(account.user?.uid, user.uid);

      // With a fresh Google sign-in it deletes everything, no function needed.
      await account.deleteAccount(freshGoogle: const GoogleCredential('g-old'));
      expect(cloud.profiles, isEmpty);
      expect(cloud.rooms, isEmpty);
      expect(account.user, isNull);
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
        'cat': 'Unknown',
        'accessory': 'x' * 65,
        'fur': CloudProfile.furCount,
        'eyes': CloudProfile.eyesCount,
        'ears': CloudProfile.earsCount,
        'pattern': CloudProfile.patternCount,
        'power': 3,
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

    test('accepts every option the cat creator offers', () async {
      final json = await valid()
        ..['cat'] = 'Custom'
        ..['fur'] = CloudProfile.furCount - 1
        ..['eyes'] = CloudProfile.eyesCount - 1
        ..['ears'] = CloudProfile.earsCount - 1
        ..['pattern'] = CloudProfile.patternCount - 1;
      final profile = CloudProfile.fromJson(json);
      expect(profile.toJson(), json);
    });
  });

  group('friend match link and emotes', () {
    test('the host learns the match the guest created', () async {
      final cloud = FakeCloud();
      final rooms = RoomService(cloud);
      final room = await rooms.createRoom('host');
      final waiting = rooms.waitForGuest(room);
      final joined = await rooms.joinRoom(room.code, 'guest');
      final link = await waiting;
      expect(link.matchId, joined.matchId);
      expect([link.hostUid, link.guestUid], ['host', 'guest']);
      // Late listeners (e.g. after a restart) still get it.
      expect((await rooms.waitForGuest(room)).matchId, joined.matchId);
    });

    test('match ID is the code plus the server creation time', () {
      final room = RoomRecord(
        code: 'ABC234',
        hostUid: 'h',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1763208000123,
          isUtc: true,
        ),
      );
      expect(room.matchId, 'ABC234_1763208000123');
      expect(room.expiresAt, room.createdAt.add(const Duration(hours: 24)));
    });

    test('players exchange preset emotes; outsiders cannot', () async {
      final cloud = FakeCloud();
      final rooms = RoomService(cloud);
      final joined = await rooms.joinRoom(
        (await rooms.createRoom('host')).code,
        'guest',
      );
      final seen = <EmoteEvent>[];
      final sub = cloud.emotes(joined.matchId).listen(seen.add);
      await cloud.sendEmote(joined.matchId, 'guest', Emote.purr);
      await cloud.sendEmote(joined.matchId, 'host', Emote.goodGame);
      await expectLater(
        cloud.sendEmote(joined.matchId, 'stranger', Emote.hello),
        throwsOnline(OnlineErrorCode.notInMatch),
      );
      await pumpEventQueue();
      expect(seen.map((e) => (e.senderUid, e.emote)), [
        ('guest', Emote.purr),
        ('host', Emote.goodGame),
      ]);
      await sub.cancel();
      final replay = await cloud.emotes(joined.matchId).take(2).toList();
      expect(replay.map((e) => e.emote), [Emote.purr, Emote.goodGame]);
    });
  });

  group('friend match sync over the fake transport', () {
    Future<(FakeCloud, MatchSession, MatchSession)> start(int seed) async {
      final cloud = FakeCloud(random: Random(seed));
      final rooms = RoomService(cloud, random: Random(seed));
      final room = await rooms.createRoom('host');
      final joined = await rooms.joinRoom(room.code, 'guest');
      return (
        cloud,
        await MatchSession.open(cloud, joined.matchId, 'host'),
        await MatchSession.open(cloud, joined.matchId, 'guest'),
      );
    }

    Future<void> playOut(
      MatchSession host,
      MatchSession guest,
      ArenaBot a,
      ArenaBot b,
    ) async {
      var guard = 0;
      while (!host.isOver && host.flag == null && guard++ < 200) {
        final mover = host.isMyTurn ? host : guest;
        final bot = identical(mover, host) ? a : b;
        await mover.play(bot.chooseMove(mover.state));
        await (identical(mover, host) ? guest : host).refresh();
      }
    }

    test('100 matches: both phones agree on score and hash', () async {
      for (var i = 0; i < 100; i++) {
        final (_, host, guest) = await start(i);
        await playOut(
          host,
          guest,
          botForLevel(HouseCatLevel.values[i % 3], i),
          botForLevel(HouseCatLevel.values[(i + 1) % 3], i + 7),
        );
        await host.refresh();
        await guest.refresh();
        expect(host.isOver, isTrue, reason: 'match $i');
        expect(host.flag, isNull, reason: 'match $i');
        expect(stateHash(host.state), stateHash(guest.state));
        expect(host.state.scores, guest.state.scores);
        expect(host.counts && guest.counts, isTrue, reason: 'match $i');
      }
    });

    test('a tampered move log is rejected and the match flagged', () async {
      final (cloud, host, guest) = await start(3);
      final bot = botForLevel(HouseCatLevel.medium);
      await host.play(bot.chooseMove(host.state));
      final real = cloud.moveLog[host.matchId]!.first;
      cloud.tamperMove(
        host.matchId,
        0,
        MoveRecord(
          index: 0,
          uid: real.uid,
          slot: real.slot,
          move: real.move,
          hashAfter: '0000000000000000',
        ),
      );
      await guest.refresh();
      expect(guest.flag, MatchFlag.hashMismatch);
      expect(guest.movesApplied, 0);
      expect(cloud.matchRecords[host.matchId]!.flag, MatchFlag.hashMismatch);
      expect(guest.counts, isFalse);
      await expectLater(
        guest.play(bot.chooseMove(guest.state)),
        throwsA(
          isA<MatchException>().having(
            (e) => e.code,
            'code',
            MatchErrorCode.notYourTurn,
          ),
        ),
      );
    });

    test('a move out of turn is flagged', () async {
      final (cloud, host, guest) = await start(4);
      final bot = botForLevel(HouseCatLevel.easy, 1);
      final move = bot.chooseMove(guest.state);
      final res = applyMove(guest.state, move) as EngineOk<MoveResult>;
      await cloud.appendMove(
        host.matchId,
        MoveRecord(
          index: 0,
          uid: 'guest',
          slot: PlayerSlot.second,
          move: move.toJson(),
          hashAfter: res.value.hashAfter,
        ),
      );
      await host.refresh();
      expect(host.flag, MatchFlag.wrongTurn);
    });

    test('a restart in the middle of a round restores the match', () async {
      final (cloud, host, guest) = await start(5);
      final a = botForLevel(HouseCatLevel.hard),
          b = botForLevel(HouseCatLevel.medium);
      for (var i = 0; i < 4; i++) {
        final mover = host.isMyTurn ? host : guest;
        await mover.play(
          (identical(mover, host) ? a : b).chooseMove(mover.state),
        );
        await (identical(mover, host) ? guest : host).refresh();
      }
      expect(host.state.round, 1);
      final restored = await MatchSession.open(cloud, host.matchId, 'host');
      expect(restored.movesApplied, 4);
      expect(stateHash(restored.state), stateHash(host.state));
      await playOut(restored, guest, a, b);
      expect(restored.counts, isTrue);
    });

    test('outsiders cannot open the match; others cannot write', () async {
      final (cloud, host, _) = await start(6);
      await expectLater(
        MatchSession.open(cloud, host.matchId, 'stranger'),
        throwsOnline(OnlineErrorCode.notInMatch),
      );
      await expectLater(
        cloud.appendMove(
          host.matchId,
          const MoveRecord(
            index: 0,
            uid: 'stranger',
            slot: PlayerSlot.first,
            move: {},
            hashAfter: 'x',
          ),
        ),
        throwsOnline(OnlineErrorCode.notInMatch),
      );
    });

    test('forfeit only after the 24-hour limit', () async {
      var now = DateTime.utc(2026, 11, 16, 10);
      final cloud = FakeCloud(clock: () => now, random: Random(8));
      final rooms = RoomService(cloud);
      final joined = await rooms.joinRoom(
        (await rooms.createRoom('host')).code,
        'guest',
      );
      final host = await MatchSession.open(cloud, joined.matchId, 'host');
      final guest = await MatchSession.open(cloud, joined.matchId, 'guest');
      await host.play(botForLevel(HouseCatLevel.medium).chooseMove(host.state));
      await host.refresh();
      await expectLater(
        host.claimForfeit(),
        throwsA(
          isA<MatchException>().having(
            (e) => e.code,
            'code',
            MatchErrorCode.deadlineNotPassed,
          ),
        ),
      );
      now = now.add(roundLimit);
      await host.claimForfeit();
      expect(host.record.forfeitWinner, PlayerSlot.first);
      expect(host.isOver, isTrue);
      await guest.refresh();
      expect(guest.isOver, isTrue);
      expect(guest.record.forfeitWinner, PlayerSlot.first);
    });
  });

  group('parent gate', () {
    test('only the right product passes', () {
      final c = ParentGateChallenge.random(Random(7));
      expect(c.a, inInclusiveRange(6, 12));
      expect(c.b, inInclusiveRange(6, 12));
      expect(c.answer('${c.a * c.b}'), isNotNull);
      expect(c.answer(' ${c.a * c.b} '), isNotNull);
      for (final wrong in ['', 'abc', '${c.a + c.b}', '${c.a * c.b + 1}']) {
        expect(c.answer(wrong), isNull, reason: wrong);
      }
      expect(c.prompt(english: true), contains('${c.a} × ${c.b}'));
      expect(c.prompt(english: false), startsWith('Doar pentru adulți'));
    });

    testWidgets('dialog returns approval only for the right answer', (
      tester,
    ) async {
      final results = <ParentGateApproval?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(
                await showParentGate(context, english: true, random: Random(2)),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      final c = ParentGateChallenge.random(Random(2));
      for (final input in ['1', '${c.a * c.b}']) {
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('parentGateAnswer')),
          input,
        );
        await tester.tap(find.byKey(const Key('parentGateOk')));
        await tester.pumpAndSettle();
      }
      expect(results, hasLength(2));
      expect(results.first, isNull);
      expect(results.last, isNotNull);
    });
  });

  group('cloud save conflicts', () {
    test('a stale install cannot overwrite a newer save', () async {
      final cloud = FakeCloud();
      final account = OnlineAccount(FakeAuth(cloud), cloud);
      final user = await account.start();
      final profile = CloudProfile.fromPlayer(await freshPlayer());
      await account.save(profile);
      await expectLater(
        cloud.writeProfile(user.uid, profile.withRevision(1).toJson()),
        throwsOnline(OnlineErrorCode.saveConflict),
      );
      expect((await account.save(profile)).revision, 2);
    });
  });

  group('configured backend flag', () {
    test('only firebase and (debug) fake turn online on', () {
      expect(OnlineMode.parse('', release: false), OnlineMode.none);
      expect(OnlineMode.parse('none', release: false), OnlineMode.none);
      expect(OnlineMode.parse('firebase', release: true), OnlineMode.firebase);
      expect(OnlineMode.parse('fake', release: false), OnlineMode.fake);
      expect(OnlineMode.parse('fake', release: true), OnlineMode.none);
      expect(OnlineMode.parse('Firebase', release: false), OnlineMode.none);
      expect(OnlineMode.configured, OnlineMode.none);
    });

    test('none starts nothing; fake signs in anonymously', () async {
      expect(await OnlineServices.start(OnlineMode.none), isNull);
      final services = (await OnlineServices.start(OnlineMode.fake))!;
      expect(services.auth.currentUser!.isAnonymous, isTrue);
      expect(services.push, isNull);
      final credential = await services.google.pick();
      final linked = await services.account.linkGoogle(credential, approve());
      expect(linked.googleLinked, isTrue);
    });
  });

  test('Firestore rules allow the same values as the app', () async {
    final rules = File('backend/firestore.rules').readAsStringSync();
    int count(String field) => int.parse(
      RegExp('inRange\\(d\\.$field, (\\d+)\\)').firstMatch(rules)!.group(1)!,
    );
    expect(count('fur'), CloudProfile.furCount);
    expect(count('eyes'), CloudProfile.eyesCount);
    expect(count('ears'), CloudProfile.earsCount);
    expect(count('pattern'), CloudProfile.patternCount);
    expect(count('power'), powers.length);
    for (final cat in CloudProfile.cats) {
      expect(rules, contains("'$cat'"));
    }
    final emotes = RegExp(r"emote in\s*\[([^\]]*)\]")
        .firstMatch(rules)!
        .group(1)!;
    expect(
      RegExp(r"'([a-z_]+)'").allMatches(emotes).map((m) => m.group(1)).toSet(),
      Emote.values.map((e) => e.wire).toSet(),
    );
    for (final key in CloudProfile.fromPlayer(
      await freshPlayer(),
    ).toJson().keys) {
      expect(rules, contains("'$key'"), reason: key);
    }
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
