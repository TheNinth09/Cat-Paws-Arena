/// Firebase implementations of the online interfaces (docs/contract.md §7).
/// Used only when the build sets `CPA_ONLINE_BACKEND=firebase`
/// (`online_config.dart`). No Analytics, Crashlytics or ad SDKs.
library;

import 'dart:async';
import 'dart:math';

import 'package:arena_engine/arena_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'emotes.dart';
import 'match_store.dart';
import 'online_backend.dart';
import 'online_errors.dart';

/// Reads the project from `android/app/google-services.json`.
Future<void> initializeFirebase() => Firebase.initializeApp();

OnlineException _authError(FirebaseAuthException e) => switch (e.code) {
  'credential-already-in-use' ||
  'email-already-in-use' ||
  'provider-already-linked' => const OnlineException(
    OnlineErrorCode.credentialInUse,
  ),
  'requires-recent-login' => const OnlineException(
    OnlineErrorCode.requiresRecentLogin,
  ),
  _ => OnlineException(OnlineErrorCode.backend, e.code),
};

Future<T> _guard<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on FirebaseAuthException catch (e) {
    throw _authError(e);
  } on FirebaseException catch (e) {
    throw OnlineException(OnlineErrorCode.backend, e.code);
  }
}

class FirebaseAuthBackend implements AuthBackend {
  FirebaseAuthBackend([FirebaseAuth? auth])
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  static bool _hasGoogle(User user) =>
      user.providerData.any((p) => p.providerId == 'google.com');

  static OnlineUser? _user(User? user) => user == null
      ? null
      : OnlineUser(uid: user.uid, googleLinked: _hasGoogle(user));

  static AuthCredential _google(GoogleCredential credential) {
    final token = credential.idToken;
    if (token == null) {
      throw const OnlineException(OnlineErrorCode.googleUnavailable);
    }
    return GoogleAuthProvider.credential(idToken: token);
  }

  User get _current =>
      _auth.currentUser ??
      (throw const OnlineException(OnlineErrorCode.notSignedIn));

  @override
  OnlineUser? get currentUser => _user(_auth.currentUser);

  @override
  Future<OnlineUser> signInAnonymously() async =>
      _user((await _guard(_auth.signInAnonymously)).user)!;

  @override
  Future<OnlineUser> linkGoogle(GoogleCredential credential) async {
    final user = _current;
    final result = await _guard(
      () => user.linkWithCredential(_google(credential)),
    );
    return _user(result.user)!;
  }

  @override
  Future<OnlineUser> signInWithGoogle(GoogleCredential credential) async {
    var google = _google(credential);
    final current = _auth.currentUser;
    if (current != null && !_hasGoogle(current)) {
      // Probe with a link first, so a Google account that was never linked
      // does not replace (and lose) the current session. Checked by
      // provider, not isAnonymous, which a link + unlink can change.
      AuthCredential? linkedElsewhere;
      try {
        await current.linkWithCredential(google);
      } on FirebaseAuthException catch (e) {
        if (e.code != 'credential-already-in-use') throw _authError(e);
        linkedElsewhere = e.credential ?? google;
      }
      if (linkedElsewhere == null) {
        await _guard(() => current.unlink('google.com'));
        throw const OnlineException(OnlineErrorCode.noLinkedAccount);
      }
      google = linkedElsewhere;
    }
    final result = await _guard(() => _auth.signInWithCredential(google));
    if (result.additionalUserInfo?.isNewUser ?? false) {
      // Google was never linked: do not create a second account.
      await _guard(() async => result.user?.delete());
      throw const OnlineException(OnlineErrorCode.noLinkedAccount);
    }
    return _user(result.user)!;
  }

  @override
  Future<void> signOut() => _guard(_auth.signOut);

  @override
  Future<void> reauthenticate(GoogleCredential credential) {
    final user = _current;
    return _guard(() => user.reauthenticateWithCredential(_google(credential)));
  }

  @override
  Future<void> deleteCurrentUser() {
    final user = _current;
    return _guard(user.delete);
  }
}

