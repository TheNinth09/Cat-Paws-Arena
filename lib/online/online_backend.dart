/// Interfaces the online layer needs from a backend. The approved backend
/// is Firebase (docs/contract.md §7, `firebase_backend.dart`); [FakeCloud]
/// implements them in memory for tests.
library;

import 'emotes.dart';

class OnlineUser {
  const OnlineUser({required this.uid, required this.googleLinked});
  final String uid;
  final bool googleLinked;
  bool get isAnonymous => !googleLinked;
}

/// Result of the platform Google sign-in flow. [idToken] is what Firebase
/// needs; the fake only uses [googleUserId].
class GoogleCredential {
  const GoogleCredential(this.googleUserId, {this.idToken});
  final String googleUserId;
  final String? idToken;
}

abstract interface class AuthBackend {
  OnlineUser? get currentUser;
  Future<OnlineUser> signInAnonymously();

  /// Links Google to the current user, keeping the same uid.
  Future<OnlineUser> linkGoogle(GoogleCredential credential);

  /// Signs in to the user that [credential] was linked to earlier.
  Future<OnlineUser> signInWithGoogle(GoogleCredential credential);

  /// Confirms the current Google-linked user with a fresh sign-in, so a
  /// later delete cannot fail with `requiresRecentLogin`.
  Future<void> reauthenticate(GoogleCredential credential);
  Future<void> signOut();
  Future<void> deleteCurrentUser();
}

/// Shows the platform Google account picker.
abstract interface class GoogleAccountPicker {
  Future<GoogleCredential> pick();
  Future<void> signOut();
}

/// Your-turn push registration. Pushes carry only a match ID.
abstract interface class PushRegistration {
  /// Asks for notification permission and stores this device's token.
  /// Returns false when the player declined.
  Future<bool> enable(String uid);

  /// Removes this device's token.
  Future<void> disable(String uid);

  /// Match IDs from notifications the player tapped.
  Stream<String> get openedMatchIds;
}

class RoomRecord {
  const RoomRecord({
    required this.code,
    required this.hostUid,
    required this.createdAt,
    this.power = 0,
  });

  /// A room lives 24 hours (server time) or until a friend joins it.
  static const lifetime = Duration(hours: 24);

  final String code;
  final String hostUid;

  /// The host cat's chosen power index (0-2); carried into the match
  /// loadout at claim time.
  final int power;

  /// Server time the room was created.
  final DateTime createdAt;
  DateTime get expiresAt => createdAt.add(lifetime);

  /// The match a claim of this room creates. Both phones can derive it, and
  /// the security rules check it.
  String get matchId => '${code}_${createdAt.millisecondsSinceEpoch}';
}

enum RoomClaim { joined, notFound, expired, ownRoom }

/// The two players of a friend match created from a room.
class MatchLink {
  const MatchLink({
    required this.matchId,
    required this.roomCode,
    required this.hostUid,
    required this.guestUid,
  });
  final String matchId, roomCode, hostUid, guestUid;
}

class EmoteEvent {
  const EmoteEvent(this.senderUid, this.emote);
  final String senderUid;
  final Emote emote;
}

abstract interface class CloudStore {
  /// Server time. Device clocks are never authoritative.
  DateTime serverNow();
  Future<Map<String, Object?>?> readProfile(String uid);

  /// Writes [data] only if its `revision` is the stored revision + 1 (1 when
  /// nothing is stored); otherwise throws [OnlineErrorCode.saveConflict].
  Future<void> writeProfile(String uid, Map<String, Object?> data);

  /// Creates `rooms/{code}` stamped with server time; null when the code
  /// is taken. [power] is the host cat's chosen power index (0-2).
  Future<RoomRecord?> createRoom(String code, String hostUid, {int power = 0});
  Future<RoomRecord?> readRoom(String code);
  Future<void> deleteRoom(String code);

  /// Atomically claims [code] for [guestUid] (a Firestore transaction), so
  /// only one guest can join. On [RoomClaim.joined] the same transaction
  /// creates the match `room.matchId` and deletes the room; an expired room
  /// is deleted too. [power] is the guest cat's chosen power index (0-2).
  Future<(RoomClaim, RoomRecord?)> claimRoom(
    String code,
    String guestUid, {
    int power = 0,
  });

  /// Emits once a guest has claimed [room].
  Stream<MatchLink> watchJoin(RoomRecord room);

  /// Only preset [Emote]s exist; there is no way to send text.
  Future<void> sendEmote(String matchId, String senderUid, Emote emote);
  Stream<EmoteEvent> emotes(String matchId);

  /// Deletes what the client may delete: profile, devices, clock and open
  /// rooms of [uid]. Works without Cloud Functions; `onUserDeleted`
  /// repeats it server-side and anonymizes matches when deployed.
  Future<void> deleteUserData(String uid);
}
