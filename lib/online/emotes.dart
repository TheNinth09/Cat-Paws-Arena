/// Preset emotes. Only [wire] names travel between players; there is no
/// free text.
enum Emote {
  hello('hello'),
  goodGame('good_game'),
  wow('wow'),
  oops('oops'),
  thanks('thanks'),
  purr('purr'),
  // Trophy-road exclusives — granted by milestones on the road.
  love('love'),
  angry('angry');

  const Emote(this.wire);
  final String wire;

  /// Returns null for anything that is not a preset emote.
  static Emote? fromWire(Object? value) {
    for (final emote in values) {
      if (emote.wire == value) return emote;
    }
    return null;
  }
}
