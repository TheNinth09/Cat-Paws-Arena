import 'dart:math';

import 'online_backend.dart';
import 'online_errors.dart';
import 'room_code.dart';

class JoinedRoom {
  const JoinedRoom({
    required this.code,
    required this.hostUid,
    required this.guestUid,
  });
  final String code, hostUid, guestUid;
}

/// Creates and joins friend rooms. A room lives 24 hours (server time) or
/// until a friend joins it.
class RoomService {
  RoomService(this.store, {this.random});

  static const lifetime = Duration(hours: 24);
  static const maxAttempts = 8;

  final CloudStore store;
  final Random? random;

  Future<RoomRecord> createRoom(String hostUid) async {
    for (var i = 0; i < maxAttempts; i++) {
      final now = store.serverNow();
      final room = RoomRecord(
        code: RoomCode.generate(random),
        hostUid: hostUid,
        createdAt: now,
        expiresAt: now.add(lifetime),
      );
      if (await store.createRoom(room)) return room;
    }
    throw const OnlineException(OnlineErrorCode.roomCodeExhausted);
  }

  /// [input] is what the player typed; spaces, dashes and lower case are
  /// accepted.
  Future<JoinedRoom> joinRoom(String input, String guestUid) async {
    final code = RoomCode.normalize(input);
    if (code == null) {
      throw const OnlineException(OnlineErrorCode.invalidRoomCode);
    }
    final room = await store.readRoom(code);
    if (room == null) throw const OnlineException(OnlineErrorCode.roomNotFound);
    if (!store.serverNow().isBefore(room.expiresAt)) {
      await store.deleteRoom(code);
      throw const OnlineException(OnlineErrorCode.roomExpired);
    }
    if (room.hostUid == guestUid) {
      throw const OnlineException(OnlineErrorCode.ownRoom);
    }
    await store.deleteRoom(code);
    return JoinedRoom(code: code, hostUid: room.hostUid, guestUid: guestUid);
  }

  Future<void> cancelRoom(RoomRecord room) => store.deleteRoom(room.code);
}
