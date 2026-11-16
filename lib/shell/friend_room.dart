import 'package:flutter/material.dart';

import '../app_dialogs.dart';
import '../online/online_backend.dart';
import '../ui_widgets.dart';
import 'online_play.dart';

Future<void> showFriendRoom(BuildContext context, {required bool english}) {
  final services = OnlinePlay.services;
  if (services == null) {
    return showUnavailable(context, english ? 'Online play' : 'Joc online');
  }
  return showAppDialog(
    context,
    english ? 'Friend room' : 'Cameră de prieten',
    FriendRoomPanel(english: english, services: services),
  );
}

class FriendRoomPanel extends StatefulWidget {
  const FriendRoomPanel({
    super.key,
    required this.english,
    required this.services,
  });

  final bool english;
  final OnlinePlayServices services;

  @override
  State<FriendRoomPanel> createState() => _FriendRoomPanelState();
}

class _FriendRoomPanelState extends State<FriendRoomPanel> {
  final roomCode = TextEditingController();
  RoomRecord? createdRoom;
  bool busy = false;
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
        await services.rooms.cancelRoom(previous);
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
      setState(() {
        notice = english
            ? 'Room ${joined.code} found. Online duels are not available yet; keep practising locally.'
            : 'Camera ${joined.code} a fost găsită. Meciurile online nu sunt încă disponibile; continuă antrenamentul local.';
      });
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

  Future<void> _cancel() async {
    final room = createdRoom;
    if (room == null || busy) return;
    setState(() => busy = true);
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
        onPressed: busy ? null : _create,
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