class FirestoreCloudStore implements CloudStore, MatchStore {
  FirestoreCloudStore([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  Duration _offset = Duration.zero;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _rooms =>
      _db.collection('rooms');
  CollectionReference<Map<String, dynamic>> get _matches =>
      _db.collection('matches');

  /// Measures the device clock against server time once per session, so
  /// [serverNow] is close to what the security rules see.
  Future<void> syncClock(String uid) => _guard(() async {
    final ref = _db.collection('clocks').doc(uid);
    final before = DateTime.now().toUtc();
    await ref.set({'t': FieldValue.serverTimestamp()});
    final snap = await ref.get(const GetOptions(source: Source.server));
    final after = DateTime.now().toUtc();
    final server = snap.data()?['t'];
    if (server is Timestamp) {
      final local = before.add(after.difference(before) ~/ 2);
      _offset = server.toDate().toUtc().difference(local);
    }
  });

  @override
  DateTime serverNow() => DateTime.now().toUtc().add(_offset);

  static RoomRecord _room(String code, Map<String, dynamic> data) => RoomRecord(
    code: code,
    hostUid: data['hostUid'] as String,
    createdAt: (data['createdAt'] as Timestamp).toDate().toUtc(),
  );

  @override
  Future<Map<String, Object?>?> readProfile(String uid) => _guard(() async {
    final snap = await _users.doc(uid).get();
    return snap.data();
  });

  @override
  Future<void> writeProfile(String uid, Map<String, Object?> data) =>
      _guard(() async {
        final ref = _users.doc(uid);
        await _db.runTransaction((tx) async {
          final snap = await tx.get(ref);
          final stored = (snap.data()?['revision'] as int?) ?? 0;
          if (data['revision'] != stored + 1) {
            throw const OnlineException(OnlineErrorCode.saveConflict);
          }
          tx.set(ref, data);
        });
      });

  @override
  Future<RoomRecord?> createRoom(String code, String hostUid) => _guard(
    () async {
      final ref = _rooms.doc(code);
      final created = await _db.runTransaction((tx) async {
        if ((await tx.get(ref)).exists) return false;
        tx.set(ref, {
          'hostUid': hostUid,
          'createdAt': FieldValue.serverTimestamp(),
          // For the Firestore TTL policy only; expiry is createdAt + 24 h.
          'expiresAt': Timestamp.fromDate(serverNow().add(RoomRecord.lifetime)),
        });
        return true;
      });
      if (!created) return null;
      final snap = await ref.get(const GetOptions(source: Source.server));
      return _room(code, snap.data()!);
    },
  );

  @override
  Future<RoomRecord?> readRoom(String code) => _guard(() async {
    final data = (await _rooms.doc(code).get()).data();
    return data == null ? null : _room(code, data);
  });

  @override
  Future<void> deleteRoom(String code) =>
      _guard(() => _rooms.doc(code).delete());

  @override
  Future<(RoomClaim, RoomRecord?)> claimRoom(String code, String guestUid) =>
      _guard(
        () => _db.runTransaction((tx) async {
          final ref = _rooms.doc(code);
          final data = (await tx.get(ref)).data();
          if (data == null) return (RoomClaim.notFound, null);
          final room = _room(code, data);
          if (!serverNow().isBefore(room.expiresAt)) {
            tx.delete(ref);
            return (RoomClaim.expired, room);
          }
          if (room.hostUid == guestUid) return (RoomClaim.ownRoom, room);
          tx.set(_matches.doc(room.matchId), {
            'roomCode': code,
            'hostUid': room.hostUid,
            'guestUid': guestUid,
            'createdAt': FieldValue.serverTimestamp(),
            'seed': Random.secure().nextInt(1 << 31),
            'config': const MatchConfig.duel().fingerprint,
            'engineVersion': kEngineVersion,
            'contractVersion': kMatchContractVersion,
          });
          tx.delete(ref);
          return (RoomClaim.joined, room);
        }),
      );

  @override
  Stream<MatchLink> watchJoin(RoomRecord room) => _matches
      .doc(room.matchId)
      .snapshots()
      .where((snap) => snap.exists)
      .map(
        (snap) => MatchLink(
          matchId: snap.id,
          roomCode: room.code,
          hostUid: snap.data()!['hostUid'] as String,
          guestUid: snap.data()!['guestUid'] as String,
        ),
      );

  @override
  Future<void> sendEmote(String matchId, String senderUid, Emote emote) =>
      _guard(
        () => _matches.doc(matchId).collection('emotes').add({
          'emote': emote.wire,
          'from': senderUid,
          'at': FieldValue.serverTimestamp(),
        }),
      );

  @override
  Stream<EmoteEvent> emotes(String matchId) => _matches
      .doc(matchId)
      .collection('emotes')
      .orderBy('at')
      .snapshots()
      .expand((snap) sync* {
        for (final change in snap.docChanges) {
          if (change.type != DocumentChangeType.added) continue;
          final data = change.doc.data() ?? const {};
          final emote = Emote.fromWire(data['emote']);
          final from = data['from'];
          if (emote != null && from is String) yield EmoteEvent(from, emote);
        }
      });

  @override
  Future<void> deleteUserData(String uid) => _guard(() async {
    final batch = _db.batch();
    final devices = await _users.doc(uid).collection('devices').get();
    for (final doc in devices.docs) {
      batch.delete(doc.reference);
    }
    final rooms = await _rooms.where('hostUid', isEqualTo: uid).get();
    for (final doc in rooms.docs) {
      batch.delete(doc.reference);
    }
    batch
      ..delete(_users.doc(uid))
      ..delete(_db.collection('clocks').doc(uid));
    await batch.commit();
  });

  static PlayerSlot? _slot(Object? name) => PlayerSlot.values.asNameMap()[name];

  static MatchRecord _matchRecord(String id, Map<String, dynamic> d) =>
      MatchRecord(
        matchId: id,
        roomCode: d['roomCode'] as String,
        hostUid: d['hostUid'] as String,
        guestUid: d['guestUid'] as String,
        seed: d['seed'] as int,
        config: d['config'] as String,
        engineVersion: d['engineVersion'] as int,
        contractVersion: d['contractVersion'] as int,
        finals: {
          for (final slot in PlayerSlot.values)
            slot: ?MatchFinal.fromJson(d['final_${slot.name}']),
        },
        flag: MatchFlag.fromWire(d['flag']),
        forfeitWinner: _slot(d['forfeitWinner']),
      );

  static MoveRecord? _moveRecord(Map<String, dynamic> d) {
    final index = d['index'], by = d['by'], slot = _slot(d['slot']);
    final move = d['move'], hash = d['hashAfter'], at = d['at'];
    final next = d['next'];
    if (index is! int ||
        by is! String ||
        slot == null ||
        move is! Map ||
        hash is! String ||
        (next != 'none' && _slot(next) == null)) {
      return null;
    }
    return MoveRecord(
      index: index,
      uid: by,
      slot: slot,
      move: Map<String, Object?>.from(move),
      hashAfter: hash,
      next: _slot(next),
      at: at is Timestamp ? at.toDate().toUtc() : null,
    );
  }

  CollectionReference<Map<String, dynamic>> _moves(String matchId) =>
      _matches.doc(matchId).collection('moves');

  static String _moveId(int index) => index.toString().padLeft(3, '0');

  @override
  Future<MatchRecord?> readMatch(String matchId) => _guard(() async {
    final snap = await _matches.doc(matchId).get();
    final data = snap.data();
    return data == null ? null : _matchRecord(snap.id, data);
  });

  @override
  Stream<MatchRecord> watchMatch(String matchId) => _matches
      .doc(matchId)
      .snapshots()
      .where((snap) => snap.exists)
      .map((snap) => _matchRecord(snap.id, snap.data()!));

  @override
  Future<List<MoveRecord>> readMoves(String matchId) => _guard(() async {
    final snap = await _moves(matchId).orderBy('index').get();
    return [for (final doc in snap.docs) ?_moveRecord(doc.data())];
  });

  @override
  Stream<MoveRecord> watchMoves(String matchId, {int from = 0}) =>
      _moves(matchId)
          .where('index', isGreaterThanOrEqualTo: from)
          .orderBy('index')
          .snapshots()
          .expand((snap) sync* {
            for (final change in snap.docChanges) {
              if (change.type != DocumentChangeType.added) continue;
              final m = _moveRecord(change.doc.data() ?? const {});
              if (m != null) yield m;
            }
          });

  @override
  Future<void> appendMove(String matchId, MoveRecord move) => _guard(() async {
    final ref = _moves(matchId).doc(_moveId(move.index));
    await _db.runTransaction((tx) async {
      if ((await tx.get(ref)).exists) {
        throw const MatchException(MatchErrorCode.moveConflict);
      }
      tx.set(ref, {
        'index': move.index,
        'by': move.uid,
        'slot': move.slot.name,
        'move': move.move,
        'hashAfter': move.hashAfter,
        'next': move.next?.name ?? 'none',
        'at': FieldValue.serverTimestamp(),
      });
    });
  });

  @override
  Future<void> writeFinal(String matchId, PlayerSlot slot, MatchFinal result) =>
      _guard(
        () => _matches.doc(matchId).update({
          'final_${slot.name}': result.toJson(),
        }),
      );

  @override
  Future<void> flagMatch(String matchId, MatchFlag reason) => _guard(() async {
    final ref = _matches.doc(matchId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.data()?['flag'] != null) return;
      tx.update(ref, {'flag': reason.wire});
    });
  });

