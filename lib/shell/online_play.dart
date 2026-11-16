import '../online/online_account.dart';
import '../online/online_backend.dart';
import '../online/online_config.dart';
import '../online/rooms.dart';

class OnlinePlayServices {
  const OnlinePlayServices({
    required this.account,
    required this.rooms,
    required this.googleCredential,
    this.online,
  });

  final OnlineAccount account;
  final RoomService rooms;
  final Future<GoogleCredential?> Function() googleCredential;

  /// Full online backend (match sync, emotes); null in tests that only
  /// exercise rooms/account, which keeps friend duels unavailable there.
  final OnlineServices? online;
}

abstract final class OnlinePlay {
  static OnlinePlayServices? services;
}
