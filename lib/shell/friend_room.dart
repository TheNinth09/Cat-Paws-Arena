import 'dart:async';

import 'package:flutter/material.dart';

import '../app_dialogs.dart';
import '../match_controller.dart';
import '../match_screen.dart';
import '../online/online_backend.dart';
import '../profile.dart';
import '../ui_widgets.dart';
import 'online_play.dart';

Future<void> showFriendRoom(
  BuildContext context, {
  required bool english,
  required Player player,
}) {
  final services = OnlinePlay.services;
  if (services == null) {
    return showUnavailable(context, english ? 'Online play' : 'Joc online');
  }
  return showAppDialog(
    context,
    english ? 'Friend room' : 'Cameră de prieten',
    FriendRoomPanel(
      english: english,
      services: services,
      player: player,
      onMatch: (duel) {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MatchScreen(player: player, mode: 0, online: duel),
          ),
        );
      },
    ),
  );
}

class FriendRoomPanel extends StatefulWidget {
  const FriendRoomPanel({
    super.key,
    required this.english,
    required this.services,
    required this.player,
    this.onMatch,
  });

  final bool english;
  final OnlinePlayServices services;
  final Player player;

  /// Called once the friend match session is open; the host shell closes
  /// the room dialog and pushes the duel screen.
  final void Function(OnlineDuel duel)? onMatch;

  @override
  State<FriendRoomPanel> createState() => _FriendRoomPanelState();
}

class _FriendRoomPanelState extends State<FriendRoomPanel> {
  final roomCode = TextEditingController();
  RoomRecord? createdRoom;
  bool busy = false, waitingForGuest = false, matchOpened = false;
  String? notice;

  OnlinePlayServices get services => widget.services;
  bool get english => widget.english;

  @override
  void dispose() {
    roomCode.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (busy) return;
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      final previous = createdRoom;
      if (previous != null) {
        try {
          await services.rooms.cancelRoom(previous);
        } catch (_) {}
        if (!mounted) return;
        createdRoom = null;
      }
      final user = await services.account.start();
      final room = await services.rooms.createRoom(user.uid);
      if (!mounted) return;
      setState(() {
        createdRoom = room;
        roomCode.clear();
        notice = english
            ? 'Share this code with a friend. House cats stay labelled BOT; this room is ONLINE.'
            : 'Trimite codul unui prieten. Pisicile casei rămân BOT; această cameră este ONLINE.';
      });
      unawaited(_waitForGuest());
    } catch (error) {
      if (mounted) {
        setState(() {
          notice = english
              ? 'The online service did not answer. Try again.'
              : 'Serviciul online nu a răspuns. Încearcă din nou.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _join() async {
    if (busy || roomCode.text.trim().isEmpty) return;
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      final user = await services.account.start();
      final joined = await services.rooms.joinRoom(roomCode.text, user.uid);
      if (!mounted) return;
      roomCode.clear();
      await _openDuel(
        MatchLink(
          matchId: joined.matchId,
          roomCode: joined.code,
          hostUid: joined.hostUid,
          guestUid: joined.guestUid,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          notice = english
              ? 'Room not found or expired. Check the code and try again.'
              : 'Camera nu a fost găsită sau a expirat. Verifică codul și încearcă din nou.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Host side: waits until the friend claims the room, then opens the
  /// shared match session and hands the duel to the shell.
  Future<void> _waitForGuest() async {
    final room = createdRoom;
    if (room == null) return;
    setState(() => waitingForGuest = true);
    try {
      final link = await services.rooms.waitForGuest(room);
      if (!mounted || matchOpened) return;
      await _openDuel(link);
    } on Object {
      if (mounted) {
        setState(() {
          notice = english
              ? 'The friend room connection failed. Create a new room and try again.'
              : 'Conexiunea camerei a eșuat. Creează o cameră nouă și încearcă din nou.';
        });
      }
    } finally {
      if (mounted) setState(() => waitingForGuest = false);
    }
  }

  /// Opens the lane-5 match session for [link] and starts the online duel.
  /// Without a configured backend the room flow stays honest: the player
  /// is told online duels are unavailable and keeps practising locally.
  Future<void> _openDuel(MatchLink link) async {
    if (matchOpened) return;
    final online = services.online;
    if (online == null) {
      setState(() {
        notice = english
            ? 'Room ${link.roomCode} found. Online duels are not available yet; keep practising locally.'
            : 'Camera ${link.roomCode} a fost găsită. Meciurile online nu sunt încă disponibile; continuă antrenamentul local.';
      });
      return;
    }
    setState(() => busy = true);
    try {
      final duel = await OnlineDuel.open(online, link);
      if (!mounted) return;
      matchOpened = true;
      widget.onMatch?.call(duel);
    } on Object {
      if (mounted) {
        setState(() {
          notice = english
              ? 'The online match could not be opened. Try again.'
              : 'Meciul online nu a putut fi deschis. Încearcă din nou.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _cancel() async {
    final room = createdRoom;
    if (room == null || busy) return;
    setState(() {
      busy = true;
      waitingForGuest = false;
    });
    try {
      await services.rooms.cancelRoom(room);
      if (!mounted) return;
      setState(() {
        createdRoom = null;
        notice = english ? 'Room cancelled.' : 'Camera a fost anulată.';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          notice = english
              ? 'The room could not be cancelled.'
              : 'Camera nu a putut fi anulată.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        english
            ? 'Create a six-character room code for a friend, or join with their code. House cats are always labelled BOT; this room is ONLINE.'
            : 'Creează un cod de șase caractere pentru un prieten sau alătură-te cu codul lui. Pisicile casei sunt mereu BOT; această cameră este ONLINE.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: Color(0xff8a6242)),
      ),
      const SizedBox(height: 12),
      ArenaButton(
        text: english ? 'CREATE ROOM' : 'CREEAZĂ CAMERĂ',
        green: true,
        onPressed: busy || waitingForGuest ? null : _create,
      ),
      if (createdRoom != null) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xfffffbec),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: gold, width: 1.5),
          ),
          child: Text(
            createdRoom!.code,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ink,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
        ),
        if (waitingForGuest) ...[
          const SizedBox(height: 8),
          Text(
            english
                ? 'Waiting for your friend to join…'
                : 'Așteptăm prietenul să intre…',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xff8a6242),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 8),
        ArenaButton(
          text: english ? 'CANCEL ROOM' : 'ANULEAZĂ CAMERA',
          danger: true,
          onPressed: busy ? null : _cancel,
        ),
      ],
      const SizedBox(height: 12),
      TextField(
        controller: roomCode,
        onChanged: (_) => setState(() {}),
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          labelText: english ? 'Room code' : 'Cod cameră',
          hintText: 'ABC-23K',
          filled: true,
          fillColor: const Color(0xfffffbec),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      const SizedBox(height: 8),
      ArenaButton(
        text: english ? 'JOIN ROOM' : 'ALĂTURĂ-TE',
        secondary: true,
        onPressed: busy || roomCode.text.trim().isEmpty ? null : _join,
      ),
      if (notice != null) ...[
        const SizedBox(height: 10),
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
  );
}
