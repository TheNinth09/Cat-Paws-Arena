import 'dart:math' show Random;

import 'package:arena_engine/arena_engine.dart';
import 'package:test/test.dart';

const config = MatchConfig.duel();

/// Plays [state] forward with random legal moves, returning the move log
/// and final state. Stops at match end or after [maxMoves].
(MatchState, List<Move>) playRandom(
  MatchState state,
  Random rng, {
  int maxMoves = 400,
}) {
  final log = <Move>[];
  var s = state;
  while (!s.isFinished && log.length < maxMoves) {
    final moves = (legalMoves(s) as EngineOk<List<Move>>).value;
    if (moves.isEmpty) break;
    final move = moves[rng.nextInt(moves.length)];
    final result = applyMove(s, move);
    expect(result, isA<EngineOk<MoveResult>>());
    final mr = (result as EngineOk<MoveResult>).value;
    expect(mr.events.whereType<SwapRejected>(), isEmpty);
    s = mr.state;
    log.add(move);
    if (!s.isFinished) {
      // Done-when 4: after any move resolves, a legal move remains.
      final next = legalMoves(s) as EngineOk<List<Move>>;
      expect(next.value, isNotEmpty);
    }
  }
  return (s, log);
}

/// Counts regular colour runs of length >= 3 horizontally and vertically.
int startingMatches(BoardState b) {
  var count = 0;
  final w = b.width, h = b.height;
  for (var r = 0; r < h; r++) {
    for (var c = 0; c + 2 < w; c++) {
      final a = b.cellAt(r, c), d = b.cellAt(r, c + 1), e = b.cellAt(r, c + 2);
      if (a >= 0 && a < 20 && a == d && d == e) count++;
    }
  }
  for (var c = 0; c < w; c++) {
    for (var r = 0; r + 2 < h; r++) {
      final a = b.cellAt(r, c), d = b.cellAt(r + 1, c), e = b.cellAt(r + 2, c);
      if (a >= 0 && a < 20 && a == d && d == e) count++;
    }
  }
  return count;
}

