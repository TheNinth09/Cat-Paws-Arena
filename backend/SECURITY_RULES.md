# Firestore security rules checklist (lane 5)

Status: `backend/firestore.rules` implements every section through
emotes, including the match record and move log;
`backend/test/rules.test.js` tests them on the emulator (25 tests). Events
come with slice 4 and are denied until then. Nothing is deployed; the owner
deploys (FIREBASE_SWITCH.md §6). No TTL policy is needed (Spark-safe):
expiry and deadlines are checked with `request.time`.

Binding source: `docs/contract.md` §7 — only the two participants touch a
match, moves are create-only/ordered/type-checked, peer-visible strings are
preset IDs only.

## Global

- [ ] Default deny: `match /{document=**} { allow read, write: if false; }`.
- [ ] Every allow requires `request.auth != null`.
- [ ] Every write checks `request.resource.data.keys().hasOnly([...])`, so
      unknown fields are rejected.
- [ ] Every field is type-checked (`is int`, `is string`, `is bool`,
      `is timestamp`, `is list`, `is map`) and size-limited
      (strings ≤ 64 chars, lists ≤ 512 items, same limits as
      `CloudProfile`).
- [ ] Timestamps that matter are `== request.time`; client clocks are never
      trusted.
- [ ] No collection allows `list` except the ones a player needs to query,
      each limited by a `where` on their own uid.

## `users/{uid}` — cloud save

- [ ] Read/write only when `request.auth.uid == uid`.
- [ ] Fields match `CloudProfile.toJson()` exactly (schema version 1);
      `cat` in `['Tzuki', 'Bubble', 'Custom']`; fur/eyes/ears/pattern/power
      in range.
- [ ] `revision == resource.data.revision + 1` on update; `1` on create.
- [ ] No name, photo, email, or free-text field exists in the allowed keys.
- [ ] `presetDisplayName` (when added) must be an ID from the preset list.
- [ ] The owner may delete their own document (in-app deletion); the
      `onUserDeleted` function removes anything left.

## `users/{uid}/devices/{installId}` — push tokens

- [ ] Read/write only by the owner.
- [ ] Fields: `fid` (Firebase installation ID), `platform == 'android'`,
      `updatedAt == request.time`; install ID is 20 lowercase letters/digits.
- [ ] Never readable by the other player; the push function reads it with
      the Admin SDK.

## `rooms/{code}` — friend room codes

- [ ] `code` matches `^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$`.
- [ ] Create: `hostUid == request.auth.uid`, `createdAt == request.time`,
      `expiresAt` within 23–25 h of `request.time` (TTL only; expiry is
      `createdAt + 24h`).
- [ ] No update.
- [ ] `get` by any signed-in user; `list` denied (no enumerating codes).
- [ ] Delete by the host, by anyone once expired, or by the guest only
      inside the claim transaction: `getAfter(/matches/{code}_{createdAtMillis})`
      exists with `guestUid == request.auth.uid`.
- [ ] Guest cannot claim their own room (`hostUid != request.auth.uid`).
- [ ] Firestore TTL policy on `expiresAt` (owner deploys).
- [ ] Emulator test: three guests claim at once, exactly one match exists.

## `matches/{matchId}` — match record

- [x] Read only by `hostUid` / `guestUid`; no list.
- [x] Create only inside the room claim: ID `{code}_{room createdAt millis}`,
      exactly `roomCode`, `hostUid` (from the room), `guestUid == auth.uid`,
      `createdAt == request.time`, `seed` (int, 0..2^31-1), `config` equal
      to `MatchConfig.duel().fingerprint`, `engineVersion == 1`,
      `contractVersion == 1`; room still live and deleted in the same commit.
- [x] Updates touch only one of: the writer's own `final_first` /
      `final_second` (once; ints, 16-hex hash, outcome enum), `flag` (once,
      fixed reason list, never cleared), or `forfeitWinner` + `forfeitAfter`.
      Seed, config, versions and players are therefore immutable.
- [x] Forfeit: move `forfeitAfter` is the last one (`existsAfter`, so no
      move in the same batch), its `next` is the opponent, and it is at least
      24 h old (`request.time`); no moves are accepted afterwards (`getAfter`).
- [x] No delete by clients.
- [ ] Rewards count only when both finals are equal and there is no flag
      (`MatchSession.counts`); the rules do not compare them.

## `matches/{matchId}/moves/{moveId}` — move log

- [x] Create only; no update, no delete; read only by the two players.
- [x] Document ID is the zero-padded `index` (`000`, `001`, …), `index` < 200.
- [x] Ordered: `index == 0` or move `index - 1` exists (create-only, so two
      writers of the same index cannot both win).
- [x] `by == auth.uid`, `slot` is the writer's own slot (host `first`).
- [x] `move` is exactly a serialized `arena_engine` move: swap with two
      cells in 0..6, or power `zoomies|shadowPounce|laserChase` with an
      optional row; no other strings.
- [x] `hashAfter` is 16 lowercase hex digits; `next` is `first|second|none`
      (verified on replay); `at == request.time`.
- [x] Rules do not judge turn order or legality: each phone replays with
      `arena_engine` and flags `wrong_turn`, `invalid_move`,
      `hash_mismatch`, `bad_log` or `unknown_version` (no cheat-proof claim).

## `matches/{matchId}/emotes/{id}` — preset emotes

- [x] Create only, by a participant (`from == auth.uid`); never updated.
- [x] `emote` in the `Emote.wire` list from `lib/online/emotes.dart`
      (`hello`, `good_game`, `wow`, `oops`, `thanks`, `purr`); any other
      string is rejected.
- [x] Only `emote`, `from`, `at == request.time` (no round or turn field).
- [ ] Rate limit: none in rules yet; the UI throttles. Revisit if abused.

## Timed turns (v0.3) — rules gaps to close with the engine change

- [ ] `config` literal in `matchCreate` is the old fingerprint
      (`...|r5|m3|...`). Update it, and `engineVersion`, in the same merge
      as the new `MatchConfig.duel()`; otherwise every room claim is denied.
- [ ] `validMove` accepts only `swap` and `power`; add the engine's
      end-turn `Move.toJson()` shape once lane 1 defines it.
- [ ] No 30 s check in rules: the turn timer is client-side and ends with a
      logged end-turn entry; an idle player is only covered by the 24 h
      forfeit (`next` semantics already fit: mid-turn `next` is the mover).

## `events/{id}` — product events (slice 4)

- [ ] Create only, by the signed-in user, `uid == request.auth.uid`.
- [ ] `name` in the fixed event list; parameters are enums/ints only.
- [ ] No advertising ID, device ID, IP or free text field.
- [ ] Clients cannot read events. TTL 90 days.

## Functions (Admin SDK bypasses rules, so check these in review)

- [ ] `onUserDeleted` (Auth trigger, `europe-west1`): deletes what is left
      of the user, devices, clock and rooms, and writes `deleted` in place of
      the uid in matches and emotes. Backup only: the app already deletes
      profile, devices, clock and rooms itself before deleting the Auth user.
- [ ] Push on move create: payload carries only the match ID, no names.
- [x] No scheduled deadline function: the waiting player claims the forfeit
      and the rules check the 24 h with server time (works on Spark).
- [ ] App Check is considered for the release, but not required by the
      contract; *decision for the orchestrator*.
