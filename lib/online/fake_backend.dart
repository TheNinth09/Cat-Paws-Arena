import 'dart:async';
import 'dart:math';

import 'package:arena_engine/arena_engine.dart';

import 'emotes.dart';
import 'match_store.dart';
import 'online_backend.dart';
import 'online_errors.dart';

/// In-memory stand-in for the Firebase project, shared by every simulated
/// install. Mirrors the security rules that matter for game logic.
class FakeCloud implements CloudStore, MatchStore {
  FakeCloud({DateTime Function()? clock, Random? random})
    : _clock = clock ?? (() => DateTime.now().toUtc()),
      _random = random ?? Random();

  final Random _random;
  final Map<String, MatchRecord> matchRecords = {};
  final Map<String, List<MoveRecord>> moveLog = {};
  final _matchChanges = StreamController<String>.broadcast(sync: true);

  final DateTime Function() _clock;
  final Map<String, Map<String, Object?>> profiles = {};
  final Map<String, RoomRecord> rooms = {};
  final Map<String, MatchLink> matches = {};
  final Map<String, List<EmoteEvent>> emoteLog = {};
  final Map<String, String> googleToUid = {};
  final Set<String> users = {};
  final _joins = StreamController<MatchLink>.broadcast(sync: true);
  final _emotes = StreamController<(String, EmoteEvent)>.broadcast(sync: true);
  int _nextUid = 0;

  String newUid() {
    final uid = 'fake-uid-${_nextUid++}';
    users.add(uid);
    return uid;
  }

  @override
  DateTime serverNow() => _clock();

  @override
  Future<Map<String, Object?>?> readProfile(String uid) async {
    final data = profiles[uid];
    return data == null ? null : _copy(data);
  }

  @override
  Future<void> writeProfile(String uid, Map<String, Object?> data) async {
    if (!users.contains(uid)) {
      throw const OnlineException(OnlineErrorCode.notSignedIn);
    }
    final stored = (profiles[uid]?['revision'] as int?) ?? 0;
    if (data['revision'] != stored + 1) {
      throw const OnlineException(OnlineErrorCode.saveConflict);
    }
    profiles[uid] = _copy(data);
  }

  @override
  Future<RoomRecord?> createRoom(String code, String hostUid) async {
    if (rooms.containsKey(code)) return null;
    return rooms[code] = RoomRecord(
      code: code,
      hostUid: hostUid,
      createdAt: serverNow(),
    );
  }

  @override
  Future<RoomRecord?> readRoom(String code) async => rooms[code];

  @override
  Future<void> deleteRoom(String code) async => rooms.remove(code);

  @override
  Future<(RoomClaim, RoomRecord?)> claimRoom(
    String code,
    String guestUid,
  ) async {
    final room = rooms[code];
    if (room == null) return (RoomClaim.notFound, null);
    if (!serverNow().isBefore(room.expiresAt)) {
      rooms.remove(code);
      return (RoomClaim.expired, room);
    }
    if (room.hostUid == guestUid) return (RoomClaim.ownRoom, room);
    rooms.remove(code);
    final match = MatchLink(
      matchId: room.matchId,
      roomCode: code,
      hostUid: room.hostUid,
      guestUid: guestUid,
    );
    matches[match.matchId] = match;
    matchRecords[match.matchId] = MatchRecord(
      matchId: match.matchId,
      roomCode: code,
      hostUid: room.hostUid,
      guestUid: guestUid,
      seed: _random.nextInt(1 << 31),
      config: const MatchConfig.duel().fingerprint,
      engineVersion: kEngineVersion,
      contractVersion: kMatchContractVersion,
    );
    _joins.add(match);
    return (RoomClaim.joined, room);
  }

  @override
  Stream<MatchLink> watchJoin(RoomRecord room) async* {
    final existing = matches[room.matchId];
    if (existing != null) {
      yield existing;
      return;
    }
    yield await _joins.stream.firstWhere((m) => m.matchId == room.matchId);
  }

