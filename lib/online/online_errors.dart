enum OnlineErrorCode {
  notSignedIn,
  credentialInUse,
  noLinkedAccount,
  invalidRoomCode,
  roomNotFound,
  roomExpired,
  ownRoom,
  roomCodeExhausted,
  invalidCloudSave,
}

class OnlineException implements Exception {
  const OnlineException(this.code, [this.detail]);
  final OnlineErrorCode code;
  final String? detail;

  @override
  String toString() =>
      'OnlineException(${code.name}${detail == null ? '' : ': $detail'})';
}
