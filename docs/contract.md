# Shared engineering contract

Status: **initial setup proposal, not an implemented API or an approved backend**. Lanes implement this contract within their ownership; only the orchestrator changes this document. A change requires an announcement and a versioned migration note. No lane may silently weaken these rules.

## 1. Ownership and integration

The orchestrator owns `AGENTS.md`, `README.md`, `docs/`, `pubspec.yaml`, `lib/main.dart`, `lib/profile.dart`, `lib/catalog.dart`, shared dependency declarations, and this contract. Other paths belong to the lane listed in [plan.md](plan.md). New files must be inside the lane's namespace. Tests may exercise another lane's public API but cannot edit that lane's implementation.

Do not rename existing public exports or change their signatures without an announced contract change and coordinated rebases. Additive APIs are preferred. Do not copy gameplay rules into UI code. A lane needing a shared change submits a request in `docs/requests.md` or opens a narrowly scoped orchestrator review request.

Dependencies: a lane may add only its own dependency lines to `pubspec.yaml` after justification and license/version review. It must not remove or downgrade another lane's dependencies, change SDK/lint policy, or modify `pubspec.lock` by hand. Resolve lockfile conflicts by regenerating with the approved SDK and reviewing the diff.

## 2. Pure Dart engine package

Target package: `packages/arena_engine/`. Dart SDK constraint: `^3.13.5` to match the application. Initially no Flutter, Flame, `dart:io`, `dart:ui`, `dart:async` timers, platform channels, network clients, wall-clock reads, or ambient randomness. Asset loading and persistence live outside the package.

The package export surface is `package:arena_engine/arena_engine.dart`. Internal board representation may evolve, but exported gameplay types must remain stable within a contract version. All state exposed to callers is immutable or defensively copied; mutating a returned state/config/log must not change engine state. Lists, sets, maps, and strings in records must not alias mutable caller-owned data.

### API

Names below are Dart declarations to implement. `MatchState`, `Move`, and `Config` are the shared opaque/value types defined in section 3; their fields are not frozen by this API sketch. Return `EngineResult<T>` or a dedicated result type for operations that can reject input; do not use uncaught exceptions for ordinary invalid moves, exhausted turns, or corrupt replay logs.

```dart
EngineResult<MatchState> newMatch(int seed, MatchConfig config);
EngineResult<List<Move>> legalMoves(MatchState state);
EngineResult<MoveResult> applyMove(MatchState state, Move move);
EngineResult<ReplayResult> replay(int seed, MatchConfig config, List<Move> moves);
```

- `newMatch`: validates seed/config, creates the initial state and event-free initial board. Same inputs produce the same initial state/hash. Seed zero and positive/negative seeds must be supported unless explicitly rejected by the documented config contract; the implementation must document and test its accepted domain.
- `legalMoves`: returns all currently legal moves for the active player/round. It must not mutate state or consume randomness needed by the next transition. Returned moves are usable with `applyMove` on that state. Empty is valid only when the state cannot accept a move; callers must not invent a move.
- `applyMove`: validates state/move, atomically returns a new state and ordered events. An invalid move returns an explicit rejection with unchanged state and no gameplay events. No partial rewards or turn consumption on rejection. State transition, event generation, and RNG advancement must be consistent on retry/replay.
- `replay`: starts from the same seed/config and applies the entire log in order. It returns the final state and hash. A failed step returns an explicit error identifying the log position and reason, without a fabricated final state. An empty log is valid only if it represents the agreed initial state.

The engine must not depend on the legacy `MatchBoard` implementation. Lane 1 may adapt the old tests to the new API; lane 2 consumes the new API. Existing `lib/arena.dart` remains legacy until its owning lane migrates it.

### Determinism and errors

Use a documented, platform-independent PRNG or an explicit seed-derived generator, not `Random()` without a fixed seed or system entropy. Define integer overflow, piece IDs, sorting of sets, coordinate ordering, and serialization order. Hashes must depend on canonical state, not object identity, map iteration order, locale, or floating-point approximations.

Document the hash algorithm and state version in the package. Changing it is a contract change. Engine errors must be typed and carry stable reason codes, not localized UI strings. UI/backend lanes map those codes to user-facing text.

## 3. Configuration, state, moves, and events

### Configuration

`MatchConfig` is immutable and includes at least:

