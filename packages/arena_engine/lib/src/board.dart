/// Mutable board mechanics: cell codec, match scanning, gravity, dealing,
/// legal-move search, reshuffle.
///
/// All functions here are deterministic given their inputs. Randomness comes
/// only from [GameRandom] streams passed in by the caller.
library;

import 'model.dart';
import 'rng.dart';

/// Transient empty cell. Never present in a stable [BoardState].
const int kCellEmpty = -1;

/// Cell occupied by a box obstacle (no piece inside).
const int kCellBox = -2;

/// Number of regular colour codes (`0..kPieceColours - 1`).
const int kPieceColours = 6;

/// Special pieces carry the colour they were made from in their low bits:
/// `code = kindBase + colour` with [kSpecialStride] slots per kind so all
/// six colours fit. The rainbow keeps colour slot 0.
const int kSpecialStride = 8;

/// Line piece that clears its row when fired.
const int kLineRow = 20;

/// Line piece that clears its column when fired.
const int kLineColumn = 28;

/// Bomb piece that clears a 3x3 area when fired.
const int kBomb = 36;

/// Copter piece: flies to the highest-priority target when fired —
/// a box if one is on the board, otherwise a random colour piece.
const int kCopter = 44;

/// Rainbow piece; effect depends on [MatchConfig.rainbowRule].
const int kRainbow = 52;

/// First special-piece code. Codes below this are regular colours.
const int kFirstSpecial = kLineRow;

/// Encodes a special piece of [kindBase] made from [colour].
int specialCode(int kindBase, int colour) => kindBase + colour;

/// The kind base ([kLineRow], [kLineColumn], [kBomb], [kCopter] or
/// [kRainbow]) of a special [code]. Call only when [isSpecialCode].
int specialKindBaseOf(int code) =>
    kFirstSpecial +
    ((basePieceCode(code) - kFirstSpecial) ~/ kSpecialStride) *
        kSpecialStride;

/// The colour a special [code] was made from (0–5). Call only when
/// [isSpecialCode].
int specialColourOf(int code) =>
    (basePieceCode(code) - kFirstSpecial) % kSpecialStride;

/// Added to a piece code when yarn locks it in place.
const int kYarnOffset = 64;

/// Whether [code] holds any piece (colour or special), yarned or not.
bool isPieceCode(int code) => code >= 0;

/// Whether [code] is locked in place by yarn.
bool isYarnedCode(int code) => code >= kYarnOffset;

/// The piece code without its yarn flag.
int basePieceCode(int code) => code >= kYarnOffset ? code - kYarnOffset : code;

/// Whether [code] is a box obstacle cell.
bool isBoxCode(int code) => code == kCellBox;

/// Whether [code] is a special piece (line, bomb or rainbow).
bool isSpecialCode(int code) => basePieceCode(code) >= kFirstSpecial;

/// Whether [code] is a regular colour piece that can form a match.
bool isColourCode(int code) => code >= 0 && basePieceCode(code) < kFirstSpecial;

/// A mutable board used inside a single transition. Frozen into
/// [BoardState] when the transition completes.
class MutableBoard {
  final int width;
  final int height;
  List<int> cells;

  /// Per-column refill generator state (Lehmer raw state), parallel to
  /// [BoardState.refillState]. Each column continues its own stream.
  final List<int> refillState;

  MutableBoard(this.width, this.height, this.cells, this.refillState);

  factory MutableBoard.fromState(BoardState state) => MutableBoard(
    state.width,
    state.height,
    List<int>.of(state.cells),
    List<int>.of(state.refillState),
  );

  BoardState freeze() => BoardState(
    width,
    height,
    cells,
    refillState,
  );

  bool inBounds(int row, int col) =>
      row >= 0 && row < height && col >= 0 && col < width;

  /// Whether two cell indices are orthogonal neighbours.
  bool adjacent(int a, int b) {
    final ar = a ~/ width, ac = a % width;
    final br = b ~/ width, bc = b % width;
    return (ar == br && (ac - bc).abs() == 1) ||
        (ac == bc && (ar - br).abs() == 1);
  }
}

/// One connected group of matched cells: either 4-connected same-colour
/// cells through overlapping horizontal/vertical runs of length >= 3, or a
/// maximal 2x2 block of same-colour cells not already claimed by a run.
/// A pure 2x2 square reports `hasHorizontal == hasVertical == false`.
class MatchGroup {
  /// The regular colour shared by every cell.
  final int colour;