  /// The rules check the opponent's last move is older than [roundLimit].
  @override
  Future<void> claimForfeit(String matchId, PlayerSlot winner) =>
      _guard(() async {
        final last = await _moves(matchId)
            .orderBy('index', descending: true)
            .limit(1)
            .get();
        final data = last.docs.isEmpty ? null : last.docs.first.data();
        final at = data?['at'];
        if (data?['next'] != winner.other.name ||
            at is! Timestamp ||
            serverNow().isBefore(at.toDate().toUtc().add(roundLimit))) {
          throw const MatchException(MatchErrorCode.deadlineNotPassed);
        }
        await _matches.doc(matchId).update({
          'forfeitWinner': winner.name,
          'forfeitAfter': last.docs.first.id,
        });
      });
}

/// Google account picker. Needs the Google provider enabled in Firebase and
/// an OAuth web client in `google-services.json` (`default_web_client_id`).
class PlatformGooglePicker implements GoogleAccountPicker {
  bool _ready = false;

  @override
  Future<GoogleCredential> pick() async {
    final google = GoogleSignIn.instance;
    try {
      if (!_ready) {
        await google.initialize();
        _ready = true;
      }
      final account = await google.authenticate();
      return GoogleCredential(
        account.id,
        idToken: account.authentication.idToken,
      );
    } on GoogleSignInException catch (e) {
      throw OnlineException(
        e.code == GoogleSignInExceptionCode.canceled
            ? OnlineErrorCode.cancelled
            : OnlineErrorCode.googleUnavailable,
        e.description,
      );
    }
  }

