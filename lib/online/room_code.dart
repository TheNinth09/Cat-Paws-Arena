import 'dart:math';

/// Six-character room and friend codes without look-alike characters
/// (no I, L, O, 0 or 1).
abstract final class RoomCode {
  static const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const length = 6;
  static final _valid = RegExp('^[$alphabet]{$length}\$');

  static String generate([Random? random]) {
    final rng = random ?? Random.secure();
    return String.fromCharCodes(
      List.generate(
        length,
        (_) => alphabet.codeUnitAt(rng.nextInt(alphabet.length)),
      ),
    );
  }

  static bool isValid(String code) => _valid.hasMatch(code);

  /// Uppercases and drops spaces and dashes from what the player typed.
  /// Returns null when the result is not a valid code.
  static String? normalize(String input) {
    final code = input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    return isValid(code) ? code : null;
  }
}