  /// Cell indices, sorted ascending (row-major order).
  final List<int> cells;

  /// Whether the group contains a horizontal run.
  final bool hasHorizontal;

  /// Whether the group contains a vertical run.
  final bool hasVertical;

  const MatchGroup({
    required this.colour,
    required this.cells,
    required this.hasHorizontal,
    required this.hasVertical,
  });

  /// Whether the group is a single horizontal line.
  bool get isStraightHorizontal => hasHorizontal && !hasVertical;

  /// Whether the group is a single vertical line.
  bool get isStraightVertical => hasVertical && !hasHorizontal;

  /// Whether the group bends (contains both orientations).
  bool get isBent => hasHorizontal && hasVertical;

  /// Whether the group is a pure 2x2 square (no qualifying run inside).
  bool get isSquare => !hasHorizontal && !hasVertical;
}

/// A maximal run of >= 3 same-colour cells along one axis.
class _Run {
  final int colour;
  final List<int> cells;
  final bool horizontal;
  const _Run(this.colour, this.cells, this.horizontal);
}

/// Scans [board] for all colour matches and returns connected
/// [MatchGroup]s sorted by their smallest cell index.
///
/// Two match shapes exist: runs of >= 3 (unioned into connected groups,
/// covering straight lines and L/T bends) and maximal 2x2 squares whose
/// cells are not already claimed by a run group. Special pieces never form
/// colour matches; yarned pieces match normally (the yarn is consumed when
/// they clear).
List<MatchGroup> scanMatches(MutableBoard board) {
  final w = board.width;
  final h = board.height;
  final cells = board.cells;
  final runs = <_Run>[];

  // Horizontal runs.
  for (var r = 0; r < h; r++) {
    var c = 0;
    while (c < w) {
      final code = cells[r * w + c];
      if (!isColourCode(code)) {
        c++;
        continue;
      }
      final colour = basePieceCode(code);
      var end = c + 1;
      while (end < w &&
          isColourCode(cells[r * w + end]) &&
          basePieceCode(cells[r * w + end]) == colour) {
        end++;
      }
      if (end - c >= 3) {
        runs.add(
          _Run(colour, [
            for (var k = c; k < end; k++) r * w + k,
          ], true),
        );
      }
      c = end;
    }
  }

  // Vertical runs.
  for (var c = 0; c < w; c++) {
    var r = 0;
    while (r < h) {
      final code = cells[r * w + c];
      if (!isColourCode(code)) {
        r++;
        continue;
      }
      final colour = basePieceCode(code);
      var end = r + 1;
      while (end < h &&
          isColourCode(cells[end * w + c]) &&
          basePieceCode(cells[end * w + c]) == colour) {
        end++;
      }
      if (end - r >= 3) {
        runs.add(
          _Run(colour, [
            for (var k = r; k < end; k++) k * w + c,
          ], false),
        );
      }
      r = end;
    }
  }

  // Union runs that share cells into connected groups.
  final parent = List<int>.generate(runs.length, (i) => i);
  int find(int x) {
    while (parent[x] != x) {
      parent[x] = parent[parent[x]];
      x = parent[x];
    }
    return x;
  }

  void union(int a, int b) {
    final ra = find(a), rb = find(b);
    if (ra != rb) parent[rb] = ra;
  }

  final cellToRuns = <int, List<int>>{};
  for (var i = 0; i < runs.length; i++) {
    for (final cell in runs[i].cells) {
      (cellToRuns[cell] ??= <int>[]).add(i);
    }
  }
  for (final ids in cellToRuns.values) {
    for (var k = 1; k < ids.length; k++) {
      union(ids[0], ids[k]);
    }
  }

  final byRoot = <int, List<int>>{};
  for (var i = 0; i < runs.length; i++) {
    byRoot.putIfAbsent(find(i), () => <int>[]).add(i);
  }

  final groups = <MatchGroup>[];
  for (final ids in byRoot.values) {
    final cellSet = <int>{};
    var hasH = false, hasV = false, colour = -1;
    for (final id in ids) {
      final run = runs[id];
      colour = run.colour;
      hasH = hasH || run.horizontal;
      hasV = hasV || !run.horizontal;
      cellSet.addAll(run.cells);
    }
    final sorted = cellSet.toList()..sort();
    groups.add(
      MatchGroup(
        colour: colour,
        cells: sorted,
        hasHorizontal: hasH,
        hasVertical: hasV,
      ),
    );
  }

  // Maximal 2x2 same-colour blocks not already claimed by a run group.
  // Scanned row-major; overlapping squares resolve to the first (top-left)
  // block, which keeps the result deterministic.
  final covered = <int>{
    for (final g in groups) ...g.cells,
  };
  for (var r = 0; r + 1 < h; r++) {
    for (var c = 0; c + 1 < w; c++) {
      final tl = r * w + c;
      final tr = tl + 1, bl = tl + w, br = tl + w + 1;
      if (covered.contains(tl) ||
          covered.contains(tr) ||
          covered.contains(bl) ||
          covered.contains(br)) {
        continue;
      }
      final code = cells[tl];
      if (!isColourCode(code)) continue;
      final colour = basePieceCode(code);
      if (isColourCode(cells[tr]) &&
          basePieceCode(cells[tr]) == colour &&
          isColourCode(cells[bl]) &&
          basePieceCode(cells[bl]) == colour &&
          isColourCode(cells[br]) &&
          basePieceCode(cells[br]) == colour) {
        groups.add(
          MatchGroup(
            colour: colour,
            cells: [tl, tr, bl, br],
            hasHorizontal: false,
            hasVertical: false,
          ),
        );
        covered.addAll([tl, tr, bl, br]);
      }
    }
  }

  groups.sort((a, b) => a.cells.first.compareTo(b.cells.first));
  return groups;
}

