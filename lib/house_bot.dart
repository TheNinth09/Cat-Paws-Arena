import 'dart:math';

import 'package:arena_engine/arena_engine.dart' as engine;

/// House-cat opponent. Picks from [engine.legalMoves] by level:
///
/// * `0` — random legal move (easiest).
/// * `1` — greedy: best immediate score gain.
/// * `2` — greedy plus charge, special creation and obstacles sent.
///
/// Timed turns allow unlimited swaps, so the controller paces the bot —
/// it keeps playing until the clock nearly runs out instead of ending on
/// a fixed move budget. Deterministic per [seed] so a match replays
/// identically.
class HouseBot {
  HouseBot({required this.level, required int seed})
    : _rng = Random(seed);

  /// 0, 1 or 2.
  final int level;
  final Random _rng;

  /// Picks the next move. Async because levels 1/2 evaluate every legal
  /// move with a full `applyMove` — ~35 cascade resolutions back to back
  /// would stall the UI thread for hundreds of ms (the reported 2-FPS
  /// drops). The loop yields the event loop whenever ~12 ms of work
  /// accrues so frames keep rendering while the bot thinks. The pick
  /// order and RNG consumption are unchanged, so results stay
  /// deterministic per [seed].
  Future<engine.Move> choose(engine.MatchState state) async {
    final legal = engine.legalMoves(state);
    if (legal is! engine.EngineOk<List<engine.Move>>) {
      // The engine guarantees EndTurnMove exists while the match runs;
      // this is only a defensive fallback.
      return const engine.EndTurnMove();
    }
    final playable = [
      for (final m in legal.value)
        if (m is! engine.EndTurnMove) m,
    ];
    if (playable.isEmpty) {
      return const engine.EndTurnMove();
    }
    if (level <= 0) {
      return playable[_rng.nextInt(playable.length)];
    }
    var best = playable.first;
    var bestScore = -1e18;
    final clock = Stopwatch()..start();
    var sliceStart = 0;
    for (final m in playable) {
      final s = _evaluate(state, m);
      if (s > bestScore || (s == bestScore && _rng.nextBool())) {
        bestScore = s;
        best = m;
      }
      if (clock.elapsedMilliseconds - sliceStart >= 12) {
        await Future<void>.delayed(Duration.zero);
        sliceStart = clock.elapsedMilliseconds;
      }
    }
    return best;
  }

  double _evaluate(engine.MatchState state, engine.Move move) {
    final res = engine.applyMove(state, move);
    if (res is! engine.EngineOk<engine.MoveResult>) return -1e17;
    final next = res.value.state;
    final slot = state.activePlayer;
    final scoreDelta = next.scoreOf(slot) - state.scoreOf(slot);
    if (level == 1) return scoreDelta.toDouble();
    final chargeDelta = next.chargeOf(slot) - state.chargeOf(slot);
    var specials = 0, obstaclesSent = 0;
    for (final e in res.value.events) {
      if (e is engine.SpecialCreated && e.player == slot) specials++;
      if (e is engine.ObstacleQueued && e.player == slot.other) {
        obstaclesSent += e.count;
      }
    }
    return scoreDelta * 10 +
        chargeDelta * 0.5 +
        specials * 15 +
        obstaclesSent * 8;
  }
}
