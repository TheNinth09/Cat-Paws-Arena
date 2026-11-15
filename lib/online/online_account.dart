import 'cloud_profile.dart';
import 'online_backend.dart';
import 'online_errors.dart';
import 'parent_gate.dart';

/// Account lifecycle: anonymous start, optional Google link, cloud save of
/// the cat and progress, and in-app deletion.
class OnlineAccount {
  OnlineAccount(this.auth, this.store);

  final AuthBackend auth;
  final CloudStore store;

  OnlineUser? get user => auth.currentUser;

  OnlineUser get _signedIn =>
      auth.currentUser ??
      (throw const OnlineException(OnlineErrorCode.notSignedIn));

  /// Reuses the current session or starts an anonymous one.
  Future<OnlineUser> start() async =>
      auth.currentUser ?? await auth.signInAnonymously();

  /// Google is optional and only reachable after the parent gate.
  Future<OnlineUser> linkGoogle(
    GoogleCredential credential,
    ParentGateApproval approval,
  ) async {
    _signedIn;
    return auth.linkGoogle(credential);
  }

  /// After a reinstall: signs in with the linked Google account and returns
  /// the saved cat and progress, or null when nothing was saved yet.
  Future<CloudProfile?> restoreWithGoogle(
    GoogleCredential credential,
    ParentGateApproval approval,
  ) async {
    await auth.signInWithGoogle(credential);
    return load();
  }

  Future<CloudProfile?> load() async {
    final data = await store.readProfile(_signedIn.uid);
    return data == null ? null : CloudProfile.fromJson(data);
  }

  /// Saves [profile] with the next revision and returns the saved copy.
  Future<CloudProfile> save(CloudProfile profile) async {
    final uid = _signedIn.uid;
    final current = await store.readProfile(uid);
    final previous = current == null
        ? 0
        : CloudProfile.fromJson(current).revision;
    final next = profile.withRevision(previous + 1);
    await store.writeProfile(uid, next.toJson());
    return next;
  }

  /// Deletes every cloud record of the account, then the account itself.
  /// The caller clears local data afterwards.
  Future<void> deleteAccount() async {
    await store.deleteUserData(_signedIn.uid);
    await auth.deleteCurrentUser();
  }
}
