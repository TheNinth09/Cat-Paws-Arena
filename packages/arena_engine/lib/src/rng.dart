/// Platform-independent deterministic random number generation.
///
/// The engine uses a Lehmer (Park-Miller) linear congruential generator:
///
/// ```
/// state = state * 48271 mod 2147483647
/// ```
///
/// `2147483647` is the Mersenne prime `2^31 - 1` and `48271` is a primitive
/// root modulo it, so the sequence has full period `2147483646`.
///
/// Every intermediate value stays below `2^53`, so results are identical on
/// the Dart VM and when compiled to JavaScript. Only `+`, `-`, `*`, `%`,
/// `~/` and comparisons are used — no bitwise operators and no `dart:math`
/// `Random`, which keeps the sequence stable across platforms.
library;

/// A deterministic generator for one independent random stream.
///
/// The mutable [_state] always stays in `[1, modulus)`; state `0` is
/// unreachable and is remapped on construction.
class GameRandom {
  /// The Mersenne prime `2^31 - 1`.
  static const int modulus = 2147483647;

  /// Primitive root used by the MINSTD generator.
  static const int multiplier = 48271;

  int _state;

  /// Creates a generator from any 64-bit [seed] value, including zero and
  /// negative seeds. The full seed value is folded into the modulus range
  /// so distinct seeds almost always produce distinct streams.
  GameRandom(int seed) : _state = _foldSeed(seed);

  /// Rebuilds a generator from a previously exported [_state] value, as
  /// stored inside [MatchState] snapshots.
  GameRandom.fromState(int state) : _state = _normalizeState(state);

  /// The current raw generator state. Store this in snapshots; pass it back
  /// to [GameRandom.fromState] to continue the same stream.
  int get state => _state;

  static int _normalizeState(int state) {
    var s = state % modulus;
    if (s <= 0) s += modulus;
    return s == modulus ? 1 : s;
  }

  static int _foldSeed(int seed) {
    // Fold the whole 64-bit seed into the modulus range. `~/` truncates
    // toward zero in Dart, so the second fold can be negative; `%` with a
    // positive divisor always returns a non-negative result.
    var low = seed % modulus;
    if (low < 0) low += modulus;
    var high = (seed ~/ modulus) % modulus;
    if (high < 0) high += modulus;
    var mixed = (low * multiplier + high) % modulus;
    if (mixed <= 0) mixed += modulus;
    return mixed;
  }

  /// Advances the stream and returns the new raw state.
  int nextState() {
    _state = (_state * multiplier) % modulus;
    return _state;
  }

  /// Returns a value in `[0, bound)` and advances the stream.
  ///
  /// Uses the high bits of the state (`(state - 1) * bound ~/ (modulus - 1)`)
  /// so small bounds do not expose the weaker low bits of the LCG.
  int nextInt(int bound) {
    if (bound <= 0) {
      throw ArgumentError.value(bound, 'bound', 'must be positive');
    }
    nextState();
    return ((_state - 1) * bound) ~/ (modulus - 1);
  }

  /// Fisher–Yates shuffle of [items] in place, driven by this stream.
  void shuffle(List<int> items) {
    for (var i = items.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final t = items[i];
      items[i] = items[j];
      items[j] = t;
    }
  }

  /// Derives an independent stream seed from [seed] and a [domain] label.
  ///
  /// Domain parts may be ints or strings; each contributes to a polynomial
  /// hash modulo [modulus]. Two callers with the same seed and domain get
  /// identical streams; different domains get unrelated streams.
  static int deriveSeed(int seed, Iterable<Object> domain) {
    var h = seed % modulus;
    if (h < 0) h += modulus;
    for (final part in domain) {
      if (part is int) {
        var v = part % modulus;
        if (v < 0) v += modulus;
        // h < 2^31 and 1000003 < 2^20, so the product stays < 2^51.
        h = (h * 1000003 + v) % modulus;
      } else {
        for (final unit in part.toString().codeUnits) {
          // h < 2^31 and 131 < 2^8, so the product stays < 2^39.
          h = (h * 131 + unit) % modulus;
        }
      }
    }
    if (h <= 0) h += modulus;
    return h;
  }
}