  @override
  Future<void> signOut() async {
    if (_ready) await GoogleSignIn.instance.signOut();
  }
}

/// FCM token registration. Auto-init is off in the manifest, so no token
/// exists until the player starts a slow match and allows notifications.
class FcmPushRegistration implements PushRegistration {
  FcmPushRegistration([FirebaseFirestore? db, FirebaseMessaging? messaging])
    : _db = db ?? FirebaseFirestore.instance,
      _messaging = messaging ?? FirebaseMessaging.instance;

  static const _installIdKey = 'online_install_id';

  final FirebaseFirestore _db;
  final FirebaseMessaging _messaging;
  StreamSubscription<String>? _refresh;

  Future<DocumentReference<Map<String, dynamic>>> _device(String uid) async =>
      _db
          .collection('users')
          .doc(uid)
          .collection('devices')
          .doc(await _installId());

  static Future<String> _installId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_installIdKey);
    if (existing != null) return existing;
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    final id = String.fromCharCodes(
      List.generate(20, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
    await prefs.setString(_installIdKey, id);
    return id;
  }

  static Map<String, Object> _record(String fid) => {
    'fid': fid,
    'platform': 'android',
    'updatedAt': FieldValue.serverTimestamp(),
  };

  @override
  Future<bool> enable(String uid) => _guard(() async {
    final settings = await _messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return false;
    }
    await _messaging.setAutoInitEnabled(true);
    final ref = await _device(uid);
    await _refresh?.cancel();
    _refresh = _messaging.onRegistered.listen((t) => ref.set(_record(t)));
    await _messaging.register();
    return true;
  });

  @override
  Future<void> disable(String uid) => _guard(() async {
    await _refresh?.cancel();
    _refresh = null;
    await (await _device(uid)).delete();
    await _messaging.unregister();
    await _messaging.setAutoInitEnabled(false);
  });

  @override
  Stream<String> get openedMatchIds async* {
    final initial = await _messaging.getInitialMessage();
    final first = _matchId(initial);
    if (first != null) yield first;
    yield* FirebaseMessaging.onMessageOpenedApp
        .map(_matchId)
        .where((id) => id != null)
        .cast<String>();
  }

  static final _matchIdPattern = RegExp(r'^[A-Z2-9]{6}_\d{1,16}$');

  static String? _matchId(RemoteMessage? message) {
    final id = message?.data['matchId'];
    return id is String && _matchIdPattern.hasMatch(id) ? id : null;
  }
}
