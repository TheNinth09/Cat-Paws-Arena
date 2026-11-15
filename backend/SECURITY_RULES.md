# Firestore security rules checklist (lane 5)

Status: `backend/firestore.rules` implements every section through
emotes; `backend/test/rules.test.js` tests them on the emulator (20 tests).
Moves, match results and events come with later slices and are denied
until then. Nothing is deployed; the owner deploys (FIREBASE_SWITCH.md §6).

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

- [ ] Read and write only if
      `request.auth.uid in [resource.data.hostUid, resource.data.guestUid]`.
- [ ] Create only inside the room claim: ID `{code}_{room createdAt millis}`,
      exactly `roomCode`, `hostUid` (from the room), `guestUid == auth.uid`,
      `createdAt == request.time`, room still live and deleted in the same
      commit. Seed, `MatchConfig`, versions and loadouts are added by the
      match slice.
- [ ] Seed, config, versions, slots and loadouts are immutable after create
      (`diff(resource.data).affectedKeys()` excludes them).
- [ ] A player may update only their own final hashes, their own
      pause/disconnect metadata, and `flag` (a reason code from a fixed list).
- [ ] A flag, once set, cannot be cleared by a client.
- [ ] Outcome is written only when both final hashes are present and equal.
- [ ] `roundDeadline` is written by the deadline function, not by clients.
- [ ] TTL 30 days after `endedAt` (owner deploys).

## `matches/{matchId}/moves/{moveId}` — move log

- [ ] Create only; no update, no delete.
- [ ] Document ID is `{slot}_{round}_{index}` and must agree with the fields.
- [ ] `slot` is the writer's own slot.
- [ ] `round` in 1..5, `index` in 0..2 (`MatchConfig`: five rounds of three
      moves).
- [ ] Ordered: `index == 0` or the move `{slot}_{round}_{index-1}` exists;
      `round > 1` requires both players' last move of `round - 1`
      (obstacles from round n land in round n+1).
- [ ] Move payload fields and types match the serialized `arena_engine`
      move; coordinates are ints inside the board size.
- [ ] `stateHash` is a string of the engine hash length; `createdAt ==
      request.time`.
- [ ] Rules do not judge legality; each client replays with `arena_engine`
      and flags a mismatch (no cheat-proof claim).

## `matches/{matchId}/emotes/{id}` — preset emotes

- [ ] Create only, by a participant, in their own slot.
- [ ] `emote` in the `Emote.wire` list from `lib/online/emotes.dart`
      (`hello`, `good_game`, `wow`, `oops`, `thanks`, `purr`); any other
      string is rejected.
- [ ] Only `emote`, `slot`, `round`, `createdAt == request.time`.
- [ ] Rate limit by rules: at most one emote per slot per round index, or a
      server-side throttle; decide in the implementation PR.

## `events/{id}` — product events (slice 4)

- [ ] Create only, by the signed-in user, `uid == request.auth.uid`.
- [ ] `name` in the fixed event list; parameters are enums/ints only.
- [ ] No advertising ID, device ID, IP or free text field.
- [ ] Clients cannot read events. TTL 90 days.

## Functions (Admin SDK bypasses rules, so check these in review)

- [ ] `onUserDeleted` (Auth trigger, `europe-west1`): deletes what is left
      of the user, devices, clock and rooms, and writes `deleted` in place of
      the uid in matches and emotes. The app deletes the profile first.
- [ ] Push on move create: payload carries only the match ID, no names.
- [ ] Deadline forfeit (scheduled): uses server time, writes only
      `roundDeadline`/forfeit fields.
- [ ] App Check is considered for the release, but not required by the
      contract; *decision for the orchestrator*.
