import 'dart:math';

import 'package:arena_engine/arena_engine.dart' as engine;

/// House-cat opponent. Picks from [engine.legalMoves] by level:
///
/// * `0` — random legal move (easiest).
/// * `1` — greedy: best immediate score gain.
/// * `2` — greedy plus charge, special creation and obstacles sent.
///
/// Deterministic per [seed] so a match replays identically.
class HouseBot {
  HouseBot({required this.level, required int seed})
    : _rng = Random(seed);

  /// 0, 1 or 2.
  final int level;
  final Random _rng;

  engine.Move choose(engine.MatchState state) {
    final legal = engine.legalMoves(state);
    if (legal is! engine.EngineOk<List<engine.Move>>) {
      // The engine guarantees a move exists (it reshuffles otherwise);
      // this is only a defensive fallback.
      return const engine.SwapMove(
        firstCell: (row: 0, col: 0),
        secondCell: (row: 0, col: 1),
      );
    }
    final moves = legal.value;
    if (moves.isEmpty || level <= 0) {
      return moves[_rng.nextInt(moves.length)];
    }
    var best = moves.first;
    var bestScore = -1e18;
    for (final m in moves) {
      final s = _evaluate(state, m);
      if (s > bestScore || (s == bestScore && _rng.nextBool())) {
        bestScore = s;
        best = m;
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
