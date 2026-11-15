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

  /// Another install saved first; load, merge and save again.
  saveConflict,

  /// Deleting a Google-linked account needs a fresh Google sign-in.
  requiresRecentLogin,

  /// Google sign-in is not configured for this build or failed to start.
  googleUnavailable,

  /// The player closed the Google sign-in sheet.
  cancelled,

  /// The user is not one of the two players of this match.
  notInMatch,

  /// Any other backend failure; [OnlineException.detail] has the code.
  backend,
}

class OnlineException implements Exception {
  const OnlineException(this.code, [this.detail]);
  final OnlineErrorCode code;
  final String? detail;

  @override
  String toString() =>
      'OnlineException(${code.name}${detail == null ? '' : ': $detail'})';
}