| Field | Contract |
| --- | --- |
| `boardWidth`, `boardHeight` | Positive integers; the agreed duel uses **7×7** |
| `colourCount` | Integer **5 or 6**, selected before match creation |
| `rounds` | Integer **5** for the agreed duel |
| `movesPerRound` | Integer **3** for the agreed duel |
| `rainbowRule` | Explicit enum/config, not an undefined boolean; exact behavior must be documented and tested before UI exposure |
| `engineVersion` | Positive integer identifying rules/serialization compatibility |
| `powerConfiguration` | Identifies the three agreed powers and their equal-strength rule; no prices |

Validate impossible configurations (for example more colours than distinct piece kinds, non-positive dimensions, or moves that cannot resolve a round). Configuration must be identical on both clients. Do not silently clamp a friend's config to a local default.

### State and moves

`MatchState` must represent, at minimum: engine/config version; match seed; current round; active player; remaining moves; both players' scores; both boards; pending obstacles and their delivery round/player; special pieces; power charge/effect state; round/match outcome; and enough RNG state to continue deterministically. Exact private representation is lane 1's choice.

Use stable player identifiers such as `PlayerSlot.first` and `PlayerSlot.second`, not display names or device IDs. A `Move` identifies the active player implicitly through state and contains an action kind plus coordinates/power selection as applicable. Define coordinates as zero-based row/column pairs and document bounds. Moves must be serializable without timestamps or local object references.

Legal actions include a valid swap and an explicitly supported power action. A power must consume the agreed resource according to engine rules, not bypass move limits unless the config explicitly says so. The engine owns when a power may be used; UI owns button availability and animation.

### Round and obstacle semantics

- Both players play the same seed/config, but each has an independent board state.
- There are five rounds of three moves. A round ends after the third accepted move, or earlier only for an explicitly defined terminal condition such as match completion. A terminal early finish must be deterministic and must not invent extra moves.
- Scores reset or accumulate exactly as documented by lane 1; the contract must state which. Flat points per piece are used, with no cascade multiplier. Colour count and rainbow behavior are config-visible.
- Obstacles earned in a round are queued for the opponent and appear at the start of that opponent's next round. Define maximum queue size, placement selection, collision behavior, and effects on move legality. Do not drop or duplicate obstacles during replay.
- After round five, produce a win/loss/draw result and final hashes. Scores alone are not proof of fairness; the event log and hashes must agree.

### Event contract

Every event is immutable and contains the fields below. Field names may be adjusted only through an announced contract revision; serialization names must remain stable. `cells` denotes zero-based row/column pairs or stable cell indices, documented by the engine. All collections have deterministic ordering.

| Event | Required fields / meaning |
| --- | --- |
| `Swapped` | `player`, `firstCell`, `secondCell`; accepted swap before resolution |
| `SwapRejected` | `player`, `firstCell`, `secondCell`, `reason`; no state mutation |
| `Cleared` | `player`, `cells`, `points`; flat points for the cleared pieces |
| `SpecialCreated` | `player`, `kind`, `cell`; kind is a defined enum, not arbitrary UI text |
| `SpecialFired` | `player`, `kind`, `cells`, `points`; resolved effect and scoring |
| `Fell` | `player`, `from`, `to`; one gravity movement |
| `Refilled` | `player`, `cell`, `piece`; deterministic new piece |
| `ObstacleQueued` | `player`, `sourceRound`, `count`; obstacle earned for opponent's next round |
| `ObstacleLanded` | `player`, `cells`; obstacles appearing at round start |
| `ObstacleBroken` | `player`, `cells`; cleared/consumed obstacles |
| `PowerCharged` | `player`, `amount`; charge delta or resulting charge, documented consistently |
| `PowerFired` | `player`, `power`, `cells`, `points`; validated power resolution |
| `Shuffled` | `player`, `cells`, `reason`; deterministic reshuffle |
| `ExtraMove` | `player`, `round`, `movesRemaining`; only if rules award one |
| `RoundEnded` | `round`, `scores`, `outcome`; boundary snapshot |
| `MatchEnded` | `outcome`, `scores`, `finalHashes`; terminal result |

Every gameplay event includes enough player/round context to render either board. Initialisation may emit `ObstacleLanded` for pre-existing obstacles only if documented; otherwise initial obstacles are part of state and not falsely reported as newly earned. Do not emit cosmetic-only events as authoritative gameplay events.

`applyMove` returns events for that move, including cascades, refill, scoring, obstacle delivery, round transitions, and match termination. Ordering must be causal and stable. `MoveResult` contains the new state, events, and before/after hashes; it does not rely on a mutable board listener.

### Replay and integrity

A move log entry contains engine version, match seed reference/config hash, round/player context as needed, move index, and the serializable move. Replaying must reject unknown versions, missing/extra entries, wrong player turn, invalid coordinates, repeated consumed moves, and hash divergence. Do not accept a client-supplied final hash as evidence without recomputation.

