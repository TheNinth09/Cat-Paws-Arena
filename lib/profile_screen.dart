import 'package:flutter/material.dart';

import 'app_dialogs.dart';
import 'cat_avatar.dart';
import 'catalog.dart';
import 'profile.dart';
import 'shell/house_tour.dart';
import 'ui_widgets.dart';

/// Dedicated profile page, Match Masters style: a top tab row
/// (PROFIL / EMOTE-URI / TINUTE) with the identity card and real local
/// stats on the first tab, the preset emote collection (unlocked vs
/// greyed "to collect") on the second, and the accessory wardrobe —
/// tap an owned piece to equip it — on the third.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.player});

  final Player player;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _tab = 0;

  Player get player => widget.player;
  bool get english => player.english;

  /// The preset duel emotes (sprite + caption + wire name) — the full
  /// set; unlocked ones show in colour, the rest greyed out. `love` and
  /// `angry` are trophy-road exclusives.
  static const _emotes = [
    ('emote_happy', 'SALUT', 'hello'),
    ('emote_surprised', 'WOW', 'wow'),
    ('emote_cheer', 'BRAVO', 'good_game'),
    ('emote_surprised', 'OPS', 'oops'),
    ('emote_happy', 'MERCI', 'thanks'),
    ('emote_laugh', 'PURR', 'purr'),
    ('emote_love', 'DRAG', 'love'),
    ('emote_angry', 'GRRR', 'angry'),
  ];

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: player,
    builder: (context, _) {
      final tabs = english
          ? const ['PROFILE', 'EMOTES', 'OUTFITS']
          : const ['PROFIL', 'EMOTE-URI', 'TINUTE'];
      final icons = [
        Icons.person_rounded,
        Icons.emoji_emotions_rounded,
        Icons.checkroom_rounded,
      ];
      return Scaffold(
        backgroundColor: const Color(0xff3a2a33),
        body: Stack(
          fit: StackFit.expand,
          children: [
            arenaImage(
              'bg_battle_lobby',
              fit: BoxFit.cover,
              fallback: Container(color: const Color(0xff4a3542)),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x8820130e), Color(0x6620130e)],
                ),
              ),
            ),
            HudSafeArea(
              child: Column(
                children: [
                  _header(context),
                  // MM-style blue tab row.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
                    child: Row(
                      children: [
                        for (var i = 0; i < 3; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(child: _tabButton(tabs[i], icons[i], i)),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: KeyedSubtree(
                        key: ValueKey(_tab),
                        child: switch (_tab) {
                          1 => _emotesTab(),
                          2 => _outfitsTab(),
                          _ => _profileTab(context),
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _tabButton(String label, IconData icon, int i) {
    final active = _tab == i;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _tab = i),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: active
                  ? const [Color(0xffffd75e), Color(0xffe8a01f)]
                  : const [Color(0xcc5f96d4), Color(0xcc2e5c96)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? const Color(0xfffff3c4) : const Color(0x55ffffff),
              width: 1.6,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44000000),
                offset: Offset(0, 3),
                blurRadius: 6,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: active ? const Color(0xff5d3a2c) : Colors.white,
              ),
              Text(
                label,
                style: TextStyle(
                  color: active ? const Color(0xff5d3a2c) : Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
    child: Row(
      children: [
        IconButton(
          key: const ValueKey('profile-close'),
          tooltip: english ? 'Back' : 'Înapoi',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: cream,
            size: 26,
            shadows: [Shadow(color: Color(0x99000000), offset: Offset(0, 2))],
          ),
        ),
        Expanded(
          child: Text(
            english ? 'MY PROFILE' : 'PROFILUL MEU',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: cream,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              shadows: [Shadow(color: Color(0x99000000), offset: Offset(0, 2))],
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    ),
  );

  // ── Tab 1: PROFILE ───────────────────────────────────────────────────

  Widget _profileTab(BuildContext context) => ListView(
    key: const PageStorageKey('profile-tab-scroll'),
    padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
    children: [
      _identityCard(context),
      const SizedBox(height: 10),
      _statsGrid(),
      const SizedBox(height: 12),
      ArenaButton(
        key: const ValueKey('profile-account'),
        text: english ? 'LINK ACCOUNT' : 'CONECTARE CONT',
        secondary: true,
        onPressed: () => showSettings(context, player),
      ),
    ],
  );

  /// Big avatar + name card — kept from the single-page design, now the
  /// header of the PROFILE tab.
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
    child: Stack(
      children: [
        Row(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey('profile-avatar-pick'),
                onTap: () => _pickAvatarArt(context),
                customBorder: const CircleBorder(),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xfffff6bd),
                        Color(0xffe8a01f),
                        Color(0xffb97a10),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(color: Color(0x55ffc63c), blurRadius: 10),
                      BoxShadow(
                        color: Color(0x44000000),
                        offset: Offset(0, 3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: ClipOval(child: playerAvatarArt(player, size: 74)),
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
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xfffdf0cd),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xffd9a86a),
                        width: 1.4,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        sprite('icon_trophy', size: 16),
                        const SizedBox(width: 5),
                        Text(
                          '${player.trophies}',
                          style: const TextStyle(
                            color: ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
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
                  const SizedBox(height: 2),
                  Text(
                    english
                        ? 'Cat in duel: ${player.cat}'
                        : 'Pisica din duel: ${player.cat}',
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
        Positioned(
          top: 0,
          right: 0,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('profile-edit'),
              onTap: () => showPlayerProfile(context, player),
              customBorder: const CircleBorder(),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xff93d94f), Color(0xff4e9c22)],
                  ),
                  border: Border.all(color: Colors.white, width: 1.6),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x44000000),
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Colors.white,
                  size: 17,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  /// Avatar chooser — the three preset cat artworks plus the live
  /// customized cat (it stays in sync with the PISICI editor). This is
  /// the PLAYER's identity and is stored separately in
  /// [Player.avatarArt] — the duel cat selection lives on the PISICI
  /// page (`Player.cat`) and is never affected by this picker.
  void _pickAvatarArt(BuildContext context) => showAppDialog(
    context,
    english ? 'CHOOSE AVATAR' : 'ALEGE AVATARUL',
    Wrap(
      spacing: 12,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        for (final art in avatarArtChoices) _avatarChoice(context, art),
      ],
    ),
  );

  Widget _avatarChoice(BuildContext context, String art) {
    final label = art == 'cat_tzuki'
        ? 'TZUKI'
        : art == 'cat_bubble'
        ? 'BUBBLE'
        : art == 'cat_custom'
        ? 'CUSTOM'
        : (english ? 'EDITED CAT' : 'PISICA EDITATĂ');
    final selected = player.avatarArt == art;
    return InkWell(
      onTap: () {
        player.avatarArt = art;
        player.save();
        Navigator.of(context).pop();
      },
      customBorder: const CircleBorder(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xfffff3d9),
              border: Border.all(
                color: selected ? gold : ink,
                width: selected ? 3 : 2,
              ),
            ),
            clipBehavior: Clip.hardEdge,
            child: art == 'my_cat'
                ? realCatArt(player, height: 60, portrait: true)
                : arenaImage(
                    art,
                    fit: BoxFit.cover,
                    fallback: catPortrait('custom', size: 60),
                  ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: ink,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  /// MM-style 3xN stat grid — only stats the local Player really tracks.
  Widget _statsGrid() {
    Widget stat(
      String label,
      String value, {
      String? spriteName,
      String? iconAsset,
      IconData? fallback,
    }) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xfffffbec),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffd9b98c), width: 1.4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spriteName != null)
            sprite(spriteName, size: 22)
          else
            arenaImage(
              iconAsset!,
              width: 22,
              height: 22,
              fallback: Icon(
                fallback,
                color: const Color(0xffa97153),
                size: 20,
              ),
            ),
          const SizedBox(height: 3),
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
    );
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.32,
      children: [
        stat(
          english ? 'TROPHIES' : 'TROFEE',
          '${player.trophies}',
          spriteName: 'icon_trophy',
        ),
        stat(
          english ? 'GAMES WON' : 'VICTORII',
          '${player.gamesWon}',
          spriteName: 'icon_chest',
        ),
        stat(
          english ? 'WIN STREAK' : 'SERIE',
          '${player.winStreak}',
          iconAsset: 'icon_events',
          fallback: Icons.local_fire_department_rounded,
        ),
        stat(
          english ? 'BEST STREAK' : 'SERIE MAXIMĂ',
          '${player.bestStreak}',
          iconAsset: 'icon_events',
          fallback: Icons.military_tech_rounded,
        ),
        stat(
          english ? 'BEST SCORE' : 'SCOR MAXIM',
          '${player.bestScore}',
          iconAsset: 'icon_achievements',
          fallback: Icons.star_rounded,
        ),
        stat(
          english ? 'GAMES PLAYED' : 'MECIURI JUCATE',
          '${player.gamesPlayed}',
          iconAsset: 'icon_leaderboard',
          fallback: Icons.sports_esports_rounded,
        ),
        stat(
          english ? 'PAWS' : 'LĂBUȚE',
          '${player.coins}',
          spriteName: 'icon_paw_coin',
        ),
        stat(
          english ? 'ROOM' : 'CAMERĂ',
          '${player.tier + 1}/${houseRooms.length}',
          iconAsset: 'icon_achievements',
          fallback: Icons.home_rounded,
        ),
        stat(
          english ? 'EMOTES' : 'EMOTE',
          '${player.unlockedEmotes.length}/${_emotes.length}',
          iconAsset: 'emote_laugh',
        ),
      ],
    );
  }

  // ── Tab 2: EMOTES ────────────────────────────────────────────────────

  Widget _emotesTab() {
    final unlocked = <(String, String, String)>[];
    final locked = <(String, String, String)>[];
    for (final e in _emotes) {
      (player.unlockedEmotes.contains(e.$3) ? unlocked : locked).add(e);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      children: [
        _panel(
          title: english ? 'MY EMOTES' : 'EMOTE-URILE MELE',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final e in unlocked) _emoteTile(e, locked: false)],
          ),
        ),
        _panel(
          title: english ? 'EMOTES TO COLLECT' : 'EMOTE-URI DE COLECȚIONAT',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in locked) _emoteTile(e, locked: true),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                english
                    ? 'Unlock new emotes on the Trophy Road milestones.'
                    : 'Deblochezi emote-uri noi la jaloanele de pe Drumul Trofeelor.',
                style: const TextStyle(
                  color: Color(0xff8a6a52),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emoteTile(
    (String, String, String) emote, {
    required bool locked,
  }) => Container(
    width: 78,
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: locked ? const Color(0xffd9d2c8) : const Color(0xfff2e6d0),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: locked ? const Color(0xffbfb4a4) : const Color(0xffd9b98c),
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ColorFiltered(
          colorFilter: locked
              ? const ColorFilter.mode(
                  Color(0xff8d8578),
                  BlendMode.saturation,
                )
              : const ColorFilter.mode(
                  Colors.transparent,
                  BlendMode.multiply,
                ),
          child: arenaImage(emote.$1, width: 32, height: 32, fallback: const Icon(Icons.emoji_emotions_rounded, size: 30, color: Color(0xffa97153))),
        ),
        const SizedBox(height: 3),
        Text(
          emote.$2,
          style: TextStyle(
            color: locked ? const Color(0xff8d8578) : ink,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (locked)
          const Icon(Icons.lock_rounded, size: 11, color: Color(0xff8d8578)),
      ],
    ),
  );

  // ── Tab 3: OUTFITS ───────────────────────────────────────────────────

  Widget _outfitsTab() => ListView(
    padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
    children: [
      _panel(
        title: english ? 'CAT OUTFITS' : 'ȚINUTELE PISICII',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < accessories.length; i++)
                  _outfitTile(accessories[i], accessoryNames[i]),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              english
                  ? 'Outfits are won by finishing rooms on the Trophy Road or bought with paws in the shop.'
                  : 'Ținutele se câștigă terminând camere de pe Drumul Trofeelor sau se cumpără cu lăbuțe din magazin.',
              style: const TextStyle(
                color: Color(0xff8a6a52),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _outfitTile(String id, String name) {
    final owned = player.owned.contains(id);
    final equipped = player.accessory == id;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: owned
          ? () {
              player.accessory = equipped ? '' : id;
              player.save();
            }
          : null,
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: equipped
              ? const Color(0xffffe9bd)
              : owned
              ? const Color(0xfff2e6d0)
              : const Color(0xffd9d2c8),
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
              opacity: owned ? 1 : .4,
              child: accessoryArt(id, size: 34),
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
                  ? (english ? 'TAP TO EQUIP' : 'APASĂ — ECHIPEAZĂ')
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
      ),
    );
  }

  Widget _panel({required String title, required Widget child}) => Container(
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
        Text(
          title,
          style: const TextStyle(
            color: ink,
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}
