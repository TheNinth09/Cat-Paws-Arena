# arena_engine

Pure Dart game engine for Cat Paws Arena duels. No Flutter, Flame,
`dart:io`, `dart:ui`, timers, platform channels, network clients,
wall-clock reads or ambient randomness — the same seed, config and move
log produce the same state and hash on every platform.

This package implements the engine contract in `docs/contract.md` at the
repository root. This revision covers the full ruleset: specials,
obstacles, powers, extra moves and the five-round duel structure.

## API

```dart
EngineResult<MatchState> newMatch(int seed, MatchConfig config);
EngineResult<List<Move>> legalMoves(MatchState state);
EngineResult<MoveResult> applyMove(MatchState state, Move move);
EngineResult<ReplayResult> replay(int seed, MatchConfig config, List<Move> moves);
String stateHash(MatchState state);
String playerHash(MatchState state, PlayerSlot player);
```

Every fallible operation returns `EngineResult<T>` (`EngineOk` /
`EngineFailure` with a stable `EngineErrorCode`). Ordinary invalid moves
are never thrown as exceptions.

## Match structure

- Two players (`PlayerSlot.first` / `second`), one independent board each,
  same seed and config. Turns alternate one accepted move at a time; a
  player who still has moves continues when the opponent is exhausted.
- `config.rounds` rounds of `config.movesPerRound` accepted moves each.
  A round ends when **both** players have used all their moves; scores are
  cumulative across the match.
- Each round deals a fresh board derived only from `(seed, round)` — both
  players receive an identical deal. Deals guarantee no starting matches
  and at least one legal move.
- Obstacles earned during a round queue per player
  (`MatchState.pendingObstacles`, capped at `kMaxPendingObstacles = 12`)
  and land at the start of that player's next round, in queue order, on
  the freshly dealt board. Obstacles earned in the final round are
  discarded.
- After the last round the engine emits `RoundEnded` (with the final
  outcome) then `MatchEnded` (outcome, scores, per-player final hashes).

## Board rules

- 7x7 by default (`MatchConfig.duel()`); `boardWidth`, `boardHeight`,
  `colourCount` (5 or 6), `rounds`, `movesPerRound`, `rainbowRule`,
  `engineVersion` and `powerConfiguration` are all configuration.
- Orthogonal swaps of two unlocked piece cells. A swap is legal only if it
  creates a line of 3+ or involves a special piece; a well-formed but
  non-productive swap returns `EngineOk` with an unchanged state and a
  single `SwapRejected` event — no turn or randomness is consumed.
- Lines of 3+ clear, gravity pulls pieces down per column (yarned pieces
  and boxes are fixed blockers that split each column into independent
  segments), columns refill from a per-column stream, and cascades repeat
  until stable.
- Flat scoring: `kPointsPerPiece` (10) per cleared piece — no cascade
  multiplier. `Cleared.points`, `SpecialFired.points` and
  `PowerFired.points` always equal `cells.length * 10`.
- If a resolved board has no legal move it is deterministically reshuffled
  (`Shuffled` event) until a move exists.

## Special pieces

Created by matches of four or more, anchored on one cell of the group
(the anchor is not cleared and does not score):

- Straight four → line piece. A horizontal run creates a **column**
  clearer (`kLineColumn`), a vertical run a **row** clearer
  (`kLineRow`) — the reward is orthogonal to the match.
- Bent group (L/T/step, always 5+ cells) → bomb (`kBomb`) at the
  lowest-index cell that has matched neighbours on both axes.
- Straight five or more → rainbow (`kRainbow`) at the run's first cell.

A special fires when swapped with any adjacent piece. When both swapped
cells hold specials, each fires once in ascending cell order; effects are
computed on a scratch board where earlier blasts are already removed, so
a special consumed by another blast does not fire. All effects resolve
before a single gravity+refill step. A fired rainbow uses
`config.rainbowRule`: `clearOneColour` removes every piece of the swapped
partner's colour (a random colour when the partner is not a regular
colour), `removeRandomPieces` removes `kRainbowRemoveCount` (12) random
pieces; the rainbow itself is always consumed.

## Extra moves

Every match group of four or more cells awards one extra move that round
(`ExtraMove` event), capped at `movesPerRound * 2` remaining moves so a
round cannot become endless. Cascades count too.

## Obstacles

- **Box** (`kCellBox`, `-2`): occupies a cell; no piece inside, not
  swappable. Breaks when a piece orthogonally adjacent to it is cleared.
- **Yarn** (`+ kYarnOffset` on a piece code): locks that piece — it cannot
  be swapped and does not fall — until the piece itself is cleared by a
  match or power (the lock is consumed, reported via `ObstacleBroken`).
  Yarn only ever lands on regular colour pieces, never on specials.
- Placement: boxes replace a random piece cell; yarn locks a random
  regular-colour cell, both drawn from the receiver's RNG stream.

## Power charge and powers

Every cleared piece (colour match, special blast, power blast) adds
`kChargePerPiece` (4) charge, capped at `kPowerCost` (500). Firing a
power consumes one move and its own charge cost (`powerChargeCost` —
see the tuning table below), reported as a `PowerCharged` event with a
negative delta, then resolves:

- **Zoomies** — clears every piece in `targetRow` and queues
  `kZoomiesObstacleCount` (2) random-kind obstacles for the opponent
  (`ObstacleQueued`). Costs `kZoomiesChargeCost` (460).
- **Shadow Pounce** — clears every piece of the most common colour
  (ties resolve to the lowest colour code). Costs
  `kShadowPounceChargeCost` (500 — a full bar).
- **Laser Chase** — breaks `kLaserBreakCount` (8) random pieces, then
  clears all of the user's own obstacles (boxes and yarn locks). Costs
  `kLaserChaseChargeCost` (175).

