import 'dart:math';

import 'online_backend.dart';
import 'online_errors.dart';
import 'room_code.dart';

class JoinedRoom {
  const JoinedRoom({
    required this.code,
    required this.hostUid,
    required this.guestUid,
    required this.matchId,
  });
  final String code, hostUid, guestUid, matchId;
}

/// Creates and joins friend rooms. A room lives [RoomRecord.lifetime]
/// (server time) or until a friend joins it.
class RoomService {
  RoomService(this.store, {this.random});

  static const maxAttempts = 8;

  final CloudStore store;
  final Random? random;

  Future<RoomRecord> createRoom(String hostUid) async {
    for (var i = 0; i < maxAttempts; i++) {
      final room = await store.createRoom(RoomCode.generate(random), hostUid);
      if (room != null) return room;
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
    final (claim, room) = await store.claimRoom(code, guestUid);
    return switch (claim) {
      RoomClaim.joined => JoinedRoom(
        code: code,
        hostUid: room!.hostUid,
        guestUid: guestUid,
        matchId: room.matchId,
      ),
      RoomClaim.notFound => throw const OnlineException(
        OnlineErrorCode.roomNotFound,
      ),
      RoomClaim.expired => throw const OnlineException(
        OnlineErrorCode.roomExpired,
      ),
      RoomClaim.ownRoom => throw const OnlineException(OnlineErrorCode.ownRoom),
    };
  }

  /// For the host: completes when a friend joins [room].
  Future<MatchLink> waitForGuest(RoomRecord room) =>
      store.watchJoin(room).first;

  Future<void> cancelRoom(RoomRecord room) => store.deleteRoom(room.code);
}
