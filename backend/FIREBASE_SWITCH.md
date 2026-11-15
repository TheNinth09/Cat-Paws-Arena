# Switching the online layer from fakes to Firebase (lane 5)

Status: **not started on purpose.** No Firebase SDK, no `google-services.json`
and no Firebase Gradle plugin are in the repo. This file is the plan for the
day both of these are true:

1. `android/app/google-services.json` for `games.oneear.catpawsarena` exists
   (owner action, `docs/requests.md`), and
2. the orchestrator approves the pubspec lines below.

Until then the app runs only on `FakeAuth`/`FakeCloud`
(`lib/online/fake_backend.dart`), and every online surface keeps saying the
service is unavailable (AGENTS.md).

## 1. What stays the same

The online code depends only on two interfaces in
`lib/online/online_backend.dart`:

- `AuthBackend`: anonymous sign-in, Google link/restore, sign-out, delete.
- `CloudStore`: server time, profile read/write, rooms, atomic room claim,
  server-side user-data deletion.

`OnlineAccount`, `RoomService`, `CloudProfile`, `RoomCode` and `Emote` do not
change. `test/online_test.dart` keeps running against the fakes; the Firebase
classes get their own emulator tests (§6) and are never used by unit tests.

## 2. The configured flag

One compile-time switch, default off:

```
flutter run --dart-define=CPA_ONLINE_BACKEND=firebase
```

| Value | Backend | Online UI |
| --- | --- | --- |
| absent / `none` (default) | none | "unavailable", as today |
| `fake` | `FakeAuth` + `FakeCloud`, in memory | debug builds only, never in release |
| `firebase` | `FirebaseAuthBackend` + `FirestoreCloudStore` | live |

Rules for the switch:

- It lives in a new `lib/online/online_config.dart`: a
  `String.fromEnvironment('CPA_ONLINE_BACKEND')` constant and one factory
  returning `(AuthBackend, CloudStore)?`. Nothing else reads the define.
- `Firebase.initializeApp()` runs only when the value is `firebase`, so a
  build without the define never opens a network connection to Firebase.
- `fake` is refused in release mode (`kReleaseMode`), so a fake can never
  ship as "online".
- Android: the `com.google.gms.google-services` Gradle plugin is applied in
  `android/app/build.gradle.kts` only when `google-services.json` exists,
  the same pattern as `key.properties`. Local builds and CI without the file
  keep working.
- The release workflow builds with `CPA_ONLINE_BACKEND=firebase` and fails
  if `google-services.json` was not provided (as a secret), because the
  first public release must include friend duels (contract §7).

## 3. Dependencies to request (after approval)

Already requested in `docs/requests.md`; the orchestrator's answer there is
that it approves them once the JSON exists: `firebase_core`, `firebase_auth`, `cloud_firestore`,
`firebase_messaging`, `google_sign_in`. Exact versions are pinned in the PR
that adds them, after checking they build with the current Flutter, AGP and
Kotlin versions in `android/settings.gradle.kts`.

Not added, ever: `firebase_analytics`, `firebase_crashlytics`,
`firebase_remote_config`, `firebase_in_app_messaging`,
`firebase_dynamic_links`, any ad or attribution SDK. The Families CI check
(`.github/scripts/check_families_policy.sh`) already fails on them.

## 4. Mapping each interface method

### `FirebaseAuthBackend implements AuthBackend`

| Method | Firebase call | Notes |
| --- | --- | --- |
| `currentUser` | `FirebaseAuth.instance.currentUser` | `googleLinked` = a provider with ID `google.com` is present |
| `signInAnonymously()` | `signInAnonymously()` | default for every player |
| `linkGoogle()` | `GoogleSignIn` → `GoogleAuthProvider.credential(idToken: …)` → `currentUser.linkWithCredential` | keeps the uid. `credential-already-in-use` → `OnlineErrorCode.credentialInUse`. Behind the parent gate (lane 4). |
| `signInWithGoogle()` | `signInWithCredential` | if `additionalUserInfo.isNewUser`, delete that new user and throw `noLinkedAccount`, same as the fake |
| `signOut()` | `GoogleSignIn.signOut()` + `FirebaseAuth.signOut()` | |
| `deleteCurrentUser()` | local sign-out only | the Auth user is deleted by the `deleteAccount` function (below), which avoids `requires-recent-login` |

`GoogleCredential` gains the ID token field (lane 5 file). The Google email
and name stay inside Firebase Auth; the app never copies them into
Firestore or shows them to another player.

### `FirestoreCloudStore implements CloudStore`

| Method | Firestore | Notes |
| --- | --- | --- |
| `serverNow()` | offset from a `serverTimestamp()` read at start | display and timers only; rules use `request.time` as the authority |
| `readProfile(uid)` | `users/{uid}` get | |
| `writeProfile(uid, data)` | `users/{uid}` set in a transaction | transaction checks `revision` = stored + 1, so two phones can no longer silently overwrite each other (open point from slice 3a) |
| `createRoom(room)` | transaction: get `rooms/{code}`, return false if it exists, else set | `createdAt` = `request.time` and `expiresAt` = `createdAt + 24h` are enforced by rules, not trusted from the client |
| `readRoom(code)` | `rooms/{code}` get | single-document get only; listing rooms is denied |
| `deleteRoom(code)` | delete | host only |
| `claimRoom(code, guestUid)` | **one transaction**: read the room, check expiry and own room, delete the room and create `matches/{id}` | this is what makes "only one guest joins" true on the server; the fake already models it |
| `deleteUserData(uid)` | callable function `deleteAccount` (`europe-west1`) | deletes `users/{uid}`, devices, open rooms and events, writes `deleted` in place of the uid in matches, then deletes the Auth user |

### Not in the interfaces yet

Matches, moves, emotes and push tokens arrive with the match part of slice 3
(engine is on main since 0edc6d1). They get their own interface in
`lib/online/` with a fake first, then a Firestore implementation behind the
same flag.

## 5. Android wiring that comes with the switch

- `INTERNET` is today only in the debug/profile manifests. The main manifest
  gets it in the same PR that turns Firebase on, not earlier, so the release
  build does not ask for network access while nothing uses it.
- `POST_NOTIFICATIONS` (API 33+) is declared then too, and requested at
  runtime only when the player starts a slow match (backend/PROPOSAL.md §5).
- The `AD_ID` removal stays; the CI check runs on the APK with the Firebase
  libraries merged in.

## 6. How the Firebase classes will be tested

- Firebase Local Emulator Suite (Auth, Firestore, Functions) with a
  `demo-` project ID, so no real project, data or deploy is involved.
- The same scenarios as `test/online_test.dart` run against the emulator:
  anonymous start, link, reinstall restore, revisions, room create/join,
  three concurrent joins with one winner, expiry, deletion.
- Security-rules tests from `backend/SECURITY_RULES.md`.
- Running the emulator in CI needs Node and Java on the runner; that is a
  new job in `.github/workflows/ci.yml`, added in the same PR.

## 7. What only the owner or a human can do

- Create the Firebase project (Blaze, budget alert) and download
  `google-services.json`.
- Add the SHA-1/SHA-256 of the upload key and of the Play app-signing key in
  the Firebase console, or Google sign-in fails on release builds.
- Deploy rules, indexes, TTL policies and functions. Lane 5 never deploys.
- Human review: Google sign-in for the child audience, Firebase SDKs under
  the Families policy, request-log retention (`backend/FAMILIES_POLICY.md`).