The backend may store logs and hashes, but game rules remain pure Dart. Server-side validation is parked as a separate deliverable; the minimum session integrity required for friend matches is part of the online lane's proposal and must be approved before implementation. No claim of cheat-proof multiplayer is made here.

## 4. Duel, profile, and persistence contract

### Duel records

A saved match record includes:

- `engineVersion` and contract version;
- match seed and full immutable `MatchConfig`;
- both player slots and agreed cat/power loadout snapshots;
- opponent kind: friend or labelled house cat;
- per-round move logs for both players, with round boundaries and accepted/rejected attempts distinguished;
- pause/disconnect/resume events as session metadata, not gameplay moves;
- final state hashes for both clients and an agreed outcome;
- local save revision and schema version for migration.

Friend and bot matches must use the same engine path. Bot choices must be deterministic for a given state/seed or explicitly labelled as local practice with a separate save type; they must not be represented as a friend's recorded moves. A rematch creates a new seed/log, not an overwrite of the old match.

### Player and cat fields

`Player` in `lib/profile.dart` is the shared local profile. Existing fields must remain compatible during migration: `name`, `trophies`, `coins`, `cat`, `accessory`, `daily`, `owned`, `claims`, `fur`, `eyes`, `ears`, `pattern`, `power`, `sfx`, `music`, `english`, `notifications`, and nullable `photo`.

The target profile additions are:

| Field | Meaning / authority |
| --- | --- |
| `presetDisplayName` | Name selected from the preset list for network-visible display; local custom name is separate |
| `friendCode` | Locally owned share code; never treated as proof of identity or ownership |
| `catLoadout` | Stable cat/cosmetic/power selection snapshot, with owned-item references only |
| `pawsBalance` | Earned paws; separate from legacy `coins` during migration |
| `ownedCosmetics` | Cosmetic IDs; powers are not sellable inventory |
| `settings` | Existing SFX/music/language/notification preferences plus accessibility preferences |
| `migrationVersion` | Versioned local data migration state |

Names displayed to other players come only from the preset list. Arbitrary profile names and typed text are never sent as peer-visible messages. Friend codes are shared explicitly by the player and are not broadcast automatically.

Migration must preserve existing saves, default new fields safely, and avoid double-crediting paws/coins or duplicating owned items. Exact conversion from legacy coins to paws/cosmetic balances requires an orchestrator-approved rule before economy lanes implement it; do not silently equate the currencies.

The profile is local UI state, not an authority for ownership, matchmaking, rewards, or billing. Online identity and entitlements require the approved backend contract. `photo` remains a parked capability; no lane re-enables photo avatars or typed peer profiles.

## 5. Screen and asset boundaries

- Lane 1 owns engine rules and package tests.
- Lane 2 owns duel rendering/input/audio and engine event adaptation; it must not calculate authoritative scores or online results.
- Lane 3 owns cat visuals/selection and local loadout presentation through profile hooks.
- Lane 4 owns home/progress/shop/settings and local navigation; parked team/event surfaces must not be advertised as live.
- Lane 5 owns online/release proposals and implementation only within approved scope; Android manifests/permissions and store declarations must match the family policy.

Use only bundled individual sprites, code-painted scenes, fonts, and permitted audio. Full-screen mockups remain reference-only. Runtime assets must not include reference mockups or unused online/chat/team assets once their owning lane removes the feature. Original source assets remain preserved.

All interactive elements need keyboard/accessibility labels where applicable, sufficient contrast, scalable text, and touch targets. Animations must not conceal game state or block input indefinitely. Reduced-motion and muted settings must be respected.

## 6. Acceptance checks for lanes

These checks define review evidence, not human gate approval.

1. Engine: same seed/config/log produces same final state/hash; invalid moves and corrupt logs fail explicitly; config constraints and obstacle timing are tested.
2. Duel: legal input produces the engine's events; UI replay matches engine replay; no timer/background/pause path awards unearned results.
3. Cats/profile: all three powers are free/equal; preset network names and loadouts survive save/reload without granting unowned items.
4. Home/shop: paws cannot be bought; cosmetic LEI offers have no countdown/pressure mechanics; parked features are not shown as live.
5. Online/release: friend code and bot label are explicit; preset emotes only; no ad SDK/advertising ID; no arbitrary peer text; no APK committed or release published by a lane.

The orchestrator reviews each PR against these checks and the lane file list. Human playtests and release approval remain separate and are never marked passed by an agent.
