import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'arena.dart';
import 'board_game.dart';
import 'profile.dart';

enum MatchPhase { searching, playing, finished }

class ArenaMatchController extends ChangeNotifier {
  ArenaMatchController(this.player, this.mode) {
    remaining = mode == 1 ? 45 : 90;
    botTrophies = max(0, player.trophies + Random().nextInt(151) - 75);
    game = BoardGame(
      board,
      refresh,
      bot.obstacle,
      [
        'obs_cardboard_box',
        'obs_slipper',
        'obs_tangled_yarn',
        'obs_tangled_yarn',
      ][player.tier],
    );
    _search = Timer(const Duration(seconds: 3), () {
      phase = MatchPhase.playing;
      refresh();
      _clock = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    });
  }
  final Player player;
  final int mode;
  final board = MatchBoard(), bot = MatchBoard();
  late final BoardGame game;
  late int remaining, botTrophies;
  MatchPhase phase = MatchPhase.searching;
  int? result;
  bool _disposed = false, _background = false, _modal = false;
  Timer? _search, _clock;
  bool get paused => _background || _modal;
  int get botScore => bot.score;
  void refresh() {
    if (!_disposed) notifyListeners();
  }

  void pause({bool? background, bool? modal}) {
    if (background != null) _background = background;
    if (modal != null) _modal = modal;
    game.suspended = paused;
  }

  void tick() {
    if (_disposed || paused || phase != MatchPhase.playing) return;
    remaining--;
    if (remaining % 3 == 0) {
      final old = bot.attacks;
      bot.autoMove();
      if (bot.attacks > old && !game.busy) board.obstacle();
    }
    if (mode == 2 && remaining % 8 == 0 && !game.busy) board.obstacle();
    if (remaining <= 0) {
      finish(board.score.compareTo(botScore));
    } else {
      refresh();
    }
  }

  void finish(int outcome) {
    if (_disposed || phase == MatchPhase.finished) return;
    _search?.cancel();
    _clock?.cancel();
    game.active = false;
    result = outcome;
    phase = MatchPhase.finished;
    player.result(outcome);
    refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    _search?.cancel();
    _clock?.cancel();
    game.active = false;
    super.dispose();
  }
}
