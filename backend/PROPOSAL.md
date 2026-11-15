# Backend proposal: friend duels (lane 5, slice 2)

Status: **proposal for orchestrator approval**. No backend SDK, service, or
project exists yet. Nothing here is implemented, and nothing here certifies
policy compliance. Items marked *needs human review* need the owner or
qualified policy/legal review before release.

## 1. Recommendation

**Firebase**, one project, Firestore in a single EU region (`europe-west1`):

| Need | Firebase product | Client package (to be justified in slice 3) |
| --- | --- | --- |
| Account | Authentication: anonymous sign-in, linkable to Google | `firebase_core`, `firebase_auth`, `google_sign_in` |
| Cloud save, rooms, matches | Cloud Firestore with security rules | `cloud_firestore` |
| "Your turn" push | Cloud Messaging (FCM), sent by a Cloud Function | `firebase_messaging` |
| Round deadlines, push fan-out, account deletion | Cloud Functions (2nd gen, TypeScript) | none on the client |

Not used: Google Analytics for Firebase (`firebase_analytics`), Crashlytics,
Remote Config, A/B Testing, In-App Messaging, Dynamic Links. App Check with
Play Integrity is an optional later addition. The Blaze (pay-as-you-go) plan
is needed only for Cloud Functions. A budget alert is set at the start.

Why Firebase: anonymous auth with in-place linking to Google keeps the same
user ID, so the cloud save survives the link. Firestore listeners give live
play and offline persistence for slow play with no server to run. FCM is the
Android push channel anyway. All of it has maintained FlutterFire packages.

## 2. Alternative: Supabase (half page)

Supabase offers Postgres with row-level security, anonymous sign-in with
linking to Google, Realtime channels, and Edge Functions.

| | Firebase | Supabase |
| --- | --- | --- |
| Anonymous → Google, same user ID | Yes (`linkWithCredential`) | Yes (`linkIdentity`) |
| Realtime + offline | Firestore listeners, offline cache built in | Realtime over websockets; offline cache is ours to build |
| Push | FCM built in | No push service; we would still need FCM |
| Access rules | Firestore rules language | SQL row-level security (more expressive) |
| Scheduled deadlines | Cloud Scheduler + Functions | `pg_cron` + Edge Functions |
| Cost at 1,000 daily players | About free to a few USD/month (§5) | Free tier pauses idle projects; Pro is a flat ~25 USD/month |
| Lock-in | Proprietary data model | Postgres, can self-host |
| Families/data review | Google SDKs, Play-familiar disclosures | Smaller SDK surface, but still needs FCM |

Supabase is the better choice if we later want server-side validation in SQL
or to leave the vendor. For this scope (friend codes, async turns, push) it
adds FCM anyway and needs our own offline layer, so Firebase is simpler.

## 3. Match flow and integrity

1. Host creates `rooms/{code}` with a 6-character code from
   `ABCDEFGHJKMNPQRSTUVWXYZ23456789` (31^6 ≈ 887 million codes), generated
   with `Random.secure()`. Collision is a failed create; retry with a new code.
   The code expires after 24 hours (Firestore TTL).
2. Guest joins by code. A transaction creates `matches/{matchId}` with the
   seed (host-generated, 32-bit), the full `MatchConfig`, both player slots,
   and both loadout snapshots, then deletes the room.
3. Each player plays the same seed on their own board. Each accepted move is a
   create-only document `matches/{id}/moves/{slot}_{round}_{index}` holding the
   serialized `Move`, the move index, and the state hash after the move.
4. Each client replays the opponent's moves with `arena_engine` and compares
   every hash. A mismatch, invalid move, gap, duplicate, wrong turn or unknown
   engine version sets `flag` on the match (reason code). A flagged match
   awards no trophies or paws and is shown as "not counted".
5. Obstacles earned in round *n* land in the opponent's round *n+1*, so a player
   can start round *n+1* only once both players have finished round *n*.
6. When both have finished round 5, each client writes its final hashes; the
   match ends only if all four hashes agree.

Security rules enforce: only the two participants read or write a match;
moves are create-only, only in your own slot, in order, never updated or
deleted; every field is type-checked and unknown fields are rejected; emote
IDs and display-name IDs must be in the allowed list.

What this does **not** do: it does not stop a modified client from making
legal moves it computed with help. Both clients replaying the same log only
proves that both agree on the result. Server-side validation is parked.

Timers: live play uses a per-move timer on the client and records
`lastMoveAt` as a server timestamp. Slow play has `roundDeadline` =
server time + 24 hours. A scheduled Cloud Function (every 15 minutes)
forfeits rounds past their deadline. Device clocks are never authoritative.

