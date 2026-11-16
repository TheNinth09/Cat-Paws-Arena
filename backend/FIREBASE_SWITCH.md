# Firebase backend (lane 5)

Status: **implemented behind the flag, not deployed.** The project is
`cat-paws-arena` (Blaze, Firestore `europe-west1`, Anonymous auth on);
`android/app/google-services.json` is on `main`. Nothing here deploys rules
or functions; the owner does that (§6).

## 1. The configured flag

```
flutter run --dart-define=CPA_ONLINE_BACKEND=firebase
```

| Value | Backends | Online UI |
| --- | --- | --- |
| absent / anything else (default) | none | "unavailable", as before |
| `fake` | `FakeAuth` + `FakeCloud` in memory | debug builds only; refused in release |
| `firebase` | `FirebaseAuthBackend` + `FirestoreCloudStore` + `FcmPushRegistration` | live |

- `lib/online/online_config.dart`: `OnlineMode.configured` reads the define;
  `OnlineServices.start()` returns null when online is off.
  `Firebase.initializeApp()` runs only in `firebase` mode, so other builds
  never contact Firebase. Start signs in anonymously and measures the
  server clock (`clocks/{uid}`).
- Nothing calls `OnlineServices.start()` yet: `lib/main.dart` is the
  orchestrator's file (request in `docs/requests.md`).
- Android applies `com.google.gms.google-services` only when
  `google-services.json` exists, and the manifest removes
  `FirebaseInitProvider`, so Firebase does not start at process launch
  (checked on the emulator: no `FirebaseApp` log in a default build).
- `.github/workflows/release.yml` builds with `CPA_ONLINE_BACKEND=firebase`
  and fails without `google-services.json`.

## 2. Dependencies

Approved by the orchestrator and pinned in `pubspec.yaml`:
`firebase_core 5.1.0`, `firebase_auth 7.0.1`, `cloud_firestore 7.1.0`,
`firebase_messaging 17.0.1`, `google_sign_in 7.2.0`. Never added:
`firebase_analytics`, `firebase_crashlytics`, `firebase_remote_config`,
`firebase_in_app_messaging`, `firebase_dynamic_links`, any ad or attribution
SDK (CI fails on them).

## 3. Client mapping (`lib/online/firebase_backend.dart`)

### `FirebaseAuthBackend`

| Method | Firebase | Notes |
| --- | --- | --- |
| `signInAnonymously()` | `signInAnonymously()` | default; enough for friend duels |
| `linkGoogle()` | `currentUser.linkWithCredential(GoogleAuthProvider.credential(idToken))` | same uid. `credential-already-in-use` → `credentialInUse` |
| `signInWithGoogle()` | `signInWithCredential` | a new user means Google was never linked: it is deleted and `noLinkedAccount` thrown |
| `reauthenticate()` | `user.reauthenticateWithCredential` | fresh Google sign-in before deleting a linked account |
| `deleteCurrentUser()` | `user.delete()` | `requires-recent-login` → `requiresRecentLogin` |

`OnlineAccount.deleteAccount({freshGoogle})` works without functions: for a
Google-linked account it first reauthenticates (without `freshGoogle` it
throws `requiresRecentLogin` before anything is deleted), then
`CloudStore.deleteUserData` removes the profile, devices, clock and open
rooms, then the Auth user is deleted. `onUserDeleted`, when deployed,
repeats the cleanup and anonymizes matches and emotes.

`OnlineAccount.linkGoogle` and `restoreWithGoogle` require a
`ParentGateApproval`, which only `ParentGateChallenge.answer` can create
(`lib/online/parent_gate.dart`). `showParentGate` is a plain dialog that
lane 4 places in settings.

`PlatformGooglePicker` uses `GoogleSignIn.instance.authenticate()`. It needs
the Google provider enabled and an OAuth web client in
`google-services.json`; the current file has none, so Google linking reports
`googleUnavailable` until the owner does §6.

### `FirestoreCloudStore`

