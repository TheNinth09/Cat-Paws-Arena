# Release checklist (lane 5)

Only the orchestrator builds a release APK, and only after every item
below is done. Lanes never tag, publish, deploy or build release APKs
(`docs/plan.md` §8, `docs/contract.md` §7). Boxes are ticked by the person
who did the step, never by an agent for a human gate.

## A. Owner prerequisites

- [ ] Firebase project on the Blaze plan, Firestore in `europe-west1`,
      budget alert (backend/PROPOSAL.md §6 suggests 25 USD).
- [ ] `android/app/google-services.json` for `games.oneear.catpawsarena`
      provided (as a CI secret for the release job; not committed if the
      orchestrator prefers).
- [ ] Upload key created and kept outside the repo; Play App Signing
      enabled.
- [ ] GitHub secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
      `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
- [ ] Upload-key and app-signing-key SHA-1/SHA-256 added to the Firebase
      Android app (needed for Google sign-in).

## B. Code on `main`

- [ ] Firebase backend behind `CPA_ONLINE_BACKEND=firebase`
      (`backend/FIREBASE_SWITCH.md`), rules tests passing, and
      `OnlineServices.start()` called from `lib/main.dart`.
- [ ] Friend match done-when checks of lane 5 slice 3 pass (100 simulated
      matches agree; tampered log flagged; restart restore; reinstall
      restore).
- [ ] Every in-scope lane merged and integrated (`docs/plan.md` §8: no
      interim APKs for the owner).
- [ ] `image_picker` and parked photo-avatar code removed.
- [ ] `pubspec.yaml` version bumped (`x.y.z+build`); build number higher
      than any previous upload.
- [ ] CI green on `main`: `flutter analyze`, `flutter test`, `dart test` in
      `packages/arena_engine`, Android build, Families policy check.

## C. Backend (owner deploys; lane 5 prepares)

- [ ] Security rules with all items of `backend/SECURITY_RULES.md`, emulator
      tests passing, deployed.
- [ ] Indexes deployed.
- [ ] TTL policies: `rooms.expiresAt` (24 h), matches 30 days after end,
      events 90 days.
- [ ] Functions deployed in `europe-west1`: `onUserDeleted`,
      `onMoveCreated`, and the deadline forfeit (match slice).
- [ ] Google provider enabled, SHA fingerprints added, and
      `google-services.json` re-downloaded with the OAuth web client.
- [ ] Two real phones finish a friend match against the deployed backend
      (list of two-phone checks comes with slice 3).

## D. Store and policy (humans)

- [ ] Privacy policy published at a public URL (draft in
      `backend/release/`, slice 4).
- [ ] Data safety form matches what the code sends (slice 4 draft, checked
      against the merged manifest and Firestore fields).
- [ ] Target audience and content: children and adults; Families policy
      review (`backend/FAMILIES_POLICY.md`).
- [ ] Account deletion: in-app path and web form URL in Play Console.
- [ ] Parent gate reviewed.
- [ ] Human gate 5 evidence recorded (device performance, billing/privacy/
      store review, release approval). Not marked passed by an agent.

## E. Cutting the release (orchestrator)

1. Confirm A–D.
2. Tag `vX.Y.Z` matching `pubspec.yaml` and push the tag.
3. `.github/workflows/release.yml` then:
   - checks the tag against `pubspec.yaml`;
   - writes `android/key.properties` from the secrets;
   - runs `flutter test` and `flutter build apk --release`;
   - checks the application ID is `games.oneear.catpawsarena` and refuses an
     APK signed with `CN=Android Debug`;
   - runs the Families policy check on the release APK;
   - attaches the APK and its SHA-256 to the GitHub Release;
   - deletes the signing files from the runner.
4. Install the attached APK on a physical phone and verify the SHA-256.
5. Play Store upload (AAB) is a separate step; the current workflow builds
   an APK for GitHub Releases only. Adding an AAB job is a lane 5 change to
   request when the Play listing is ready.

## F. Known gaps today

- No release has ever run: the signing secrets are not configured.
- Google linking cannot work yet: the Google provider and OAuth client are
  not configured in the Firebase project.
- Players with the old `com.pawsandclaws.cat_paws_arena` app get the new ID
  as a separate app; there is no data migration between them.
