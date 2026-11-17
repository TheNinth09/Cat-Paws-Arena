import 'package:flutter/material.dart';

import 'app_dialogs.dart';
import 'cat_avatar.dart';
import 'catalog.dart';
import 'profile.dart';
import 'shell/house_tour.dart';
import 'ui_widgets.dart';

/// Dedicated profile page (replaces the small profile dialog as the
/// avatar-tap target): user avatar + name, trophies and the stats that
/// actually exist locally, plus organised sections for REALIZĂRI,
/// BANDAJE, EMOTE-URI and ACCESORII. Sections without a data source are
/// labelled honestly — never faked. Name editing and the Google link stay
/// reachable through the existing app_dialogs flows (lane-4 surface,
/// called as-is).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.player});

  final Player player;

  bool get english => player.english;

  /// The six preset duel emotes (sprite + label) shipped in the bundle —
  /// the full emote set players can send in a match.
  static const _emotes = [
    ('emote_laugh', 'SALUT'),
    ('emote_laugh', 'WOW'),
    ('emote_love', 'BRAVO'),
    ('emote_angry', 'OPS'),
    ('emote_love', 'MERCI'),
    ('emote_love', 'PURR'),
  ];

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: player,
    builder: (context, _) => Scaffold(
      backgroundColor: const Color(0xff3a2a33),
      body: SafeArea(
        child: RoomBackground(
          tier: player.tier,
          dim: true,
          child: Column(
            children: [
              _header(context),
              Expanded(
                child: ListView(
                  key: const PageStorageKey('profile-scroll'),
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                  children: [
                    _identityCard(context),
                    const SizedBox(height: 10),
                    _statsRow(),
                    const SizedBox(height: 12),
                    _section(
                      title: english ? 'ACHIEVEMENTS' : 'REALIZĂRI',
                      icon: Icons.military_tech_rounded,
                      child: _comingSoon(
                        english
                            ? 'Achievement badges are not tracked yet — the section arrives with a real data source.'
                            : 'Insignele de realizare nu sunt încă urmărite — secțiunea apare când există o sursă de date.',
                      ),
                    ),
                    _section(
                      title: 'BANDAJE',
                      icon: Icons.healing_rounded,
                      child: _comingSoon(
                        english
                            ? 'No bandage cosmetics exist yet — this space stays empty until they ship.'
                            : 'Nu există încă bandaje cosmetice — spațiul rămâne gol până apar.',
                      ),
                    ),
                    _section(
                      title: english ? 'EMOTES' : 'EMOTE-URI',
                      icon: Icons.emoji_emotions_rounded,
                      child: _emotesGrid(),
                    ),
                    _section(
                      title: english ? 'ACCESSORIES' : 'ACCESORII',
                      icon: Icons.style_rounded,
                      child: _accessoriesGrid(),
                    ),
                    const SizedBox(height: 8),
                    ArenaButton(
                      text: english ? 'EDIT NAME' : 'EDITEAZĂ NUMELE',
                      secondary: true,
                      onPressed: () => showPlayerProfile(context, player),
                    ),
                    ArenaButton(
                      key: const ValueKey('profile-account'),
                      text: english ? 'LINK ACCOUNT' : 'CONECTARE CONT',
                      secondary: true,
                      onPressed: () => showSettings(context, player),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
    child: Row(
      children: [
        IconButton(
          key: const ValueKey('profile-close'),
          tooltip: english ? 'Back' : 'Înapoi',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, color: cream, size: 26),
        ),
        Expanded(
          child: Text(
            english ? 'PROFILE' : 'PROFILUL MEU',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: cream,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              shadows: [
                Shadow(color: Color(0x66000000), offset: Offset(0, 2)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    ),
  );

  /// Big avatar + name card: the custom user avatar (AvatarSpec), the
  /// player name and a shortcut to the name editor.
  Widget _identityCard(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xfffff3d2), Color(0xfff6d9a0)],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: gold, width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x553c241a),
          offset: Offset(0, 4),
          blurRadius: 10,
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xffffe9bd), Color(0xffd9a86a)],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: AvatarAvatar(
              AvatarSpec.fromJsonString(player.avatarSpec),
              size: 74,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                player.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                english
                    ? 'Current room: ${houseRoomDisplayNamesEn[player.tier]}'
                    : 'Camera curentă: ${houseRoomDisplayNames[player.tier]}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xff8a6242),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                english ? 'Cat in duel: ${player.cat}' : 'Pisica din duel: ${player.cat}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xff8a6242),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  /// The stats that exist locally — trophies, paws and owned cosmetics.
  /// Wins/losses/draws are not tracked anywhere in Player, so they are
  /// deliberately absent rather than faked.
  Widget _statsRow() {
    Widget stat(String label, String value, String iconAsset) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xfffffbec),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xffd9b98c), width: 1.4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            sprite(iconAsset, size: 22),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  color: ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xff8a6242),
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: .6,
              ),
            ),
          ],
        ),
      ),
    );
    return Row(
      children: [
        stat(
          english ? 'TROPHIES' : 'TROFEE',
          '${player.trophies}',
          'icon_trophy',
        ),
        const SizedBox(width: 8),
        stat(
          english ? 'PAWS' : 'LĂBUȚE',
          '${player.coins}',
          'icon_paw_coin',
        ),
        const SizedBox(width: 8),
        stat(
          english ? 'COSMETICS' : 'COSMETICE',
          '${player.owned.length}',
          'icon_chest',
        ),
      ],
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Widget child,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
    decoration: BoxDecoration(
      color: const Color(0xfffffbec),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xffd9b98c), width: 1.4),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xffa97153), size: 20),
            const SizedBox(width: 7),
            Text(
              title,
              style: const TextStyle(
                color: ink,
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                letterSpacing: .8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );

  /// Honest placeholder: labelled, never pretends to hold real items.
  Widget _comingSoon(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xfff2e6d0),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: const Color(0xffd9b98c),
        width: 1.2,
        style: BorderStyle.solid,
      ),
    ),
    child: Row(
      children: [
        const Icon(Icons.hourglass_empty_rounded, color: Color(0xffa08d77), size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xff8a6a52),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );

  /// The preset emote set that actually ships in the duel UI — shown as
  /// the player's emote collection (preset-only by contract).
  Widget _emotesGrid() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final emote in _emotes)
        Container(
          width: 72,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xfff2e6d0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xffd9b98c)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              sprite(emote.$1, size: 30),
              const SizedBox(height: 3),
              Text(
                emote.$2,
                style: const TextStyle(
                  color: ink,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
    ],
  );

  /// The accessory catalogue with honest owned/equipped badges driven by
  /// player.owned + player.accessory.
  Widget _accessoriesGrid() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (var i = 0; i < accessories.length; i++)
        _accessoryTile(accessories[i], accessoryNames[i]),
    ],
  );

  Widget _accessoryTile(String id, String name) {
    final owned = player.owned.contains(id);
    final equipped = player.accessory == id;
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: equipped ? const Color(0xffffe9bd) : const Color(0xfff2e6d0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: equipped ? gold : const Color(0xffd9b98c),
          width: equipped ? 1.8 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: owned ? 1 : .45,
            child: sprite(id, size: 34),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ink,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            equipped
                ? (english ? 'EQUIPPED' : 'ECHIPAT')
                : owned
                ? (english ? 'OWNED' : 'DEȚINUT')
                : (english ? 'NOT OWNED' : 'NEDEȚINUT'),
            style: TextStyle(
              color: equipped
                  ? const Color(0xffb0791f)
                  : owned
                  ? const Color(0xff6d8f3e)
                  : const Color(0xffa08d77),
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
