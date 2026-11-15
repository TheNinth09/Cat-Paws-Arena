# Google Play Families policy notes (lane 5)

These notes record what the code and CI enforce today and what still needs
a person. They are not a compliance certification. COPPA, GDPR/GDPR-K and
Play Families compliance needs human review (`docs/contract.md` §7).

## Enforced automatically today

| Rule | Where | How it fails |
| --- | --- | --- |
| No advertising ID | `android/app/src/main/AndroidManifest.xml` removes `com.google.android.gms.permission.AD_ID` with `tools:node="remove"` | `.github/scripts/check_families_policy.sh` runs `aapt2 dump permissions` on the built APK and fails if `AD_ID` is present |
| No ad, analytics or attribution Dart packages | same script, on `pubspec.lock` | fails on `firebase_analytics`, `firebase_crashlytics`, `google_mobile_ads`, AppLovin, Unity Ads, AppsFlyer, Adjust and similar |
| No ad, analytics or attribution Android libraries | same script, on `:app:releaseRuntimeClasspath` | fails on `play-services-ads*`, `play-services-measurement*`, `firebase-analytics`, `firebase-crashlytics`, Facebook, AppLovin, Unity Ads, AppsFlyer, Adjust, ironSource, Branch |
| Only preset emotes | `lib/online/emotes.dart` | `Emote.fromWire` returns null for anything not in the list (tested) |
| Room codes are not text | `lib/online/room_code.dart` | 6 characters from a fixed alphabet (tested) |
| Typed name and photo never uploaded | `lib/online/cloud_profile.dart` | `CloudProfile` has no name or photo field; unknown keys are rejected (tested) |
| No tracked APK/AAB | `.github/workflows/ci.yml` | fails if `git ls-files` lists one |

The CI step runs on the debug APK on every push and pull request, and on the
release APK before a GitHub Release is published.

## Current Android permissions

- Main manifest: no permission requested; `AD_ID` explicitly removed.
- Debug/profile manifests: `INTERNET` (Flutter tooling), not in release.
- Will be added with Firebase (`backend/FIREBASE_SWITCH.md` §5):
  `INTERNET`, and `POST_NOTIFICATIONS` asked only when a slow match starts.
- Libraries can merge more; the merged manifest of the release APK is the
  source of truth for the Data safety form, not this list.

## Current dependencies to keep an eye on

- `share_plus` (approved for the cat share card): its Android manifest adds
  a non-exported `FileProvider` and a non-exported receiver, and no
  permission. Sharing goes through the system share sheet; the app does not
  learn where the card went. Nothing is uploaded by us.
- `image_picker`: only for the parked photo avatar. The contract says it
  must be removed before release and no photo is ever uploaded. Removal is
  the orchestrator's change in `pubspec.yaml` (plus the parked code owner).
- Firebase (not added yet): `firebase_core`, `firebase_auth`,
  `cloud_firestore`, `firebase_messaging`, `google_sign_in`. When they land,
  re-run the CI check and read the merged manifest; `AD_ID` must still be
  absent and no `play-services-measurement*` may appear.

## Text between players

- No text field reaches another player. Names visible to others will be
  preset IDs (`presetDisplayName`, orchestrator field in `lib/profile.dart`);
  the local custom name stays on the phone.
- Security rules reject any peer-visible string that is not a preset ID
  (`backend/SECURITY_RULES.md`).
- Push payloads carry only the match ID.

## Accounts

- Play starts anonymous and stays fully playable for friend duels without
  Google.
- Google linking is optional and behind a parent gate (lane 4 UI, requested
  in `docs/requests.md`).
- Account deletion is in the app (`OnlineAccount.deleteAccount`); the Play
  listing also needs a web deletion path. *Human/owner action.*

## Needs a person before release

- [ ] Whether Google sign-in is acceptable for child accounts in each target
      market, or must be hidden for them.
- [ ] Whether the Firebase SDKs in use meet the Play Families SDK
      requirements at release time (check Google's current list, not this
      file).
- [ ] Whether the anonymous Firebase user ID and request logs (IP, user
      agent, Google Cloud default retention) are acceptable under COPPA and
      GDPR for players under 13/16, and what the privacy policy says.
- [ ] Parent gate design and wording.
- [ ] Target audience and content declaration in Play Console (children and
      adults), drafted in slice 4 under `backend/release/`.
- [ ] Data safety form, drafted in slice 4, checked against the merged
      manifest and the Firestore fields actually written.