/// Whether the two cells [a] and [b] can be swapped: both hold unlocked
/// pieces (specials allowed).
bool swappablePair(MutableBoard board, int a, int b) {
  final ca = board.cells[a];
  final cb = board.cells[b];
  return isPieceCode(ca) &&
      isPieceCode(cb) &&
      !isYarnedCode(ca) &&
      !isYarnedCode(cb);
}

/// Whether swapping [a] and [b] is productive under the Royal Kingdom
/// rules: two specials always combine, a rainbow swapped onto a colour
/// clears that colour, and a non-rainbow special may swap with a plain
/// piece only when the swap forms a match of 3+ of the special's colour
/// (the special counts as a piece of that colour and detonates inside
/// the match). Every other pair is only productive when the swap forms
/// a colour match.
bool productiveSwap(MutableBoard board, int a, int b) {
  final ca = board.cells[a];
  final cb = board.cells[b];
  final aSpec = isSpecialCode(ca), bSpec = isSpecialCode(cb);
  if (aSpec && bSpec) return true;
  if (aSpec || bSpec) {
    final sIdx = aSpec ? a : b;
    final oIdx = aSpec ? b : a;
    final s = board.cells[sIdx];
    final other = board.cells[oIdx];
    if (specialKindBaseOf(s) == kRainbow) return isColourCode(other);
    if (!isColourCode(other)) return false;
    return formsSpecialColourMatch(board, sIdx, oIdx);
  }
  board.cells[a] = cb;
  board.cells[b] = ca;
  final found = scanMatches(board).isNotEmpty;
  board.cells[a] = ca;
  board.cells[b] = cb;
  return found;
}

/// Probe for the special+normal rule: simulate the swap with the special
/// (at [sIdx]) standing in as a piece of the colour it was made from, and
/// report whether any matched group of that colour would result. The
/// plain piece (at [oIdx]) must be a regular colour.
bool formsSpecialColourMatch(MutableBoard board, int sIdx, int oIdx) {
  final s = board.cells[sIdx];
  final other = board.cells[oIdx];
  final colour = specialColourOf(s);
  board.cells[sIdx] = other;
  board.cells[oIdx] = colour;
  final ok = scanMatches(board).any((g) => g.colour == colour);
  board.cells[sIdx] = s;
  board.cells[oIdx] = other;
  return ok;
}

