import 'dart:math';

import 'duel_events.dart';

/// Legacy local-match board rules.
///
/// Lane-2 legacy kept until `packages/arena_engine` lands and replaces this
/// with `applyMove`/`replay`. The rules below are unchanged from the original
/// implementation; what is new is that mutations also record contract
/// [BoardEvent]s and stable piece ids so [BoardView] can animate them.
/// No timers live here — rule code stays synchronous and deterministic.
class MatchBoard {
  MatchBoard({int? seed}) : random = Random(seed) {
    _doReset();
  }
  final Random random;
  late List<int> cells;
  late List<int> _ids;
  int _nextId = 1;
  int score = 0;
  int charge = 0;
  int attacks = 0;

  /// Which seat this board belongs to; recorded on every emitted event.
  PlayerSlot slot = PlayerSlot.first;

  /// Cosmetic kind used for `ObstacleLanded` events from [obstacle].
  ObstacleKind obstacleKind = ObstacleKind.cardboardBox;

  final List<BoardEvent> _events = [];

  static const names = [
    'tile_star',
    'tile_fish',
    'tile_mouse',
    'tile_yarn',
    'tile_paw',
  ];

  /// Drains recorded contract events in causal order.
  List<BoardEvent> takeEvents() {
    if (_events.isEmpty) return const [];
    final out = List<BoardEvent>.of(_events);
    _events.clear();
    return out;
  }

  /// Records a rejected swap; performs no state mutation.
  void rejectSwap(int a, int b, String reason) {
    _events.add(
      SwapRejected(
        player: slot,
        firstCell: a,
        secondCell: b,
        reason: reason,
      ),
    );
  }

  /// Board contents as contract cells for the view's initial state.
  BoardSnapshot snapshot() => BoardSnapshot(
    width: 7,
    height: 7,
    cells: [for (var i = 0; i < 49; i++) _snapshotCell(i)],
  );

  BoardCell _snapshotCell(int i) {
    final v = cells[i];
    if (v >= 0) return BoardCell(piece: BoardPiece(id: _ids[i], kind: v));
    if (v == -1) return BoardCell(obstacle: obstacleKind);
    return const BoardCell();
  }

  Map<int, BoardPiece> _piecesMap() => {
    for (var i = 0; i < 49; i++)
      if (cells[i] >= 0) i: BoardPiece(id: _ids[i], kind: cells[i]),
  };

  void reset() {
    _doReset();
    _events.add(
      Shuffled(
        player: slot,
        cells: [for (var i = 0; i < 49; i++) i],
        reason: 'reshuffle',
        pieces: _piecesMap(),
      ),
    );
  }

  void _doReset() {
    cells = List.filled(49, 0);
    _ids = List.filled(49, -1);
    for (var i = 0; i < 49; i++) {
      do {
        cells[i] = random.nextInt(5);
      } while ((i % 7 > 1 &&
              cells[i] == cells[i - 1] &&
              cells[i] == cells[i - 2]) ||
          (i > 13 && cells[i] == cells[i - 7] && cells[i] == cells[i - 14]));
      _ids[i] = _nextId++;
    }
    if (!hasMove) _doReset();
  }

  Set<int> matches() {
    final result = <int>{};
    for (var row = 0; row < 7; row++) {
      for (var col = 0; col < 7; col++) {
        final i = row * 7 + col;
        if (cells[i] < 0) continue;
        if (col < 5 && cells[i] == cells[i + 1] && cells[i] == cells[i + 2]) {
          var end = col;
          while (end < 7 && cells[row * 7 + end] == cells[i]) {
            result.add(row * 7 + end);
            end++;
          }
        }
        if (row < 5 && cells[i] == cells[i + 7] && cells[i] == cells[i + 14]) {
          var end = row;
          while (end < 7 && cells[end * 7 + col] == cells[i]) {
            result.add(end * 7 + col);
            end++;
          }
        }
      }
    }
    return result;
  }

  bool adjacent(int a, int b) =>
      a >= 0 &&
      b >= 0 &&
      a < 49 &&
      b < 49 &&
      ((a ~/ 7 == b ~/ 7 && (a - b).abs() == 1) || (a - b).abs() == 7);
  void exchange(int a, int b) {
    final t = cells[a];
    cells[a] = cells[b];
    cells[b] = t;
    final ti = _ids[a];
    _ids[a] = _ids[b];
    _ids[b] = ti;
  }

  bool swap(int a, int b) {
    if (!adjacent(a, b) || cells[a] < 0 || cells[b] < 0) return false;
    exchange(a, b);
    if (matches().isEmpty) {
      exchange(a, b);
      return false;
    }
    _events.add(Swapped(player: slot, firstCell: a, secondCell: b));
    return true;
  }