  @override
  Future<void> sendEmote(String matchId, String senderUid, Emote emote) async {
    final match = matches[matchId];
    if (match == null ||
        (senderUid != match.hostUid && senderUid != match.guestUid)) {
      throw const OnlineException(OnlineErrorCode.notInMatch);
    }
    final event = EmoteEvent(senderUid, emote);
    (emoteLog[matchId] ??= []).add(event);
    _emotes.add((matchId, event));
  }

  @override
  Stream<EmoteEvent> emotes(String matchId) {
    StreamSubscription<(String, EmoteEvent)>? live;
    late final StreamController<EmoteEvent> out;
    out = StreamController<EmoteEvent>(
      onListen: () {
        (emoteLog[matchId] ?? const []).forEach(out.add);
        live = _emotes.stream
            .where((e) => e.$1 == matchId)
            .listen((e) => out.add(e.$2));
      },
      onCancel: () => live?.cancel(),
    );
    return out.stream;
  }

  MatchRecord _match(String id) =>
      matchRecords[id] ??
      (throw const OnlineException(OnlineErrorCode.notInMatch));

  void _update(String id, MatchRecord Function(MatchRecord m) change) {
    matchRecords[id] = change(_match(id));
    _matchChanges.add(id);
  }

  static MatchRecord _copyMatch(
    MatchRecord m, {
    Map<PlayerSlot, MatchFinal>? finals,
    MatchFlag? flag,
    PlayerSlot? forfeitWinner,
  }) => MatchRecord(
    matchId: m.matchId,
    roomCode: m.roomCode,
    hostUid: m.hostUid,
    guestUid: m.guestUid,
    seed: m.seed,
    config: m.config,
    engineVersion: m.engineVersion,
    contractVersion: m.contractVersion,
    finals: finals ?? m.finals,
    flag: flag ?? m.flag,
    forfeitWinner: forfeitWinner ?? m.forfeitWinner,
  );

  @override
  Future<MatchRecord?> readMatch(String matchId) async => matchRecords[matchId];

  @override
  Stream<MatchRecord> watchMatch(String matchId) {
    StreamSubscription<String>? live;
    late final StreamController<MatchRecord> out;
    out = StreamController<MatchRecord>(
      onListen: () {
        final m = matchRecords[matchId];
        if (m != null) out.add(m);
        live = _matchChanges.stream
            .where((id) => id == matchId)
            .listen((id) => out.add(matchRecords[id]!));
      },
      onCancel: () => live?.cancel(),
    );
    return out.stream;
  }

  @override
  Future<List<MoveRecord>> readMoves(String matchId) async =>
      List.of(moveLog[matchId] ?? const []);

  @override
  Stream<MoveRecord> watchMoves(String matchId, {int from = 0}) {
    StreamSubscription<String>? live;
    var next = from;
    late final StreamController<MoveRecord> out;
    void drain() {
      final log = moveLog[matchId] ?? const [];
      while (next < log.length) {
        out.add(log[next++]);
      }
    }

    out = StreamController<MoveRecord>(
      onListen: () {
        drain();
        live = _matchChanges.stream
            .where((id) => id == matchId)
            .listen((_) => drain());
      },
      onCancel: () => live?.cancel(),
    );
    return out.stream;
  }

  /// Mirrors the security rules: participant, own slot, next index only.
  @override
  Future<void> appendMove(String matchId, MoveRecord move) async {
    final m = _match(matchId);
    if (m.slotOf(move.uid) != move.slot) {
      throw const OnlineException(OnlineErrorCode.notInMatch);
    }
    final log = moveLog[matchId] ??= [];
    if (move.index < log.length) {
      throw const MatchException(MatchErrorCode.moveConflict);
    }
    if (move.index != log.length) {
      throw const OnlineException(OnlineErrorCode.backend, 'gap');
    }
    log.add(
      MoveRecord(
        index: move.index,
        uid: move.uid,
        slot: move.slot,
        move: Map.of(move.move),
        hashAfter: move.hashAfter,
        at: serverNow(),
      ),
    );
    _matchChanges.add(matchId);
  }

  @override
  Future<void> writeFinal(
    String matchId,
    PlayerSlot slot,
    MatchFinal result,
  ) async {
    final m = _match(matchId);
    if (m.finals.containsKey(slot)) return;
    _update(matchId, (m) => _copyMatch(m, finals: {...m.finals, slot: result}));
  }

