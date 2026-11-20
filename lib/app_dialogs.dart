import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'cat_avatar.dart';
import 'online/online_errors.dart';
import 'online/parent_gate.dart';
import 'profile.dart';
import 'shell/house_tour.dart';
import 'shell/online_play.dart';
import 'ui_widgets.dart';

Future<void> showAppDialog(BuildContext context, String title, Widget child) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xfffff4d8),
        surfaceTintColor: Colors.transparent,
        elevation: 14,
        shadowColor: const Color(0x7751312d),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
        titlePadding: const EdgeInsets.fromLTRB(20, 14, 8, 2),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              tooltip: 'ÎNCHIDE',
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(
                Icons.close_rounded,
                color: Color(0xff9a6a45),
                size: 24,
              ),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(child: child),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ArenaButton(
              text: 'ÎNCHIDE',
              secondary: true,
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ),
        ],
      ),
    );

Future<void> showUnavailable(BuildContext context, String feature) =>
    showAppDialog(
      context,
      feature,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 46, color: Color(0xffa97153)),
          const SizedBox(height: 12),
          Text(
            'Această funcție necesită configurarea serviciilor online. Jocul este momentan offline; nu s-a efectuat nicio plată, trimitere de mesaj sau tranzacție.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xff6b4a35),
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

Future<void> showPlayerProfile(BuildContext context, Player p) =>
    showAppDialog(context, 'Profilul meu', _ProfileEditor(player: p));

/// Match Masters-inspired "GAME UPDATES" feed: scrollable cards with a
/// coloured banner, version/date chip, title and changelog body. Content
/// is an honest local changelog — no fake live-service announcements.
Future<void> showNews(BuildContext context, {required bool english}) =>
    showAppDialog(
      context,
      english ? 'NEWS' : 'NOUTĂȚI',
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in _newsItems(english)) ...[
            _NewsCard(item: item),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );

class _NewsItem {
  const _NewsItem({
    required this.version,
    required this.title,
    required this.body,
    required this.asset,
    required this.fallbackIcon,
    required this.colors,
  });
  final String version, title, body, asset;
  final IconData fallbackIcon;
  final List<Color> colors;
}

List<_NewsItem> _newsItems(bool english) => [
  _NewsItem(
    version: '0.7.0-29',
    title: english ? 'Smoother duels' : 'Dueluri mai fluide',
    body: english
        ? 'Swipes queue during animations so moves chain instantly. The house cat now plays its whole turn, specials grant bonus time (+2s each, shown on the clock), pieces fall and refill together, and the emote bubble appears once — on the board.'
        : 'Swipe-urile se bufă în timpul animațiilor, deci mutările se înlănțuie instant. Pisica casei joacă toată tura, piesele speciale dau timp bonus (+2s fiecare, afișat pe cronometru), piesele cad și se reumplu împreună, iar bula de emote apare o singură dată — pe tablă.',
    asset: 'icon_fight',
    fallbackIcon: Icons.bolt_rounded,
    colors: const [Color(0xffe8955a), Color(0xffb45f2e)],
  ),
  _NewsItem(
    version: '0.7.0-28',
    title: english ? 'New look, new sound' : 'Look nou, sunet nou',
    body: english
        ? 'Six dedicated full-screen backgrounds, a 3D bottom bar with a raised FIGHT button, a rebuilt profile editor with round cartoon avatars, and real battle music plus sound effects.'
        : 'Șase fundaluri dedicate full-screen, bară de jos 3D cu butonul LUPTĂ ridicat, editor de profil refăcut cu avatare rotunde cartoon și muzică de luptă reală plus efecte sonore.',
    asset: 'icon_music',
    fallbackIcon: Icons.music_note_rounded,
    colors: const [Color(0xff7a9fe0), Color(0xff3d5a9e)],
  ),
  _NewsItem(
    version: '0.7.0-27',
    title: english ? 'Shared board duels' : 'Dueluri pe tabla comună',
    body: english
        ? 'Duels are now played on one shared 7×7 board: 3 rounds of 15 seconds each. Royal-style special rules — tap to detonate, combine specials for bigger blasts, 2×2 makes a copter.'
        : 'Duelurile se joacă acum pe o singură tablă comună 7×7: 3 runde câte 15 secunde. Reguli royale pentru speciale — tap pentru detonare, combină speciale pentru explozii mai mari, 2×2 face elicopter.',
    asset: 'icon_paw_coin',
    fallbackIcon: Icons.grid_on_rounded,
    colors: const [Color(0xff8ec96f), Color(0xff4a8f3a)],
  ),
];

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item});
  final _NewsItem item;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xfffffbf0),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xffe2c493), width: 1.2),
      boxShadow: const [
        BoxShadow(color: Color(0x22000000), offset: Offset(0, 2), blurRadius: 4),
      ],
    ),
    clipBehavior: Clip.hardEdge,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Coloured banner strip with the feature icon — MM-style header.
        Container(
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: item.colors,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -12,
                top: -12,
                child: Icon(
                  item.fallbackIcon,
                  size: 90,
                  color: const Color(0x22ffffff),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0x33ffffff),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0x55ffffff),
                          width: 1.4,
                        ),
                      ),
                      child: arenaImage(
                        item.asset,
                        fit: BoxFit.contain,
                        fallback: Icon(
                          item.fallbackIcon,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                              color: Color(0x55000000),
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xfff0dfc0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'v${item.version}',
                    style: const TextStyle(
                      color: Color(0xff8a5c3e),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.body,
                style: const TextStyle(
                  color: Color(0xff6b4a35),
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({required this.player});
  final Player player;
  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late final name = TextEditingController(text: widget.player.name);
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  OutlineInputBorder fieldBorder(Color color, {double width = 1.2}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );

  /// The preset portraits + the own-cat option + the photo slot — one row
  /// of round chips under the big preview. Picking a chip sets
  /// [Player.avatarArt] (the avatar only — it never changes the duel cat)
  /// and clears a custom photo.
  Widget _avatarChip(String art) {
    final p = widget.player;
    final active = p.photo == null && p.avatarArt == art;
    return GestureDetector(
      onTap: () {
        p.avatarArt = art;
        p.photo = null;
        p.save();
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? gold : const Color(0xffd9b98c),
            width: active ? 3 : 1.4,
          ),
          boxShadow: [
            if (active)
              const BoxShadow(
                color: Color(0x66ffc63c),
                blurRadius: 8,
                spreadRadius: 1,
              ),
          ],
        ),
        child: ClipOval(
          child: art == 'my_cat'
              ? CatSpecAvatar(catSpecForPlayer(p), size: 50)
              : catPortrait(art.substring(4), size: 50),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.player,
    builder: (context, _) {
      final p = widget.player;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Big round preview of the active avatar (photo or portrait).
          Center(
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xffffe9bd), Color(0xffd9a86a)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x443c241a),
                    offset: Offset(0, 4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ClipOval(
                child: SizedBox(
                  width: 104,
                  height: 104,
                  child: playerAvatarArt(p, size: 104),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Quick selector: preset portraits + own cat + a photo slot.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final art in avatarArtChoices) ...[
                _avatarChip(art),
                const SizedBox(width: 10),
              ],
              GestureDetector(
                onTap: () async {
                  final image = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 256,
                    maxHeight: 256,
                    imageQuality: 75,
                  );
                  if (image == null) return;
                  final bytes = await image.readAsBytes();
                  if (!mounted) return;
                  p.photo = base64Encode(bytes);
                  p.save();
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xfffff3d6),
                    border: Border.all(
                      color: p.photo != null ? gold : const Color(0xffd9b98c),
                      width: p.photo != null ? 3 : 1.4,
                    ),
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    size: 22,
                    color: Color(0xff8a6242),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: name,
            maxLength: 20,
            decoration: InputDecoration(
              labelText: 'Nume jucător',
              counterText: '',
              filled: true,
              fillColor: const Color(0xfffffbec),
              border: fieldBorder(const Color(0xffd9b98c)),
              enabledBorder: fieldBorder(const Color(0xffd9b98c)),
              focusedBorder: fieldBorder(const Color(0xffc98f3f), width: 1.6),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ArenaButton(
                  text: 'ANULEAZĂ',
                  secondary: true,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ArenaButton(
                  text: 'SALVEAZĂ',
                  green: true,
                  onPressed: () {
                    if (name.text.trim().isNotEmpty) {
                      p.name = name.text.trim();
                      p.save();
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

/// The honest offline tile shared by the settings and account dialogs when
/// no online backend is configured.
Widget _offlineOnline() => const ListTile(
  contentPadding: EdgeInsets.zero,
  leading: Icon(Icons.cloud_off, color: Color(0xffa97153), size: 26),
  title: Text(
    'Joc online',
    style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 15),
  ),
  subtitle: Text(
    'Indisponibil',
    style: TextStyle(
      color: Color(0xff8a6a52),
      fontWeight: FontWeight.w700,
      fontSize: 12,
    ),
  ),
);

/// Dedicated account dialog — opened from the top-bar CONT circle and the
/// CONT entry in the hamburger menu. Same online section as settings.
Future<void> showAccount(BuildContext context, Player p) => showAppDialog(
  context,
  p.english ? 'ACCOUNT' : 'CONT',
  AnimatedBuilder(
    animation: p,
    builder: (context, _) => OnlinePlay.services != null
        ? _OnlineSettings(player: p, services: OnlinePlay.services!)
        : _offlineOnline(),
  ),
);

Future<void> showSettings(BuildContext context, Player p) => showAppDialog(
  context,
  'Setări',
  AnimatedBuilder(
    animation: p,
    builder: (context, _) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SettingRow(
          image: 'icon_music',
          fallbackIcon: Icons.music_note,
          title: 'Muzică',
          value: p.music,
          onChanged: (v) {
            p.music = v;
            p.save();
          },
        ),
        _SettingRow(
          image: 'icon_sfx',
          fallbackIcon: Icons.volume_up,
          title: 'Efecte sonore',
          value: p.sfx,
          onChanged: (v) {
            p.sfx = v;
            p.save();
          },
        ),
        _SettingRow(
          image: 'icon_haptics',
          fallbackIcon: Icons.vibration,
          title: 'Vibrații',
          value: p.haptics,
          onChanged: (v) {
            p.haptics = v;
            p.save();
          },
        ),
        _SettingRow(
          image: null,
          fallbackIcon: Icons.notifications_none_rounded,
          title: 'Notificări',
          value: p.notifications,
          onChanged: (v) {
            p.notifications = v;
            p.save();
          },
        ),
        _SettingRow(
          image: 'icon_language',
          fallbackIcon: Icons.translate,
          title: 'English',
          value: p.english,
          onChanged: (v) {
            p.english = v;
            p.save();
          },
        ),
        const SizedBox(height: 4),
        if (OnlinePlay.services != null)
          _OnlineSettings(player: p, services: OnlinePlay.services!)
        else
          _offlineOnline(),
        const SizedBox(height: 6),
        const Text(
          'Preferințele sunt salvate local. Notificările sunt memento-uri zilnice pentru recompensa gratuită — poți opri oricând de aici sau din setările telefonului.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xff8a6a52),
            fontSize: 12,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  ),
);

class _OnlineSettings extends StatefulWidget {
  const _OnlineSettings({required this.player, required this.services});

  final Player player;
  final OnlinePlayServices services;

  @override
  State<_OnlineSettings> createState() => _OnlineSettingsState();
}

class _OnlineSettingsState extends State<_OnlineSettings> {
  final roomCode = TextEditingController();
  bool busy = false;
  String? notice;

  OnlinePlayServices get services => widget.services;
  Player get player => widget.player;

  @override
  void dispose() {
    roomCode.dispose();
    super.dispose();
  }

  Future<void> _linkGoogle() async {
    if (busy) return;
    final approval = await showParentGate(context, english: player.english);
    if (approval == null || !mounted) return;
    setState(() => busy = true);
    try {
      final credential = await services.googleCredential();
      if (credential == null) return;
      await services.account.start();
      await services.account.linkGoogle(credential, approval);
      if (!mounted) return;
      setState(() {});
      await showAppDialog(
        context,
        'Cont Google',
        const Text('Contul Google a fost conectat la acest dispozitiv.'),
      );
    } catch (error) {
      if (mounted) setState(() => notice = _onlineErrorMessage(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _restoreGoogle() async {
    if (busy) return;
    final approval = await showParentGate(context, english: player.english);
    if (approval == null || !mounted) return;
    setState(() => busy = true);
    try {
      final credential = await services.googleCredential();
      if (credential == null) return;
      final profile = await services.account.restoreWithGoogle(
        credential,
        approval,
      );
      if (!mounted) return;
      if (profile != null) await profile.applyTo(player);
      if (!mounted) return;
      setState(() {});
      await showAppDialog(
        context,
        'Cont Google',
        Text(
          profile == null
              ? 'Nu există profil cloud de restaurat.'
              : 'Profilul cloud a fost restaurat.',
        ),
      );
    } catch (error) {
      if (mounted) setState(() => notice = _onlineErrorMessage(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _deleteAccount() async {
    if (busy) return;
    if (await showParentGate(context, english: player.english) == null ||
        !mounted) {
      return;
    }
    final confirmed = await _showDeleteConfirmation(context);
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await services.account.start();
      try {
        await services.account.deleteAccount();
      } on OnlineException catch (error) {
        if (error.code != OnlineErrorCode.requiresRecentLogin) rethrow;
        final credential = await services.googleCredential();
        if (credential == null || !mounted) return;
        final approval = await showParentGate(context, english: player.english);
        if (approval == null || !mounted) return;
        await services.account.deleteAccount(freshGoogle: credential);
      }
      await _clearLocalData(player);
      if (!mounted) return;
      setState(() {});
      await showAppDialog(
        context,
        'Cont șters',
        const Text('Contul și datele locale au fost șterse.'),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => notice = _onlineErrorMessage(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _joinRoom() async {
    if (busy) return;
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      final user = await services.account.start();
      final joined = await services.rooms.joinRoom(
        roomCode.text,
        user.uid,
        power: player.power,
      );
      if (!mounted) return;
      roomCode.clear();
      await showAppDialog(
        context,
        'Join room',
        Text('Camera ${joined.code} a fost găsită.'),
      );
    } catch (error) {
      if (mounted) setState(() => notice = _onlineErrorMessage(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  OutlineInputBorder fieldBorder(Color color, {double width = 1.2}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final user = services.account.user;
    return panel(
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label('CONT ȘI CAMERĂ', size: 18, color: ink),
          const SizedBox(height: 8),
          Text(
            user == null
                ? 'Neconectat'
                : user.googleLinked
                ? 'Google conectat'
                : 'Anonim',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xff8a6a52),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          ArenaButton(
            text: 'Link Google account',
            secondary: true,
            onPressed: busy || user?.googleLinked == true ? null : _linkGoogle,
          ),
          ArenaButton(
            text: 'Restore with Google',
            secondary: true,
            onPressed: busy ? null : _restoreGoogle,
          ),
          ArenaButton(
            text: 'Delete account',
            danger: true,
            onPressed: busy ? null : _deleteAccount,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: roomCode,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Cod cameră',
              hintText: 'ABC-23K',
              filled: true,
              fillColor: const Color(0xfffffbec),
              border: fieldBorder(const Color(0xffd9b98c)),
              enabledBorder: fieldBorder(const Color(0xffd9b98c)),
              focusedBorder: fieldBorder(const Color(0xffc98f3f), width: 1.6),
            ),
          ),
          const SizedBox(height: 8),
          ArenaButton(
            text: 'Join room',
            green: true,
            onPressed: busy ? null : _joinRoom,
          ),
          if (notice != null) ...[
            const SizedBox(height: 8),
            Text(
              notice!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xff8a6242),
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<bool> _showDeleteConfirmation(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xfffff4d8),
      surfaceTintColor: Colors.transparent,
      elevation: 14,
      shadowColor: const Color(0x7751312d),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      title: const Text(
        'Șterge contul?',
        style: TextStyle(color: ink, fontSize: 20, fontWeight: FontWeight.w900),
      ),
      content: const Text(
        'Se vor șterge datele cloud și datele locale ale acestui dispozitiv. Această acțiune nu poate fi anulată.',
        style: TextStyle(
          color: Color(0xff6b4a35),
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('ANULEAZĂ'),
        ),
        ArenaButton(
          text: 'ȘTERGE CONTUL',
          danger: true,
          singleLine: true,
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
      ],
    ),
  );
  return confirmed == true;
}

Future<void> _clearLocalData(Player p) async {
  await p.prefs.clear();
  final fresh = Player(p.prefs);
  p
    ..name = fresh.name
    ..trophies = fresh.trophies
    ..coins = fresh.coins
    ..cat = fresh.cat
    ..accessory = fresh.accessory
    ..daily = fresh.daily
    ..owned = {...fresh.owned}
    ..claims = {...fresh.claims}
    ..fur = fresh.fur
    ..eyes = fresh.eyes
    ..ears = fresh.ears
    ..pattern = fresh.pattern
    ..power = fresh.power
    ..sfx = fresh.sfx
    ..music = fresh.music
    ..english = fresh.english
    ..notifications = fresh.notifications
    ..photo = fresh.photo
    ..avatarSpec = fresh.avatarSpec;
  await p.save();
}

String _onlineErrorMessage(Object error) {
  if (error is OnlineException) {
    return switch (error.code) {
      OnlineErrorCode.notSignedIn => 'Conectează-te din nou.',
      OnlineErrorCode.credentialInUse =>
        'Acest cont Google este deja conectat la alt jucător.',
      OnlineErrorCode.noLinkedAccount => 'Nu există un cont Google asociat.',
      OnlineErrorCode.invalidRoomCode => 'Codul camerei nu este valid.',
      OnlineErrorCode.roomNotFound =>
        'Camera nu a fost găsită sau nu mai este disponibilă.',
      OnlineErrorCode.roomExpired => 'Camera a expirat.',
      OnlineErrorCode.ownRoom => 'Nu te poți alătura propriei camere.',
      OnlineErrorCode.roomCodeExhausted =>
        'Nu s-a putut genera codul camerei. Încearcă din nou.',
      OnlineErrorCode.invalidCloudSave => 'Datele cloud nu sunt valide.',
      OnlineErrorCode.saveConflict =>
        'Datele s-au schimbat pe alt dispozitiv. Încearcă din nou.',
      OnlineErrorCode.requiresRecentLogin =>
        'Este nevoie de o nouă confirmare Google. Încearcă din nou.',
      OnlineErrorCode.googleUnavailable =>
        'Google nu este disponibilă în această versiune.',
      OnlineErrorCode.cancelled => 'Ai renunțat la conectarea Google.',
      OnlineErrorCode.notInMatch => 'Nu ești participant la acest meci.',
      OnlineErrorCode.backend =>
        'Serviciul online nu a răspuns. Încearcă din nou.',
    };
  }
  return 'Serviciul online nu a răspuns. Încearcă din nou.';
}

Future<void> showTrophyRoad(BuildContext context, Player p) => showAppDialog(
  context,
  'DRUMUL TROFEELOR',
  AnimatedBuilder(
    animation: p,
    builder: (context, _) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${p.trophies} trofee totale',
          style: const TextStyle(
            color: Color(0xff8a6a52),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        for (final room in houseRooms)
          panel(
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xfffff3cf), Color(0xfff0cf96)],
                        ),
                        border: Border.all(
                          color: const Color(0xffcaa06a),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x333c241a),
                            offset: Offset(0, 2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Center(
                        child: sprite(
                          room.threshold == 1500
                              ? 'icon_golden_fish'
                              : 'icon_chest',
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${room.threshold} trofee',
                            style: const TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            room.name,
                            style: const TextStyle(
                              color: Color(0xff8a6242),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ArenaButton(
                  text: p.claims.contains(room.threshold)
                      ? 'REVENDICAT'
                      : '+100 Lăbuțe',
                  green: true,
                  onPressed:
                      p.trophies >= room.threshold &&
                          !p.claims.contains(room.threshold)
                      ? () {
                          p.claims.add(room.threshold);
                          p.coins += 100;
                          p.save();
                        }
                      : null,
                ),
              ],
            ),
          ),
      ],
    ),
  ),
);

/// Settings row styled like the reference panels: a warm icon tile, the
/// label, then a glossy toggle pill on the right (green = on).
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.image,
    required this.fallbackIcon,
    required this.title,
    required this.value,
    required this.onChanged,
  });
  final String? image;
  final IconData fallbackIcon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: TactilePress(
      onTap: () => onChanged(!value),
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xfffffdf2), Color(0xfff3e4c4)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xffc9a06a), width: 1.4),
            boxShadow: const [
              BoxShadow(
                color: Color(0xffc9a06a),
                offset: Offset(0, 2.5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xff8a6242), Color(0xff6b4634)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: gold, width: 1.2),
                ),
                child: image == null
                    ? Icon(fallbackIcon, color: gold, size: 19)
                    : arenaImage(
                        image!,
                        fit: BoxFit.contain,
                        fallback: Icon(fallbackIcon, color: gold, size: 19),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _GlossySwitch(value: value, onChanged: onChanged),
            ],
          ),
      ),
    ),
  );
}

/// Glossy pill toggle: green gradient + white knob when on, beige + knob to
/// the left when off.
class _GlossySwitch extends StatelessWidget {
  const _GlossySwitch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onChanged(!value),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 54,
      height: 30,
      padding: const EdgeInsets.all(3),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: value
              ? const [Color(0xff9ede55), Color(0xff4e9c22)]
              : const [Color(0xfff0e2c6), Color(0xffc3a87e)],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: value ? const Color(0xff3f7d1c) : const Color(0xffa98d64),
          width: 1.6,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2a000000),
            offset: Offset(0, 2),
            blurRadius: 3,
          ),
        ],
      ),
      child: Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xffe8e2d4)],
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              offset: Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
    ),
  );
}
