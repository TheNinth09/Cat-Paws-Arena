/// Interfaces the online layer needs from a backend. The approved backend
/// is Firebase (docs/contract.md §7); [FakeCloud] implements them in memory
/// until the Firebase project exists.
library;

class OnlineUser {
  const OnlineUser({required this.uid, required this.googleLinked});
  final String uid;
  final bool googleLinked;
  bool get isAnonymous => !googleLinked;
}

/// Result of the platform Google sign-in flow. Only the stable Google
/// account ID is used here.
class GoogleCredential {
  const GoogleCredential(this.googleUserId);
  final String googleUserId;
}

abstract interface class AuthBackend {
  OnlineUser? get currentUser;
  Future<OnlineUser> signInAnonymously();

  /// Links Google to the current user, keeping the same uid.
  Future<OnlineUser> linkGoogle(GoogleCredential credential);

  /// Signs in to the user that [credential] was linked to earlier.
  Future<OnlineUser> signInWithGoogle(GoogleCredential credential);
  Future<void> signOut();
  Future<void> deleteCurrentUser();
}

class RoomRecord {
  const RoomRecord({
    required this.code,
    required this.hostUid,
    required this.createdAt,
    required this.expiresAt,
  });
  final String code;
  final String hostUid;
  final DateTime createdAt;
  final DateTime expiresAt;
}

abstract interface class CloudStore {
  /// Server time. Device clocks are never authoritative.
  DateTime serverNow();
  Future<Map<String, Object?>?> readProfile(String uid);
  Future<void> writeProfile(String uid, Map<String, Object?> data);

  /// Returns false when a room with this code already exists.
  Future<bool> createRoom(RoomRecord room);
  Future<RoomRecord?> readRoom(String code);
  Future<void> deleteRoom(String code);

  /// Server-side deletion: profile, devices and open rooms of [uid].
  Future<void> deleteUserData(String uid);
}
