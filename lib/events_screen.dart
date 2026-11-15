import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_dialogs.dart';
import 'catalog.dart';
import 'local_play.dart';
import 'profile.dart';
import 'ui_widgets.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({
    super.key,
    required this.player,
    required this.onUnavailable,
    this.onBattle,
  });
  final Player player;
  final ValueChanged<String> onUnavailable;

  /// Optional callback that starts a real match screen. When omitted, the
  /// "Joacă meci" action explains that matches start from the Battle tab.
  final void Function(int mode)? onBattle;
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final code = TextEditingController();
  final codeFocus = FocusNode();
  int selected = 0;
  late bool weekendJoinedState;
  List<LocalTournament> tournaments = <LocalTournament>[];
  String? joinFeedback;
  bool preview = false;

  bool get unlocked => widget.player.trophies >= 250 || preview;

  @override
  void initState() {
    super.initState();
    weekendJoinedState = weekendJoined(widget.player.prefs);
    tournaments = readTournaments(widget.player.prefs);
  }

  @override
  void dispose() {
    code.dispose();
    codeFocus.dispose();
    super.dispose();
  }

  void persistTournaments() =>
      unawaited(writeTournaments(widget.player.prefs, tournaments));

  void toggleWeekend() {
    final value = !weekendJoinedState;
    setState(() => weekendJoinedState = value);
    unawaited(setWeekendJoined(widget.player.prefs, value));
  }

  void createTournament() {
    final nameController = TextEditingController(
      text: 'Turneul ${widget.player.name}',
    );
    var mode = widget.player.tier.clamp(0, modeNames.length - 1).toInt();
    var maxPlayers = 4;
    showAppDialog(
      context,
      'Creează turneu local',
      StatefulBuilder(
        builder: (dialogContext, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Simulare locală • turneul există doar pe acest dispozitiv și generează un cod de alăturare local.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              maxLength: 28,
              decoration: const InputDecoration(labelText: 'Nume turneu'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mod de joc',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            for (var i = 0; i < modeNames.length; i++)
              ArenaButton(
                text:
                    '${modeNames[i]}${i > widget.player.tier ? ' • ${modeThresholds[i]} trofee' : ''}',
                green: mode == i,
                onPressed: i <= widget.player.tier
                    ? () => setDialogState(() => mode = i)
                    : null,
              ),
            const SizedBox(height: 6),
            const Text(
              'Jucători maxim',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            Row(
              children: [
                for (final size in [4, 8])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: ArenaButton(
                        text: '$size locuri',
                        green: maxPlayers == size,
                        onPressed: () =>
                            setDialogState(() => maxPlayers = size),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            ArenaButton(
              text: 'CREEAZĂ TURNEU',
              green: true,
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final tournament = LocalTournament(
                  name: name,
                  mode: mode,
                  maxPlayers: maxPlayers,
                  code: newTournamentCode(tournaments.map((t) => t.code)),
                  owner: widget.player.name,
                  players: [
                    widget.player.name,
                    ...pickSimulatedNames(maxPlayers == 4 ? 1 : 2),
                  ],
                  status: 0,
                  created: DateTime.now().toIso8601String(),
                );
                setState(() {
                  tournaments.add(tournament);
                  joinFeedback =
                      'Turneul „$name" a fost creat • cod ${tournament.code} (doar local).';
                });
                persistTournaments();
                Navigator.pop(dialogContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  bool tryJoin(LocalTournament tournament) {
    if (tournament.has(widget.player.name) || tournament.full) return false;
    setState(() {
      tournament.players.add(widget.player.name);
      if (tournament.full) tournament.status = 1;
      joinFeedback =
          'Te-ai alăturat la „${tournament.name}" (simulare locală).';
    });
    persistTournaments();
    return true;
  }

  void joinByCode() {
    final value = code.text.trim().toUpperCase();
    if (value.isEmpty) return;
    LocalTournament? found;
    for (final tournament in tournaments) {
      if (tournament.code == value) {
        found = tournament;
        break;
      }
    }
    if (found == null) {
      setState(
        () => joinFeedback =
            'Cod negăsit printre turneele locale de pe acest dispozitiv.',
      );
      return;
    }
    final tournament = found;
    if (tournament.has(widget.player.name)) {
      setState(() => joinFeedback = 'Ești deja în „${tournament.name}".');
      return;
    }
    if (tournament.full) {
      setState(
        () => joinFeedback =
            '„${tournament.name}" este complet (${tournament.maxPlayers} locuri).',
      );
      return;
    }
    if (tryJoin(tournament)) code.clear();
  }

  void leaveTournament(LocalTournament tournament) {
    setState(() {
      tournament.players.remove(widget.player.name);
      if (tournament.owner == widget.player.name) {
        tournament.owner = tournament.players.isEmpty
            ? ''
            : tournament.players.first;
      }
      if (!tournament.full) tournament.status = 0;
      if (tournament.players.isEmpty) {
        tournaments.remove(tournament);
      }
      joinFeedback = 'Ai părăsit „${tournament.name}" (simulare locală).';
    });
    persistTournaments();
  }

  void simulateSignups(LocalTournament tournament) {
    final free = tournament.freeSlots;
    if (free <= 0) return;
    final existing = tournament.players.toSet();
    final bots = pickSimulatedNames(4)
        .where((name) => !existing.contains(name))
        .take(free < 2 ? free : 2)
        .toList();
    if (bots.isEmpty) return;
    setState(() {
      tournament.players.addAll(bots);
      if (tournament.full) tournament.status = 1;
      joinFeedback =
          '${bots.length} jucător(i) simulați s-au înscris la „${tournament.name}".';
    });
    persistTournaments();
  }

  void copyCode(LocalTournament tournament) {
    unawaited(Clipboard.setData(ClipboardData(text: tournament.code)));
    setState(
      () => joinFeedback =
          'Codul ${tournament.code} a fost copiat (valabil doar local).',
    );
  }

  void playMatch(LocalTournament tournament) {
    final battle = widget.onBattle;
    if (battle == null) {
      setState(
        () => joinFeedback = 'Pornește meciul din ecranul LUPTĂ — evenimentele nu pornesc meciuri direct.',
      );
      return;
    }
    battle(tournament.mode);
  }

  @override
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey('events-scroll'),
    padding: const EdgeInsets.all(12),
    children: [
      panel(
        Row(
          children: [
            for (var i = 0; i < 2; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ArenaButton(
                    text: ['GLOBAL', 'PRIVATE'][i],
                    green: selected == i,
                    onPressed: () => setState(() => selected = i),
                  ),
                ),
              ),
          ],
        ),
        padding: const EdgeInsets.all(6),
      ),
      if (!unlocked)
        unlockGateCard(
          title: 'EVENIMENTE',
          art: 'icon_golden_fish',
          needed: 250,
          current: widget.player.trophies,
          reward: 'challenge global de weekend și turnee private simulate',
        ),
      if (!unlocked)
        panel(
          ArenaButton(
            text: 'PREVIZUALIZEAZĂ LOCAL',
            green: true,
            onPressed: () => setState(() => preview = true),
          ),
        ),
      if (unlocked && selected == 0) globalPanel(),
      if (unlocked && selected == 1) ...privatePanels(),
    ],
  );

  Widget globalPanel() {
    final standings = weekendStandings(widget.player, weekendJoinedState);
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: label('GLOBAL WEEKEND\nCHALLENGE', size: 24, color: ink),
              ),
              sprite('icon_golden_fish', size: 60),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xffab4a42),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'SIMULARE LOCALĂ • nu este un turneu online real',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cream,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Provocare de weekend: adună cel mai mare scor în meciurile de antrenament. Participanții și scorurile sunt generate local.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < standings.length; i++)
            standingRow(i + 1, standings[i]),
          const SizedBox(height: 10),
          ArenaButton(
            text: weekendJoinedState
                ? 'PĂRĂSEȘTE CHALLENGE-UL'
                : 'INTRĂ ÎN CHALLENGE',
            green: !weekendJoinedState,
            onPressed: toggleWeekend,
          ),
        ],
      ),
    );
  }

  Widget standingRow(int rank, ({String name, int score, bool you}) entry) =>
      Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: entry.you
              ? gold.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: entry.you ? gold : ink.withValues(alpha: 0.35),
            width: entry.you ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Expanded(
              child: Text(
                entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            sprite('icon_paw_coin', size: 18),
            const SizedBox(width: 3),
            Text(
              '${entry.score}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
            if (entry.you) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: ink,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'TU',
                  style: TextStyle(
                    color: cream,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      );

  List<Widget> privatePanels() => [
    const SectionHeading('EVENIMENTE PRIVATE'),
    const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        'Toate turneele sunt simulate local • nu există turnee online.',
        textAlign: TextAlign.center,
        style: TextStyle(color: cream, fontSize: 12),
      ),
    ),
    AdaptiveCardGrid(
      minWidth: 140,
      maxColumns: 2,
      children: [
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              label('CREEAZĂ TURNEU', size: 18, color: ink),
              const SizedBox(height: 12),
              const Icon(Icons.groups, color: Color(0xffcb8b28), size: 70),
              ArenaButton(
                text: 'CREEAZĂ',
                green: true,
                onPressed: createTournament,
              ),
            ],
          ),
        ),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              label('INTRĂ CU COD', size: 18, color: ink),
              const SizedBox(height: 12),
              sprite('icon_trophy', size: 70),
              ArenaButton(
                text: 'INTRODU CODUL',
                onPressed: () => codeFocus.requestFocus(),
              ),
            ],
          ),
        ),
      ],
    ),
    panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'COD DE ALĂTURARE',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: code,
                  focusNode: codeFocus,
                  maxLength: 8,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Cod turneu',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ArenaButton(
                text: 'ALĂTURĂ-TE',
                green: true,
                onPressed: joinByCode,
              ),
            ],
          ),
          if (joinFeedback != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                joinFeedback!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    ),
    if (tournaments.isEmpty)
      panel(
        const Text(
          'Niciun turneu local încă. Creează unul mai sus sau introdu un cod.',
          textAlign: TextAlign.center,
        ),
      )
    else
      for (final tournament in tournaments) tournamentCard(tournament),
  ];

  Widget tournamentCard(LocalTournament tournament) {
    final mine = tournament.has(widget.player.name);
    final rounds = tournamentBracket(tournament);
    final maxMatches = rounds.isEmpty ? 0 : rounds.first.length;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final bracketHeight =
        maxMatches * (30 * textScale + 18) + 18 * textScale + 22;
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.groups, color: Color(0xffcb8b28), size: 30),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tournament.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${modeNames[tournament.mode]} • ${tournament.players.length}/${tournament.maxPlayers} jucători',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => copyCode(tournament),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: gold,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ink, width: 1.5),
                  ),
                  child: Text(
                    tournament.code,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final name in tournament.players)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: name == widget.player.name
                        ? gold.withValues(alpha: 0.45)
                        : Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: name == widget.player.name
                          ? gold
                          : ink.withValues(alpha: 0.4),
                      width: name == widget.player.name ? 1.5 : 1,
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      name == widget.player.name ? 'TU • $name' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (tournament.players.length >= 2)
            bracketView(rounds, bracketHeight)
          else
            const Text(
              'Bracketul se va genera când se vor alătura cel puțin 2 jucători.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          const SizedBox(height: 8),
          if (mine) ...[
            ArenaButton(
              text: 'JOACĂ MECI',
              green: true,
              spriteName: 'btn_play_paw',
              onPressed: () => playMatch(tournament),
            ),
            const Text(
              'Deschide un meci de antrenament cu modul turneului (întotdeauna contra unui bot).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11),
            ),
            ArenaButton(
              text: 'PĂRĂSEȘTE TURNEUL',
              onPressed: () => leaveTournament(tournament),
            ),
          ] else if (!tournament.full) ...[
            ArenaButton(
              text: 'INTRĂ ÎN TURNEU',
              green: true,
              onPressed: () => tryJoin(tournament),
            ),
            ArenaButton(
              text: 'ADAUGĂ 2 JUCĂTORI SIMULAȚI',
              onPressed: () => simulateSignups(tournament),
            ),
          ] else
            const Text(
              'Turneu complet (simulat).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget bracketView(List<List<BracketMatch>> rounds, double height) {
    if (rounds.isEmpty) return const SizedBox.shrink();
    const labels = ['SFERTURI', 'SEMIFINALE', 'FINALĂ'];
    final firstLabel = labels.length - rounds.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'BRACKET SIMULAT',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Color(0xff8a5a2b),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: height,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var r = 0; r < rounds.length; r++) ...[
                  if (r > 0) const SizedBox(width: 14),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text(
                        labels[firstLabel + r],
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      for (final match in rounds[r]) matchBox(match),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const Text(
          'Rezultatele sunt simulate • nu sunt meciuri reale.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  Widget matchBox(BracketMatch match) => Container(
    width: 104,
    margin: const EdgeInsets.symmetric(vertical: 3),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: ink.withValues(alpha: 0.5), width: 1.2),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        matchName(match.first, match.winner == match.first),
        const SizedBox(height: 2),
        matchName(match.second, match.winner == match.second),
      ],
    ),
  );

  Widget matchName(String name, bool winner) => Text(
    name,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: 11,
      fontWeight: winner ? FontWeight.w900 : FontWeight.w500,
      color: name == '—'
          ? Colors.black38
          : winner
          ? ink
          : const Color(0xff6d4c41),
    ),
  );
}