| Method | Firestore |
| --- | --- |
| `readProfile` / `writeProfile` | `users/{uid}`; write in a transaction that requires `revision` = stored + 1, else `saveConflict` |
| `createRoom(code, host)` | transaction: refuse if `rooms/{code}` exists, else set `createdAt: serverTimestamp()`, `expiresAt` (TTL only); returns the record with the server time |
| `claimRoom(code, guest)` | **one transaction**: read room, check expiry/own room, create `matches/{code}_{createdAtMillis}`, delete room |
| `watchJoin(room)` | snapshots of `matches/{room.matchId}` |
| `sendEmote` / `emotes` | `matches/{id}/emotes`: `{emote: wire ID, from: uid, at: serverTimestamp()}` |
| `readMatch` / `watchMatch` | `matches/{id}`: seed, `config` fingerprint, versions, `final_first`/`final_second`, `flag`, `forfeitWinner` |
| `readMoves` / `watchMoves` | `matches/{id}/moves` ordered by `index`: `{index, by, slot, move, hashAfter, at}` |
| `appendMove` | transaction: `moveConflict` if `moves/{index}` exists, else create |
| `writeFinal` / `flagMatch` / `claimForfeit` | single-field updates the rules allow once |

### Match sync (`lib/online/match_sync.dart`)

`MatchSession.open(store, matchId, uid)` replays the whole log (resume after
a restart). `play(move)` applies the move with `arena_engine` and appends it
with its `stateHash`; a rejected swap is not sent. Opponent moves arrive by
`watch()` (Firestore listener) or `refresh()` (polling via `poll(every)` and
on app resume), are replayed and hash-checked; any mismatch flags the match.
After the last move each phone writes its `MatchFinal`; `counts` is true only
when both are equal and nothing is flagged. Push (`onMoveCreated`) is an
optimization: without functions, `watch`/`poll` still deliver every move.
The slow-play limit is 24 h from the last move (`roundLimit`); the waiting
player calls `claimForfeit()`. `liveMoveLimit` (30 s) is the suggested live
timer for the duel screen.

Expiry is always `createdAt + 24 h` in server time; rules enforce it with
`request.time`.

### `FcmPushRegistration`

- `firebase_messaging_auto_init_enabled=false` in the manifest: no token or
  installation ID is created until `enable(uid)` is called. The match flow
  calls it when a slow match starts.
- `enable` asks for `POST_NOTIFICATIONS`, calls `register()`, and stores the
  Firebase installation ID in `users/{uid}/devices/{installId}` as
  `{fid, platform, updatedAt}`.
- `openedMatchIds` yields the match ID of a tapped notification, after
  checking its format.

## 4. Server side (`backend/`)

- `firestore.rules`: checklist in `SECURITY_RULES.md`; 25 emulator tests in
  `test/rules.test.js` (`npm run test:rules`, demo project, CI job
  "Firestore rules and functions").
- `functions/src/index.ts` (region `europe-west1`):
  - `onUserDeleted` (Auth delete trigger) deletes the profile, devices,
    clock and rooms, and replaces
    the uid with `deleted` in matches and emotes.
  - `onMoveCreated` / `notifyTurn` send the your-turn push with
    `data: {matchId}` only; the text comes from
    `android/app/src/main/res/values*/strings.xml` (`cpa_turn_*`).
- `firebase.json`, `.firebaserc` (`cat-paws-arena`), `firestore.indexes.json`.

## 5. Tests

- `test/online_test.dart` runs every service against the fakes, which
  follow the same revision, claim and emote rules.
- The rules are tested on the emulator. A Dart test checks that the cat
  option counts, cats, profile keys and emote IDs in `firestore.rules`
  match the app.
- Not tested: the Dart Firebase classes against the emulator or the real
  project. That needs a device or emulator run with the flag.

## 6. Owner actions (lane 5 never deploys)

1. Deploy the rules: `firebase deploy --only firestore:rules` from `backend/`.
2. TTL policies are optional (not available on Spark). Expiry and the
   24 h limit are enforced by the client and the rules.
3. Deploy functions: `firebase deploy --only functions`.
   Needs Blaze and the Cloud Build and Eventarc APIs.
4. To enable Google linking:
   - turn on the Google provider in Firebase Auth;
   - add the SHA-1/SHA-256 of the debug key, the upload key and the Play
     app-signing key;
   - download `google-services.json` again, so it contains the OAuth web
     client.
5. Human review: Google sign-in for child accounts, Firebase under the
   Families policy, request-log retention (`FAMILIES_POLICY.md`).
