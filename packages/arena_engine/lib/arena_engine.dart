/// Cat Paws Arena game engine.
///
/// Pure Dart package: deterministic seeded boards, legal-move queries,
/// event-returning transitions, replay and state hashing. No Flutter,
/// Flame, `dart:io`, `dart:ui`, timers, platform channels, network clients,
/// wall-clock reads or ambient randomness.
///
/// See `docs/contract.md` in the repository for the shared engineering
/// contract and `README.md` in this package for the rules reference,
/// hash algorithm and determinism notes.
library;

export 'src/bots.dart';
export 'src/engine.dart';
export 'src/sync.dart';
