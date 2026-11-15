import 'dart:math';

class MatchBoard {
  MatchBoard({int? seed}) : random = Random(seed) {
    reset();
  }
  final Random random;
  late List<int> cells;
  int score = 0;
  int charge = 0;
  int attacks = 0;
  static const names = [
    'tile_star',
    'tile_fish',
    'tile_mouse',
    'tile_yarn',
    'tile_paw',
  ];

  void reset() {
    cells = List.filled(49, 0);
    for (var i = 0; i < 49; i++) {
      do {
        cells[i] = random.nextInt(5);
      } while ((i % 7 > 1 &&
              cells[i] == cells[i - 1] &&
              cells[i] == cells[i - 2]) ||
          (i > 13 && cells[i] == cells[i - 7] && cells[i] == cells[i - 14]));
    }
    if (!hasMove) reset();
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
  }

  bool swap(int a, int b) {
    if (!adjacent(a, b) || cells[a] < 0 || cells[b] < 0) return false;
    exchange(a, b);
    if (matches().isEmpty) {
      exchange(a, b);
      return false;
    }
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

  int clear(Set<int> found, int combo) {
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
      for (final j in [i - 1, i + 1, i - 7, i + 7]) {
        if (adjacent(i, j) && cells[j] < 0) obstacles.add(j);
      }
    }
    for (final i in {...found, ...obstacles}) {
      cells[i] = -2;
    }
    return found.length;
  }

  void fall() {
    for (var col = 0; col < 7; col++) {
      final values = [
        for (var row = 6; row >= 0; row--)
          if (cells[row * 7 + col] != -2) cells[row * 7 + col],
      ];
      for (var row = 6; row >= 0; row--) {
        final n = 6 - row;
        cells[row * 7 + col] = n < values.length
            ? values[n]
            : random.nextInt(5);
      }
    }
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
      cells[candidates[random.nextInt(candidates.length)]] = -1;
    }
  }
}
