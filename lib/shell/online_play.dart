import '../online/online_account.dart';
import '../online/online_backend.dart';
import '../online/rooms.dart';

class OnlinePlayServices {
  const OnlinePlayServices({
    required this.account,
    required this.rooms,
    required this.googleCredential,
  });

  final OnlineAccount account;
  final RoomService rooms;
  final Future<GoogleCredential?> Function() googleCredential;
}

abstract final class OnlinePlay {
  static OnlinePlayServices? services;
}