  bool get hasMove {
    for (var i = 0; i < 49; i++) {
      for (final j in [i + 1, i + 7]) {
        if (!adjacent(i, j) || cells[i] < 0 || cells[j] < 0) continue;
        exchange(i, j);
        final valid = matches().isNotEmpty;
        exchange(i, j);
        if (valid) return true;
      }
    }
    return false;
  }

  int clear(Set<int> found, int combo, {bool reportClear = true}) {
    var longest = 0;
    for (final i in found) {
      for (final step in [1, 7]) {
        var count = 1, j = i + step;
        while (j < 49 &&
            (step == 7 || j ~/ 7 == i ~/ 7) &&
            cells[j] == cells[i]) {
          count++;
          j += step;
        }
        longest = max(longest, count);
      }
    }
    if (longest >= 4) attacks++;
    score += found.length * 10 * combo;
    charge = min(100, charge + found.length * 4);
    final obstacles = <int>{};
    for (final i in found) {
      if (cells[i] < 0) obstacles.add(i);
      for (final j in [i - 1, i + 1, i - 7, i + 7]) {
        if (adjacent(i, j) && cells[j] < 0) obstacles.add(j);
      }
    }
    final sorted = found.toList()..sort();
    if (reportClear) {
      _events.add(
        Cleared(
          player: slot,
          cells: sorted,
          points: found.length * 10 * combo,
        ),
      );
    }
    if (obstacles.isNotEmpty) {
      _events.add(
        ObstacleBroken(
          player: slot,
          cells: obstacles.toList()..sort(),
        ),
      );
    }
    _events.add(PowerCharged(player: slot, amount: charge));
    for (final i in {...found, ...obstacles}) {
      cells[i] = -2;
      _ids[i] = -1;
    }
    return found.length;
  }

  void fall() {
    for (var col = 0; col < 7; col++) {
      final entries = <(int, int, int)>[];
      for (var row = 6; row >= 0; row--) {
        final i = row * 7 + col;
        if (cells[i] != -2) entries.add((cells[i], row, _ids[i]));
      }
      for (var row = 6; row >= 0; row--) {
        final n = 6 - row;
        final i = row * 7 + col;
        if (n < entries.length) {
          final (value, fromRow, id) = entries[n];
          if (fromRow != row) {
            _events.add(Fell(player: slot, from: fromRow * 7 + col, to: i));
          }
          cells[i] = value;
          _ids[i] = id;
        } else {
          final kind = random.nextInt(5);
          cells[i] = kind;
          final id = _nextId++;
          _ids[i] = id;
          _events.add(
            Refilled(
              player: slot,
              cell: i,
              piece: BoardPiece(id: id, kind: kind),
            ),
          );
        }
      }
    }
  }

  /// Cascade resolution loop moved here from the old Flame board: clear,
  /// fall, repeat until stable, reshuffle when no move remains.
  void resolve() {
    var combo = 1;
    while (matches().isNotEmpty) {
      clear(matches(), combo++);
      fall();
    }
    if (!hasMove) reset();
  }

  /// Legacy power: clears a row, column, or colour band and resolves.
  /// Returns the affected cells; emits `PowerFired` plus the usual clear/fall
  /// events. [power] is the contract power kind for the event.
  Set<int> firePower(int kind, {PowerKind power = PowerKind.zoomies}) {
    charge = 0;
    final row = random.nextInt(7);
    final found = <int>{};
    for (var i = 0; i < 49; i++) {
      if (kind == 0
          ? i ~/ 7 == row
          : kind == 1
          ? i % 7 == row
          : cells[i] == row % 5) {
        found.add(i);
      }
    }
    _events.add(
      PowerFired(
        player: slot,
        power: power,
        cells: found.toList()..sort(),
        points: found.length * 10,
      ),
    );
    clear(found, 1, reportClear: false);
    fall();
    return found;
  }

  bool autoMove() {
    final moves = <(int, int)>[];
    for (var i = 0; i < 49; i++) {
      for (final j in [i + 1, i + 7]) {
        if (!adjacent(i, j) || cells[i] < 0 || cells[j] < 0) continue;
        exchange(i, j);
        if (matches().isNotEmpty) moves.add((i, j));
        exchange(i, j);
      }
    }
    if (moves.isEmpty) {
      reset();
      return false;
    }
    final move = moves[random.nextInt(moves.length)];
    swap(move.$1, move.$2);
    var combo = 1;
    while (matches().isNotEmpty && combo <= 30) {
      clear(matches(), combo++);
      fall();
    }
    if (!hasMove || matches().isNotEmpty) reset();
    return true;
  }

  void obstacle() {
    final candidates = [
      for (var i = 0; i < 49; i++)
        if (cells[i] >= 0) i,
    ];
    if (candidates.length > 35) {
      final idx = candidates[random.nextInt(candidates.length)];
      cells[idx] = -1;
      _ids[idx] = -1;
      _events.add(
        ObstacleLanded(
          player: slot,
          cells: [idx],
          obstacle: obstacleKind,
        ),
      );
    }
  }
}
