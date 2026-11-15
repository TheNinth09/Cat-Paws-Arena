# arena_engine

Pure Dart game engine for Cat Paws Arena duels. No Flutter, Flame,
`dart:io`, `dart:ui`, timers, platform channels, network clients,
wall-clock reads or ambient randomness — the same seed, config and move
log produce the same state and hash on every platform.

This package implements the engine contract in `docs/contract.md` at the
repository root. Slice 1 (this revision) covers the core ruleset; special
pieces, obstacles, powers and extra moves land in later contract-visible
revisions.

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

## Match structure (core slice)

- Two players (`PlayerSlot.first` / `second`), one independent board each,
  same seed and config. Turns alternate one accepted move at a time; a
  player who still has moves continues when the opponent is exhausted.
- `config.rounds` rounds of `config.movesPerRound` accepted moves each.
  A round ends when **both** players have used all their moves; scores are
  cumulative across the match.
- Each round deals a fresh board derived only from `(seed, round)` — both
  players receive an identical deal. Deals guarantee no starting matches
  and at least one legal move.
- After the last round the engine emits `RoundEnded` (with the final
  outcome) then `MatchEnded` (outcome, scores, per-player final hashes).

## Board rules (core slice)

- 7x7 by default (`MatchConfig.duel()`); `boardWidth`, `boardHeight`,
  `colourCount` (5 or 6), `rounds`, `movesPerRound`, `rainbowRule`,
  `engineVersion` and `powerConfiguration` are all configuration.
- Orthogonal swaps of two unlocked piece cells. A swap is legal only if it
  creates a line of 3+ or involves a special piece; a well-formed but
  non-productive swap returns `EngineOk` with an unchanged state and a
  single `SwapRejected` event — no turn or randomness is consumed.
- Lines of 3+ clear, gravity pulls pieces down per column, columns refill
  from a per-column stream, and cascades repeat until stable.
- Flat scoring: `kPointsPerPiece` (10) per cleared piece per wave — no
  cascade multiplier. `Cleared.points` always equals
  `cells.length * 10`.
- If a resolved board has no legal move it is deterministically reshuffled
  (`Shuffled` event) until a move exists.

## Determinism

- RNG: Lehmer/Park-Miller LCG, `state = state * 48271 mod (2^31 - 1)`,
  full period `2147483646`. All arithmetic stays below `2^53` and uses no
  bitwise operators, so streams are identical on the VM and on JS.
- Streams: per-player effect RNG (`state.rngState`), per-column refill
  streams derived from `(seed, round, column)` — identical for both
  players — and a deal stream derived from `(seed, round)`.
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
`MatchEnded`. In the core slice only `Swapped`, `SwapRejected`, `Cleared`,
`ObstacleBroken` (always empty), `Fell`, `Refilled`, `Shuffled`,
`RoundEnded` and `MatchEnded` can be emitted.

## Testing

```sh
dart pub get
dart test
```

No Flutter SDK is required.
