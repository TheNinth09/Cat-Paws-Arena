import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'app_dialogs.dart';
import 'cat_avatar.dart';
import 'catalog.dart';
import 'local_play.dart';
import 'profile.dart';
import 'ui_widgets.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({
    super.key,
    required this.player,
    required this.onUnavailable,
  });
  final Player player;
  final ValueChanged<String> onUnavailable;
  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  static const chatKey = 'team_chat';

  final search = TextEditingController();
  final message = TextEditingController();
  final random = Random();

  LocalTeam? team;
  List<ChatMessage> chat = <ChatMessage>[];
  String? offer;
  String? wanted;
  String? tradeStatus;
  bool tradePending = false;
  Timer? replyTimer;
  Timer? tradeTimer;
  bool preview = false;

  bool get unlocked => widget.player.trophies >= 200 || preview;

  @override
  void initState() {
    super.initState();
    team = readLocalTeam(widget.player.prefs);
    chat = readChat(widget.player.prefs, chatKey);
  }

  @override
  void dispose() {
    replyTimer?.cancel();
    tradeTimer?.cancel();
    search.dispose();
    message.dispose();
    super.dispose();
  }

  void persistTeam() => unawaited(writeLocalTeam(widget.player.prefs, team));
  void persistChat() =>
      unawaited(writeChat(widget.player.prefs, chatKey, chat));

  void changeTeam(LocalTeam? value) {
    replyTimer?.cancel();
    tradeTimer?.cancel();
    setState(() {
      team = value;
      chat = <ChatMessage>[];
      offer = null;
      wanted = null;
      tradeStatus = null;
      tradePending = false;
    });
    persistTeam();
    persistChat();
  }

  void createTeam() {
    final controller = TextEditingController(
      text: 'Echipa ${widget.player.name}',
    );
    showAppDialog(
      context,
      'Creează echipă locală',
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Echipa este o simulație locală: membrii sunt boți și datele rămân pe acest dispozitiv.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLength: 24,
            decoration: const InputDecoration(labelText: 'Nume echipă'),
          ),
          ArenaButton(
            text: 'CREEAZĂ ECHIPA',
            green: true,
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              changeTeam(LocalTeam(name: name, members: pickSimulatedNames(4)));
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void joinTeam(String name, List<String> members) =>
      changeTeam(LocalTeam(name: name, members: List<String>.of(members)));

  void sendMessage() {
    final text = message.text.trim();
    if (text.isEmpty || team == null) return;
    setState(() {
      chat.add(ChatMessage('Tu', text, mine: true));
    });
    message.clear();
    persistChat();
    replyTimer?.cancel();
    replyTimer = Timer(Duration(milliseconds: 900 + random.nextInt(900)), () {
      if (!mounted) return;
      final active = team;
      if (active == null || active.members.isEmpty) return;
      final who = active.members[random.nextInt(active.members.length)];
      setState(() {
        chat.add(
          ChatMessage(
            who,
            cannedChatReplies[random.nextInt(cannedChatReplies.length)],
          ),
        );
      });
      persistChat();
    });
  }

  List<String> get offerable => [
    for (final item in [...accessories, ...powers])
      if (widget.player.owned.contains(item)) item,
  ];

  List<String> get requestable => [
    for (final item in [...accessories, ...powers])
      if (item != offer && !widget.player.owned.contains(item)) item,
  ];

  String? get validOffer =>
      offer != null && offerable.contains(offer) ? offer : null;
  String? get validWanted =>
      wanted != null && requestable.contains(wanted) ? wanted : null;

  bool get canTrade =>
      unlocked &&
      !tradePending &&
      offer != null &&
      wanted != null &&
      offerable.contains(offer) &&
      requestable.contains(wanted);

  void sendTrade() {
    final offered = offer;
    final requested = wanted;
    if (offered == null || requested == null || tradePending) return;
    final offerItem = offered;
    final requestItem = requested;
    setState(() {
      tradePending = true;
      tradeStatus = 'Se așteaptă răspunsul coechipierului… (simulare)';
    });
    tradeTimer?.cancel();
    tradeTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) resolveTrade(offerItem, requestItem);
    });
  }

  void resolveTrade(String offered, String requested) {
    final p = widget.player;
    String status;
    if (!p.owned.contains(offered)) {
      status = 'Oferta selectată nu mai este în inventarul tău.';
    } else if (p.owned.contains(requested)) {
      status =
          'Cererea a expirat: ${itemName(requested)} este deja în inventar.';
    } else {
      p.owned.remove(offered);
      p.owned.add(requested);
      p.save();
      status = 'Schimb acceptat (simulat)! Ai primit ${itemName(requested)}.';
      offer = null;
      wanted = null;
    }
    setState(() {
      tradePending = false;
      tradeStatus = status;
    });
  }

  @override
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey('team-scroll'),
    padding: const EdgeInsets.all(12),
    children: [
      panel(
        Row(
          children: [
            const Icon(Icons.shield, color: Color(0xffc18a35), size: 48),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ECHIPA TA',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    !unlocked
                        ? 'Se deblochează la 200 trofee'
                        : team == null
                        ? 'Nicio echipă locală'
                        : '${team!.name} • simulat',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (!unlocked)
        unlockGateCard(
          title: 'ECHIPA',
          art: 'icon_chest',
          needed: 200,
          current: widget.player.trophies,
          reward: 'echipă locală, chat și schimburi simulate',
        ),
      if (!unlocked)
        panel(
          ArenaButton(
            text: 'PREVIZUALIZEAZĂ LOCAL',
            green: true,
            onPressed: () => setState(() => preview = true),
          ),
        ),
      if (unlocked) ...[teamPanel(), chatPanel(), tradePanel()],
    ],
  );

  Widget teamPanel() {
    final current = team;
    if (current == null) {
      final query = search.text.trim().toLowerCase();
      final results = [
        for (final seed in joinableTeamSeeds)
          if (query.isEmpty || seed.$1.toLowerCase().contains(query)) seed,
      ];
      return Column(
        children: [
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Echipă locală (simulare)',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Creează o echipă sau alătură-te uneia simulate. Membrii sunt boți; datele rămân pe acest dispozitiv.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Caută o echipă',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                ArenaButton(
                  text: 'CREEAZĂ ECHIPĂ',
                  green: true,
                  onPressed: createTeam,
                ),
              ],
            ),
          ),
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'ECHIPE SIMULATE',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                if (results.isEmpty)
                  const Text(
                    'Nicio echipă nu corespunde căutării.',
                    textAlign: TextAlign.center,
                  )
                else
                  for (final seed in results)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.groups, color: Color(0xffcb8b28)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  seed.$1,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  '${seed.$2.length + 1} membri • boți simulați',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 96,
                            child: ArenaButton(
                              text: 'ALĂTURĂ-TE',
                              green: true,
                              singleLine: true,
                              onPressed: () => joinTeam(seed.$1, seed.$2),
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ],
      );
    }
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Echipă locală • ${current.members.length + 1} membri • SIMULAT',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              ArenaButton(text: 'PLEACĂ', onPressed: () => changeTeam(null)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              memberChip(widget.player.name, you: true, cat: widget.player),
              for (var i = 0; i < current.members.length; i++)
                memberChip(
                  current.members[i],
                  you: false,
                  cat: simulatedCat(widget.player.prefs, current.members[i], i),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget memberChip(String name, {required bool you, required Player cat}) =>
      SizedBox(
        width: 78,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: you ? gold : ink, width: 2.5),
              ),
              child: ClipOval(child: CatAvatar(cat, size: 54)),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
            Text(
              you ? 'TU' : 'BOT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: you ? const Color(0xff9a6a00) : const Color(0xff8a5a2b),
              ),
            ),
          ],
        ),
      );

  Widget chatPanel() => panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.chat_bubble, color: Color(0xffcb8b28), size: 26),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'CHAT LOCAL SIMULAT',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const Divider(color: ink),
        const Text(
          'Doar pe acest dispozitiv • răspunsurile colegilor sunt automate.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (team == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Alătură-te sau creează o echipă pentru a activa chatul local.',
              textAlign: TextAlign.center,
            ),
          )
        else ...[
          SizedBox(
            height: 190,
            child: chat.isEmpty
                ? const Center(
                    child: Text(
                      'Niciun mesaj încă. Spune „salut" echipei!',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: chat.length,
                    itemBuilder: (context, index) => chatBubble(chat[index]),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: message,
                  maxLength: 200,
                  maxLines: 2,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => sendMessage(),
                  decoration: const InputDecoration(
                    labelText: 'Scrie un mesaj...',
                    border: OutlineInputBorder(),
                    isDense: true,
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SendButton(onPressed: sendMessage),
            ],
          ),
        ],
      ],
    ),
  );

  Widget chatBubble(ChatMessage item) => Align(
    alignment: item.mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: item.mine ? gold : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(item.mine ? 14 : 4),
          bottomRight: Radius.circular(item.mine ? 4 : 14),
        ),
        border: Border.all(color: ink, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.who,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: item.mine
                  ? const Color(0xff7a5200)
                  : const Color(0xff8a5a2b),
            ),
          ),
          Text(item.text, style: const TextStyle(fontSize: 14, color: ink)),
        ],
      ),
    ),
  );

  Widget tradePanel() => panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'SCHIMB ÎNTRE COECHIPIERI',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        const Divider(color: ink),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xffffdfa1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ink, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Simulare locală • nu este schimb online',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(
                'Cere un accesoriu sau o putere unui coechipier simulat. Inventarul se actualizează doar local.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _tradeSlot(validOffer),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.swap_horiz, color: ink, size: 36),
                  ),
                  _tradeSlot(validWanted),
                ],
              ),
              const SizedBox(height: 10),
              if (offerable.isEmpty)
                const Text(
                  'Nu deții încă accesorii sau puteri — vizitează magazinul pentru a oferi ceva.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                )
              else ...[
                DropdownButtonFormField<String>(
                  initialValue: validOffer,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'OFERĂ'),
                  items: [
                    for (final item in offerable)
                      DropdownMenuItem(
                        value: item,
                        child: Text(
                          itemName(item),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: tradePending
                      ? null
                      : (value) => setState(() => offer = value),
                ),
                if (requestable.isEmpty)
                  const Text(
                    'Deții tot catalogul — nu mai ai ce cere.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: validWanted,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'CERE'),
                    items: [
                      for (final item in requestable)
                        DropdownMenuItem(
                          value: item,
                          child: Text(
                            itemName(item),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: tradePending
                        ? null
                        : (value) => setState(() => wanted = value),
                  ),
              ],
              if (tradeStatus != null) ...[
                const SizedBox(height: 8),
                Text(
                  tradeStatus!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              ArenaButton(
                text: tradePending
                    ? 'SE AȘTEAPTĂ RĂSPUNSUL…'
                    : 'TRIMITE CERERE',
                green: true,
                onPressed: canTrade ? sendTrade : null,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _tradeSlot(String? item) => SizedBox(
    width: 84,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        item == null
            ? Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ink.withValues(alpha: 0.5)),
                ),
                child: Icon(
                  Icons.help_outline,
                  color: ink.withValues(alpha: 0.6),
                  size: 30,
                ),
              )
            : sprite(item, size: 56),
        const SizedBox(height: 4),
        Text(
          item == null ? '—' : itemName(item),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Material(
    color: gold,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Icon(Icons.send_rounded, color: ink, size: 22),
      ),
    ),
  );
}