/// Non-rainbow specials currently sitting inside a run of 3+ pieces of
/// the colour they were made from — they count as that colour and
/// detonate as part of the match. Index list, row-major.
List<int> specialsInColourRuns(MutableBoard board) {
  final w = board.width;
  final h = board.height;
  final cells = board.cells;

  /// Whether [code] joins a run of [colour]: a plain piece of that
  /// colour or another non-rainbow special made from it.
  bool member(int code, int colour) {
    if (isColourCode(code)) return basePieceCode(code) == colour;
    if (!isSpecialCode(code)) return false;
    return specialKindBaseOf(code) != kRainbow &&
        specialColourOf(code) == colour;
  }

  final out = <int>[];
  for (var i = 0; i < cells.length; i++) {
    final code = cells[i];
    if (!isSpecialCode(code) || specialKindBaseOf(code) == kRainbow) {
      continue;
    }
    final colour = specialColourOf(code);
    final r = i ~/ w, c = i % w;
    var span = 1;
    for (var cc = c - 1; cc >= 0 && member(cells[r * w + cc], colour); cc--) {
      span++;
    }
    for (var cc = c + 1; cc < w && member(cells[r * w + cc], colour); cc++) {
      span++;
    }
    if (span >= 3) {
      out.add(i);
      continue;
    }
    span = 1;
    for (var rr = r - 1; rr >= 0 && member(cells[rr * w + c], colour); rr--) {
      span++;
    }
    for (var rr = r + 1; rr < h && member(cells[rr * w + c], colour); rr++) {
      span++;
    }
    if (span >= 3) out.add(i);
  }
  return out;
}

/// Whether [board] has at least one legal move.
///
/// A legal move is an adjacent swap of two unlocked piece cells that either
/// creates a colour match or involves a special piece. Does not consume
/// randomness and leaves [board] unchanged.
bool hasLegalMove(MutableBoard board) {
  final w = board.width;
  final h = board.height;
  for (var r = 0; r < h; r++) {
    for (var c = 0; c < w; c++) {
      final i = r * w + c;
      if (!swappablePair(board, i, i)) continue;
      if (c + 1 < w && swappablePair(board, i, i + 1)) {
        if (productiveSwap(board, i, i + 1)) return true;
      }
      if (r + 1 < h && swappablePair(board, i, i + w)) {
        if (productiveSwap(board, i, i + w)) return true;
      }
    }
  }
  return false;
}

/// All legal swaps on [board] as index pairs `(a, b)` with `a < b`, in
/// row-major order. Does not consume randomness and does not mutate
/// [board].
List<(int, int)> legalSwapPairs(MutableBoard board) {
  final w = board.width;
  final h = board.height;
  final result = <(int, int)>[];
  for (var r = 0; r < h; r++) {
    for (var c = 0; c < w; c++) {
      final i = r * w + c;
      if (!swappablePair(board, i, i)) continue;
      if (c + 1 < w && swappablePair(board, i, i + 1)) {
        if (productiveSwap(board, i, i + 1)) result.add((i, i + 1));
      }
      if (r + 1 < h && swappablePair(board, i, i + w)) {
        if (productiveSwap(board, i, i + w)) result.add((i, i + w));
      }
    }
  }
  return result;
}

/// The initial Lehmer state of the refill stream for column [column] of
/// [round]: derived from `(seed, round, column)` only, so both players get
/// identical refill pieces in the same order in every column.
int refillStateSeed(int seed, int round, int column) =>
    GameRandom.deriveSeed(seed, ['refill', round, column]);

/// Deals a fresh board for [round] of [seed]. Identical for both players:
/// the deal stream depends only on `(seed, round)`, never on the player.
///
/// The deal guarantees no starting matches (no runs of 3 and no 2x2
/// squares) and at least one legal move; it redraws deterministically
/// until both hold.
MutableBoard dealBoard(int seed, int round, MatchConfig config) {
  final w = config.boardWidth;
  final h = config.boardHeight;
  final colours = config.colourCount;
  final rng = GameRandom(GameRandom.deriveSeed(seed, ['deal', round]));
  final refill = [
    for (var col = 0; col < w; col++)
      GameRandom(refillStateSeed(seed, round, col)).state,
  ];

  while (true) {
    final cells = List<int>.filled(w * h, 0);
    for (var i = 0; i < cells.length; i++) {
      final r = i ~/ w;
      final c = i % w;
      int pick;
      do {
        pick = rng.nextInt(colours);
      } while ((c >= 2 && cells[i - 1] == pick && cells[i - 2] == pick) ||
          (r >= 2 && cells[i - w] == pick && cells[i - 2 * w] == pick) ||
          (r >= 1 &&
              c >= 1 &&
              cells[i - w - 1] == pick &&
              cells[i - w] == pick &&
              cells[i - 1] == pick));
      cells[i] = pick;
    }
    final board = MutableBoard(w, h, cells, List<int>.of(refill));
    if (hasLegalMove(board)) return board;
  }
}