void main() {
  group('newMatch', () {
    test('is deterministic for the same seed and config', () {
      final a = (newMatch(42, config) as EngineOk<MatchState>).value;
      final b = (newMatch(42, config) as EngineOk<MatchState>).value;
      expect(stateHash(a), stateHash(b));
      expect(a.boards[0].cells, b.boards[0].cells);
      expect(a.boards[1].cells, b.boards[1].cells);
    });

    test('different seeds produce different boards', () {
      final a = (newMatch(1, config) as EngineOk<MatchState>).value;
      final b = (newMatch(2, config) as EngineOk<MatchState>).value;
      expect(stateHash(a), isNot(stateHash(b)));
    });

    test('supports zero and negative seeds', () {
      for (final seed in [0, -1, -987654321, 9223372036854775807]) {
        final r = newMatch(seed, config);
        expect(r, isA<EngineOk<MatchState>>());
      }
    });

    test('deals no starting matches and at least one legal move', () {
      for (var seed = 0; seed < 50; seed++) {
        final s = (newMatch(seed, config) as EngineOk<MatchState>).value;
        for (final b in s.boards) {
          expect(startingMatches(b), 0, reason: 'seed $seed');
        }
        final moves = (legalMoves(s) as EngineOk<List<Move>>).value;
        expect(moves, isNotEmpty);
      }
    });

    test('both players get identical boards and refill streams', () {
      final s = (newMatch(777, config) as EngineOk<MatchState>).value;
      expect(s.boards[0].cells, s.boards[1].cells);
      expect(s.boards[0].refillState, s.boards[1].refillState);
    });

    test('rejects invalid configs', () {
      expect(
        newMatch(1, const MatchConfig(colourCount: 4)),
        isA<EngineFailure<MatchState>>(),
      );
      expect(
        newMatch(1, const MatchConfig(engineVersion: 99)),
        isA<EngineFailure<MatchState>>(),
      );
      expect(
        newMatch(1, const MatchConfig(boardWidth: 0)),
        isA<EngineFailure<MatchState>>(),
      );
    });
  });

  group('applyMove', () {
    test('rejects structurally invalid moves without mutating', () {
      final s = (newMatch(5, config) as EngineOk<MatchState>).value;
      final h = stateHash(s);
      // Out of bounds.
      expect(
        applyMove(s, const SwapMove(firstCell: (row: -1, col: 0), secondCell: (row: 0, col: 1))),
        isA<EngineFailure<MoveResult>>(),
      );
      // Same cell.
      expect(
        applyMove(s, const SwapMove(firstCell: (row: 0, col: 0), secondCell: (row: 0, col: 0))),
        isA<EngineFailure<MoveResult>>(),
      );
      // Non-adjacent.
      expect(
        applyMove(s, const SwapMove(firstCell: (row: 0, col: 0), secondCell: (row: 0, col: 2))),
        isA<EngineFailure<MoveResult>>(),
      );
      // Powers need charge; a fresh match has none.
      expect(
        applyMove(s, const PowerMove(power: PowerKind.zoomies, targetRow: 3)),
        isA<EngineFailure<MoveResult>>(),
      );
      expect(stateHash(s), h);
    });

    test('a non-matching swap returns SwapRejected and unchanged state', () {
      final s = (newMatch(11, config) as EngineOk<MatchState>).value;
      final board = s.boardOf(PlayerSlot.first);
      // Find an adjacent non-productive swap.
      SwapMove? bad;
      for (var r = 0; r < board.height && bad == null; r++) {
        for (var c = 0; c + 1 < board.width && bad == null; c++) {
          final move = SwapMove(
            firstCell: (row: r, col: c),
            secondCell: (row: r, col: c + 1),
          );
          final res = applyMove(s, move);
          if (res is EngineOk<MoveResult> &&
              res.value.events.single is SwapRejected) {
            bad = move;
          }
        }
      }
      expect(bad, isNotNull, reason: 'expected a non-matching swap to exist');
      final res = applyMove(s, bad!) as EngineOk<MoveResult>;
      expect(res.value.state, same(s));
      expect(res.value.hashBefore, res.value.hashAfter);
      expect(res.value.events, hasLength(1));
      expect(res.value.events.single, isA<SwapRejected>());
      expect(s.movesLeft(PlayerSlot.first), config.movesPerRound);
      expect(s.activePlayer, PlayerSlot.first);
    });

    test('every legalMoves entry is accepted by applyMove', () {
      var s = (newMatch(21, config) as EngineOk<MatchState>).value;
      final rng = Random(1);
      for (var step = 0; step < 30 && !s.isFinished; step++) {
        final moves = (legalMoves(s) as EngineOk<List<Move>>).value;
        for (final m in moves) {
          final res = applyMove(s, m);
          expect(res, isA<EngineOk<MoveResult>>(), reason: 'move $m rejected');
        }
        final pick = moves[rng.nextInt(moves.length)];
        s = (applyMove(s, pick) as EngineOk<MoveResult>).value.state;
      }
    });

    test('scores accumulate flat points and turns alternate', () {
      final s = (newMatch(3, config) as EngineOk<MatchState>).value;
      var cur = s;
      final log = <Move>[];
      // Play until the first RoundEnded appears.
      var sawRoundEnd = false;
      for (var i = 0; i < 20 && !sawRoundEnd; i++) {
        final moves = (legalMoves(cur) as EngineOk<List<Move>>).value;
        final move = moves.first;
        final res = applyMove(cur, move) as EngineOk<MoveResult>;
        cur = res.value.state;
        log.add(move);
        sawRoundEnd = res.value.events.any((e) => e is RoundEnded);
      }
      expect(sawRoundEnd, isTrue);
      // A full round is 3 moves per player = 6 accepted moves.
      expect(log.length, 6);
      expect(cur.round, 2);
      expect(cur.activePlayer, PlayerSlot.first);
      expect(cur.movesLeft(PlayerSlot.first), config.movesPerRound);
      expect(cur.movesLeft(PlayerSlot.second), config.movesPerRound);
      // Verify the replayed log produces the identical final state/hash.
      final replayed = replay(3, config, log);
      expect(replayed, isA<EngineOk<ReplayResult>>());
      final rr = (replayed as EngineOk<ReplayResult>).value;
      expect(rr.hash, stateHash(cur));
      expect(rr.state.scores[0], greaterThanOrEqualTo(0));
      expect(rr.state.scores[1], greaterThanOrEqualTo(0));
      expect(rr.state.scores[0] + rr.state.scores[1], greaterThan(0));
    });
  });

  group('replay and hash', () {
    test('empty log returns the initial state', () {
      final s = (newMatch(9, config) as EngineOk<MatchState>).value;
      final r = replay(9, config, const []) as EngineOk<ReplayResult>;
      expect(r.value.hash, stateHash(s));
      expect(r.value.movesApplied, 0);
    });

    test('replay reproduces the live-played final state', () {
      final rng = Random(1234);
      final s = (newMatch(2024, config) as EngineOk<MatchState>).value;
      final (finalState, log) = playRandom(s, rng);
      final r = replay(2024, config, log) as EngineOk<ReplayResult>;
      expect(r.value.hash, stateHash(finalState));
      expect(r.value.movesApplied, log.length);
    });

    test('corrupt logs fail with position and reason', () {
      final rng = Random(7);
      final s = (newMatch(31, config) as EngineOk<MatchState>).value;
      final (_, log) = playRandom(s, rng, maxMoves: 10);
      expect(log, isNotEmpty);
      final bad = List<Move>.of(log);
      bad.add(const SwapMove(firstCell: (row: 0, col: 0), secondCell: (row: 0, col: 2)));
      final r = replay(31, config, bad);
      expect(r, isA<EngineFailure<ReplayResult>>());
      final err = (r as EngineFailure<ReplayResult>).error;
      expect(err.code, EngineErrorCode.replayDivergence);
      expect(err.details['position'], log.length);
    });

    test('moves after match end are rejected', () {
      final rng = Random(99);
      final s = (newMatch(4, config) as EngineOk<MatchState>).value;
      final (_, log) = playRandom(s, rng);
      expect(log.length, greaterThan(0));
      final extended = List<Move>.of(log);
      // Find the first finished prefix length by replaying.
      var finishedAt = -1;
      for (var n = 1; n <= log.length; n++) {
        final r = replay(4, config, log.sublist(0, n));
        if (r is EngineOk<ReplayResult> && r.value.state.isFinished) {
          finishedAt = n;
          break;
        }
      }
      expect(finishedAt, greaterThan(0));
      extended.length = finishedAt;
      extended.add(const SwapMove(firstCell: (row: 0, col: 0), secondCell: (row: 0, col: 1)));
      final r = replay(4, config, extended);
      expect(r, isA<EngineFailure<ReplayResult>>());
    });

    test('stateHash and playerHash are stable', () {
      final s = (newMatch(8, config) as EngineOk<MatchState>).value;
      expect(stateHash(s), stateHash(s));
      expect(playerHash(s, PlayerSlot.first), playerHash(s, PlayerSlot.first));
      expect(
        playerHash(s, PlayerSlot.first),
        isNot(playerHash(s, PlayerSlot.second)),
      );
    });
  });

  group('determinism at scale', () {
    test('1000 seeds: replay twice returns the same hash', () {
      final rng = Random(20261115);
      for (var seed = 0; seed < 1000; seed++) {
        final s = (newMatch(seed, config) as EngineOk<MatchState>).value;
        final (_, log) = playRandom(s, rng, maxMoves: 60);
        final r1 = replay(seed, config, log) as EngineOk<ReplayResult>;
        final r2 = replay(seed, config, log) as EngineOk<ReplayResult>;
        expect(r1.value.hash, r2.value.hash, reason: 'seed $seed');
        expect(r1.value.hash, isNotEmpty);
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('two engines with the same seed stay identical under same moves', () {
      final rng = Random(555);
      var a = (newMatch(12345, config) as EngineOk<MatchState>).value;
      var b = (newMatch(12345, config) as EngineOk<MatchState>).value;
      final log = <Move>[];
      for (var i = 0; i < 40 && !a.isFinished; i++) {
        final moves = (legalMoves(a) as EngineOk<List<Move>>).value;
        if (moves.isEmpty) break;
        final m = moves[rng.nextInt(moves.length)];
        log.add(m);
        a = (applyMove(a, m) as EngineOk<MoveResult>).value.state;
        b = (applyMove(b, m) as EngineOk<MoveResult>).value.state;
      }
      expect(stateHash(a), stateHash(b));
      for (var p = 0; p < 2; p++) {
        expect(a.boards[p].cells, b.boards[p].cells);
        expect(a.boards[p].refillState, b.boards[p].refillState);
      }
    });
  });

  group('match structure', () {
    test('a full scripted match ends with MatchEnded', () {
      final rng = Random(31337);
      final s = (newMatch(606, config) as EngineOk<MatchState>).value;
      var cur = s;
      MatchEnded? ended;
      var guard = 0;
      while (!cur.isFinished && guard++ < 500) {
        final moves = (legalMoves(cur) as EngineOk<List<Move>>).value;
        final m = moves[rng.nextInt(moves.length)];
        final res = applyMove(cur, m) as EngineOk<MoveResult>;
        for (final e in res.value.events) {
          if (e is MatchEnded) ended = e;
        }
        cur = res.value.state;
      }
      expect(cur.isFinished, isTrue);
      expect(ended, isNotNull);
      expect(ended!.scores.first, cur.scores[0]);
      expect(ended.scores.second, cur.scores[1]);
      expect(ended.finalHashes.first, isNotEmpty);
      expect(ended.finalHashes.second, isNotEmpty);
    });

    test('move json round-trips', () {
      const m1 = SwapMove(firstCell: (row: 2, col: 3), secondCell: (row: 2, col: 4));
      final j = m1.toJson();
      expect(Move.fromJson(j), m1);
      const m2 = PowerMove(power: PowerKind.zoomies, targetRow: 4);
      expect(Move.fromJson(m2.toJson()), m2);
      expect(Move.fromJson({'kind': 'bogus'}), isNull);
      expect(Move.fromJson('nope'), isNull);
    });
  });
}