  @override
  Future<void> flagMatch(String matchId, MatchFlag reason) async {
    if (_match(matchId).flag != null) return;
    _update(matchId, (m) => _copyMatch(m, flag: reason));
  }

  @override
  Future<void> claimForfeit(String matchId, PlayerSlot winner) async {
    final log = moveLog[matchId] ?? const [];
    final last = log.isEmpty ? null : log.last.at;
    if (last == null || serverNow().isBefore(last.add(roundLimit))) {
      throw const MatchException(MatchErrorCode.deadlineNotPassed);
    }
    _update(matchId, (m) => _copyMatch(m, forfeitWinner: winner));
  }

  /// Test hook: overwrite a logged move as a cheating client would.
  void tamperMove(String matchId, int index, MoveRecord replacement) {
    moveLog[matchId]![index] = replacement;
  }

  /// What the `onUserDeleted` function does server-side after the Auth user
  /// is deleted.
  void onUserDeleted(String uid) {
    profiles.remove(uid);
    rooms.removeWhere((_, room) => room.hostUid == uid);
    for (final e in matches.entries.toList()) {
      final m = e.value;
      if (m.hostUid != uid && m.guestUid != uid) continue;
      matches[e.key] = MatchLink(
        matchId: m.matchId,
        roomCode: m.roomCode,
        hostUid: m.hostUid == uid ? 'deleted' : m.hostUid,
        guestUid: m.guestUid == uid ? 'deleted' : m.guestUid,
      );
    }
  }

  static Map<String, Object?> _copy(Map<String, Object?> data) => {
    for (final e in data.entries)
      e.key: e.value is List ? List<Object?>.of(e.value as List) : e.value,
  };
}

/// Auth state of one app install. A reinstall is a new [FakeAuth] on the
/// same [FakeCloud].
class FakeAuth implements AuthBackend {
  FakeAuth(this.cloud);

  final FakeCloud cloud;
  OnlineUser? _user;

  /// Simulates Firebase refusing to delete a stale Google session.
  bool requireRecentLogin = false;

  @override
  OnlineUser? get currentUser => _user;

  @override
  Future<OnlineUser> signInAnonymously() async =>
      _user = OnlineUser(uid: cloud.newUid(), googleLinked: false);

  @override
  Future<OnlineUser> linkGoogle(GoogleCredential credential) async {
    final user = _user;
    if (user == null) throw const OnlineException(OnlineErrorCode.notSignedIn);
    final owner = cloud.googleToUid[credential.googleUserId];
    if (owner != null && owner != user.uid) {
      throw const OnlineException(OnlineErrorCode.credentialInUse);
    }
    cloud.googleToUid[credential.googleUserId] = user.uid;
    return _user = OnlineUser(uid: user.uid, googleLinked: true);
  }

  @override
  Future<OnlineUser> signInWithGoogle(GoogleCredential credential) async {
    final uid = cloud.googleToUid[credential.googleUserId];
    if (uid == null) {
      throw const OnlineException(OnlineErrorCode.noLinkedAccount);
    }
    return _user = OnlineUser(uid: uid, googleLinked: true);
  }

  @override
  Future<void> signOut() async => _user = null;

  @override
  Future<void> deleteCurrentUser() async {
    final user = _user;
    if (user == null) throw const OnlineException(OnlineErrorCode.notSignedIn);
    if (requireRecentLogin && user.googleLinked) {
      throw const OnlineException(OnlineErrorCode.requiresRecentLogin);
    }
    cloud.users.remove(user.uid);
    cloud.googleToUid.removeWhere((_, uid) => uid == user.uid);
    cloud.onUserDeleted(user.uid);
    _user = null;
  }
}

/// Picker that returns a fixed account, for tests and `fake` mode.
class FakeGooglePicker implements GoogleAccountPicker {
  FakeGooglePicker([this.googleUserId = 'fake-google']);
  final String googleUserId;

  @override
  Future<GoogleCredential> pick() async => GoogleCredential(googleUserId);

  @override
  Future<void> signOut() async {}
}