`legalMoves` lists power moves only while the active player has enough
charge for that power.

## Event order inside a transition

`Swapped` → (`SpecialFired`* → `ObstacleBroken` → `PowerCharged` →
gravity) when specials fire → per clear wave: `Cleared` →
`SpecialCreated`* → `ExtraMove` → `PowerCharged` → `ObstacleBroken` →
gravity → powers: `PowerCharged`(-cost) → `PowerFired` →
`ObstacleBroken`/`ObstacleQueued` → `PowerCharged`(+gain) → gravity →
cascades → `Shuffled` (if needed) → `RoundEnded`/`MatchEnded`.
`SwapRejected` is the only event of a rejected swap.

## Online 1v1 sync

`lib/src/sync.dart` holds the pure helpers a match-sync layer needs —
no I/O, no clocks, no platform APIs. It maps directly onto the friend
duel flow in `backend/PROPOSAL.md`:

- `MatchConfig.toJson()` / `MatchConfig.fromJson()` — full config
  round-trip for the match document. `fromJson` is strict: missing
  fields, wrong types or unknown enum names return `null` rather than
  silently defaulting (contract: never clamp a friend's config).
- `MoveLogEntry` — one shared-log record `{index, move, hashAfter?}`
  with `toJson`/`fromJson`. `index` is the 0-based position in the
  interleaved accepted-move log; `hashAfter` is the writer's claimed
  post-move state hash.
- `replayEntries(seed, config, entries)` — validated replay that plain
  `replay` cannot do: contiguous indices (gaps/duplicates/out-of-order
  rejected as `index-not-contiguous`), per-step `hashAfter` verification
  (`hash-mismatch`), plus all `applyMove` checks (wrong turn, bad
  coordinates, moves after finish). Failures carry `position` + `reason`.
- `summarizeLog(seed, config, entries)` — same validation, plus the log
  reorganized into `RoundMoveLog`s: per-round, per-player accepted moves
  and rejected swap attempts — the per-round move logs a saved match
  record stores (contract §4).
- `syncHashes(state)` / `initialSyncHashes(seed, config)` — the
  `{state, first, second}` digest triple clients exchange at match
  start and compare at match end (`MatchEnded.finalHashes` agrees).
- `isLegalMove(state, move)` — membership check against `legalMoves`
  without mutating state.

`Move.toJson`/`Move.fromJson` already provide the per-move document
payload; `MoveResult.hashAfter` is what a client stores as each move
document's state hash.

## Determinism

- RNG: Lehmer/Park-Miller LCG, `state = state * 48271 mod (2^31 - 1)`,
  full period `2147483646`. All arithmetic stays below `2^53` and uses no
  bitwise operators, so streams are identical on the VM and on JS.
- Streams: per-player effect RNG (`state.rngState`) advanced by that
  player's shuffles, rainbow draws, power picks and obstacle placement;
  per-column refill streams derived from `(seed, round, column)` —
  identical for both players; and a deal stream derived from `(seed,
  round)`.
- Cell encoding: `-1` empty (transient only), `-2` box, `0..5` colours,
  `20..23` specials, `+64` yarn lock. See `lib/src/board.dart`.

## Hashing

`stateHash` / `playerHash` use `kHashVersion = 1`: the state is serialized
to a canonical string (fixed field order, no maps, no floats, no object
identity) and hashed by two independent polynomial passes
(`h = ((h ^ unit) * 1000003) mod (2^31 - 1)`) producing a 16-hex-digit
digest. Changing the algorithm or the canonical layout is a contract
change.

## Events

Every transition returns an ordered, immutable `List<GameEvent>`:
`Swapped`, `SwapRejected`, `Cleared`, `SpecialCreated`, `SpecialFired`,
`Fell`, `Refilled`, `ObstacleQueued`, `ObstacleLanded`, `ObstacleBroken`,
`PowerCharged`, `PowerFired`, `Shuffled`, `ExtraMove`, `RoundEnded`,
`MatchEnded`.

## Bots

`lib/src/bots.dart` implements `ArenaBot` (`chooseMove(MatchState)`),
exported from `package:arena_engine/arena_engine.dart`:

- `RandomBot(seed)` — uniform pick over `legalMoves`.
- `GreedyBot()` — largest first clear; deterministic tie-break.
- `LookaheadBot()` — evaluates each candidate by simulating the
  transition plus a bounded reply search; deterministic.
- `PowerBot(power)` — plays regular swaps via greedy scoring but only
  fires its own [power] (swap-only fallback, so one power setting can
  never accidentally use another power).

Three house-cat levels are `RandomBot`, `GreedyBot` and `LookaheadBot`;
apps should label them clearly as house cats.

## Luck harness

```sh
dart run tool/harness.dart [matchesPerSetting]   # default 2000
```

Plays bot-vs-bot matches for each setting (identical-bot pairings plus
lookahead-vs-random and one dedicated setting per power) in parallel
isolates and writes `report/harness.md` with match outcomes, per-power
use statistics, power parity and the list of tuned numbers.

## Tuning constants

All balance numbers live in `lib/src/model.dart`:
`kPointsPerPiece` (10), `kChargePerPiece` (4), `kPowerCost` (500 cap),
`kZoomiesChargeCost` (460), `kShadowPounceChargeCost` (500),
`kLaserChaseChargeCost` (175), `kLaserBreakCount` (8),
`kZoomiesObstacleCount` (2), `kRainbowRemoveCount` (12),
`kMaxPendingObstacles` (12). The charge costs were tuned by the slice-3
harness until the three power settings stayed within 10% mean match
score of each other; the report lists every changed number.

## Testing

```sh
dart pub get
dart test
```

No Flutter SDK is required.