/// Applies gravity and refill to [board], appending [Fell] and [Refilled]
/// events for [player].
///
/// Yarned pieces and boxes are fixed blockers: each maximal segment of
/// free cells settles independently, so pieces never cross a lock. New
/// pieces come from each column's own refill stream, consumed in row
/// order (top to bottom); columns are processed left to right. Within a
/// column, [Fell] events are emitted segment by segment (top to bottom),
/// each segment's moved pieces ordered by destination row bottom to top,
/// then [Refilled] events in row order.
void applyGravityAndRefill({
  required MutableBoard board,
  required int colourCount,
  required PlayerSlot player,
  required List<GameEvent> events,
}) {
  final w = board.width;
  final h = board.height;
  final cells = board.cells;

  bool freeCell(int index) {
    final code = cells[index];
    return code != kCellBox && !isYarnedCode(code);
  }

  for (var col = 0; col < w; col++) {
    // Compact each free segment toward the bottom of the segment.
    var r = 0;
    while (r < h) {
      if (!freeCell(r * w + col)) {
        r++;
        continue;
      }
      var rBottom = r;
      while (rBottom + 1 < h && freeCell((rBottom + 1) * w + col)) {
        rBottom++;
      }
      // Segment rows [r, rBottom]; collect (code, fromRow) bottom to top.
      final pieces = <(int, int)>[];
      for (var rr = rBottom; rr >= r; rr--) {
        final code = cells[rr * w + col];
        if (code != kCellEmpty) pieces.add((code, rr));
      }
      var p = 0;
      for (var rr = rBottom; rr >= r; rr--) {
        final index = rr * w + col;
        if (p < pieces.length) {
          final (code, fromRow) = pieces[p++];
          cells[index] = code;
          if (fromRow != rr) {
            events.add(
              Fell(
                player: player,
                from: (row: fromRow, col: col),
                to: (row: rr, col: col),
              ),
            );
          }
        } else {
          cells[index] = kCellEmpty;
        }
      }
      r = rBottom + 1;
    }

    // Refill every remaining empty cell in this column, top to bottom.
    var rng = GameRandom.fromState(board.refillState[col]);
    for (var rr = 0; rr < h; rr++) {
      final index = rr * w + col;
      if (cells[index] == kCellEmpty) {
        final piece = rng.nextInt(colourCount);
        cells[index] = piece;
        events.add(
          Refilled(
            player: player,
            cell: (row: rr, col: col),
            piece: piece,
          ),
        );
      }
    }
    board.refillState[col] = rng.state;
  }
}

/// Deterministically reshuffles the pieces on [board] until at least one
/// legal move exists, then emits one [Shuffled] event.
///
/// The permutation pool is every piece cell (box cells are fixed). Yarn
/// locks travel with their piece. Up to [maxAttempts] permutations are
/// tried; each consumes [rng], so the result is reproducible on replay.
void reshuffleBoard({
  required MutableBoard board,
  required GameRandom rng,
  required PlayerSlot player,
  required List<GameEvent> events,
  String reason = 'no-legal-move',
  int maxAttempts = 10000,
}) {
  final cells = board.cells;
  final pieceCells = <int>[
    for (var i = 0; i < cells.length; i++)
      if (isPieceCode(cells[i])) i,
  ];
  if (pieceCells.length < 2) {
    // Degenerate board: nothing can be permuted. Report the shuffle anyway
    // so the event stream stays honest about the attempted rescue.
    events.add(
      Shuffled(
        player: player,
        cells: [
          for (final i in pieceCells)
            (row: i ~/ board.width, col: i % board.width),
        ],
        reason: reason,
      ),
    );
    return;
  }

  final values = [for (final i in pieceCells) cells[i]];
  var attempts = 0;
  while (attempts < maxAttempts) {
    attempts++;
    final perm = List<int>.of(values);
    for (var i = perm.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final t = perm[i];
      perm[i] = perm[j];
      perm[j] = t;
    }
    for (var k = 0; k < pieceCells.length; k++) {
      cells[pieceCells[k]] = perm[k];
    }
    if (hasLegalMove(board)) break;
  }

  events.add(
    Shuffled(
      player: player,
      cells: [
        for (final i in pieceCells)
          (row: i ~/ board.width, col: i % board.width),
      ],
      reason: reason,
    ),
  );
}
