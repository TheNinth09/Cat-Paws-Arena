import 'online_backend.dart';
import 'online_errors.dart';

/// In-memory stand-in for the Firebase project, shared by every simulated
/// install. Used by tests and until `google-services.json` exists.
class FakeCloud implements CloudStore {
  FakeCloud({DateTime Function()? clock})
    : _clock = clock ?? (() => DateTime.now().toUtc());

  final DateTime Function() _clock;
  final Map<String, Map<String, Object?>> profiles = {};
  final Map<String, RoomRecord> rooms = {};
  final Map<String, String> googleToUid = {};
  final Set<String> users = {};
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
    profiles[uid] = _copy(data);
  }

  @override
  Future<bool> createRoom(RoomRecord room) async {
    if (rooms.containsKey(room.code)) return false;
    rooms[room.code] = room;
    return true;
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
    return (RoomClaim.joined, room);
  }

  @override
  Future<void> deleteUserData(String uid) async {
    profiles.remove(uid);
    rooms.removeWhere((_, room) => room.hostUid == uid);
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
    cloud.users.remove(user.uid);
    cloud.googleToUid.removeWhere((_, uid) => uid == user.uid);
    _user = null;
  }
}