Push: a Cloud Function on `moves` create sends one FCM message ("It's your
turn") to the opponent's devices, with only the match ID as data. No player
names in the payload.

## 4. Data stored

Every item, where it lives, why, and how long. Nothing else is sent.

| Data | Where | Purpose | Kept until |
| --- | --- | --- | --- |
| Firebase user ID | Auth, every doc | Account, access rules | Account deletion |
| Google account email, name, Google user ID | Auth only, after the player links Google | Sign in again after reinstall | Unlink or account deletion |
| Preset display name ID (e.g. `name_07`) | `users/{uid}` | Shown to friends | Account deletion |
| Friend code | `users/{uid}` | Lets a friend find you | Account deletion |
| Cat loadout (cat, fur, eyes, ears, pattern, accessory, power IDs) | `users/{uid}` | Cloud save | Account deletion |
| Progress: trophies, paws balance, owned cosmetic IDs, daily claim date, tutorial done, settings (sound, music, language, notifications) | `users/{uid}` | Cloud save | Account deletion |
| FCM registration token, app version, platform | `users/{uid}/devices/{installId}` | Your-turn push | Token refresh, sign-out, or deletion |
| Room code, host user ID, created time | `rooms/{code}` | Joining a friend | 24 h (TTL) or join |
| Match record per `docs/contract.md` §4: versions, seed, config, both user IDs, loadout snapshots, opponent kind, per-round move logs and hashes, outcome, pause/disconnect events | `matches/{id}` | Play, replay check, resume | 30 days after the match ends (TTL) |
| Emotes: emote ID, sender slot, round, server time | `matches/{id}/emotes` | Preset emotes | With the match |
| Product events (list in slice 4): event name, user ID, app version, server time, enum parameters only | `events/{id}` | Learn whether players come back | 90 days (TTL) |
| Request logs (IP address, user agent) | Google Cloud logs, automatic | Operating the service | Google default retention; *needs human review* |

Never uploaded: the local custom player name (typed text), photo avatars
(parked), the advertising ID, contacts, location, or any free text.

Account deletion (in the app): a callable Cloud Function deletes
`users/{uid}`, its devices, open rooms, and the user's events; in matches it
replaces the user ID with `deleted`; then it deletes the Auth user. The app
then clears local data. A web deletion form is also needed for the Play
listing; *needs human review*.

## 5. Families policy

- **No advertising ID.** The merged manifest must not contain
  `com.google.android.gms.permission.AD_ID`. Lane 5 will add
  `tools:node="remove"` for it in `android/app/src/main/AndroidManifest.xml`
  and a CI step that fails if the merged release manifest contains it.
- **No ad SDK and no analytics that collect the advertising ID.** No
  `firebase_analytics`, Google Mobile Ads, AppLovin, Unity Ads, Facebook
  SDK, Adjust, AppsFlyer, or similar. A CI step will fail if any of these
  appears in `pubspec.lock` or the Gradle dependency tree. Product events
  (§4) are our own Firestore writes with no device or ad identifier.
- **No typed text between players.** Display names come from a preset list
  and travel as IDs; emotes are IDs from a fixed list; friend and room codes
  are fixed-alphabet identifiers. Security rules reject any other string.
  There is no text field that reaches another player.
- **Google sign-in is optional.** Play starts anonymous. Linking Google is
  behind a parent gate in settings (lane 4 screen, via a request). *Needs
  human review*: whether Google sign-in is acceptable for the child audience
  in each target market.
- **Push permission** (`POST_NOTIFICATIONS`) is asked only when the player
  starts a slow match, and respects the existing notifications setting.
- **Existing dependency to check:** `image_picker` is in `pubspec.yaml` for
  the parked photo avatar. If it stays, its permissions and data flows have
  to be declared; the orchestrator owns that file, so this is a request, not
  a change by lane 5.
- *Needs human review*: whether the Firebase SDKs and the anonymous user ID
  meet COPPA/GDPR rules for players under 13/16 in the target markets, and
  the Play Families self-certified SDK requirements. This proposal does not
  claim they do.

## 6. Cost at 1,000 daily players

Assumptions (deliberately high): 1,000 players a day, each plays 2 friend
matches (1,000 matches a day), opens the app twice, and sends 10 product
events. Firestore Standard, single region, list prices as published by
Google at the time of writing (verify in the Firebase pricing calculator
before approval): 50k reads, 20k writes, 20k deletes and 1 GiB per day
free; then about 0.03 USD per 100k reads, 0.09 USD per 100k writes,
0.01 USD per 100k deletes.

| Item per day | Count |
| --- | --- |
| Match writes: room, join, 30 moves, round/end updates, emotes | ~40 per match → 40,000 |
| Match reads: listener reads of the opponent's writes, resume | ~40 per match → 40,000 |
| Profile reads/writes (2 opens, ~3 saves per player) | 2,000 reads, 3,000 writes |
| Product events | 10,000 writes |
| TTL deletes (rooms, matches, moves, events) | ~45,000 |
| **Total** | ~42,000 reads, ~53,000 writes, ~45,000 deletes |

Monthly: reads stay under the free tier (0 USD); writes ≈ 33,000 billable
a day ≈ 0.9 USD; deletes ≈ 25,000 billable a day ≈ 0.1 USD; storage stays
under 1 GiB (0 USD). Auth (anonymous + Google) is free at this volume. FCM is
free. Cloud Functions: ~35,000 invocations a day ≈ 1 million a month, inside
the 2 million free invocations; compute is a few cents. Outbound network is
small (JSON documents).

**Estimate: about 1–5 USD a month at 1,000 daily players**, with a budget
alert at 25 USD. Costs grow roughly linearly with matches played. The same
load on Supabase would be the Pro plan, about 25 USD a month.

## 7. What slice 3 would add (after approval)

- `pubspec.yaml` lines for the packages in §1, through `docs/requests.md`.
- `lib/online/`: `OnlineAccount`, `RoomCodes`, `MatchTransport` (interface,
  with a Firestore and a fake implementation), `MatchSession` (replay and
  hash check, timers, resume), `EmoteIds`, `CloudSave`.
- `backend/`: `firestore.rules`, rules tests with the emulator,
  `functions/` (push, deadlines, account deletion), `firebase.json`.
- `android/`: `google-services` plugin, AD_ID removal, CI manifest check.
- `test/online_test.dart`: the five Done-when checks over a fake transport.

## 8. Decisions requested from the orchestrator

1. Approve Firebase (or choose Supabase).
2. Approve the data list in §4 and the retention periods (30 days for
   matches, 90 days for events).
3. Approve that the local custom name is never uploaded.
4. Decide on the parent gate for Google sign-in and on `image_picker`.
5. Owner: create the Firebase project (Blaze, budget alert) and provide
   `google-services.json` for `games.oneear.catpawsarena`.
