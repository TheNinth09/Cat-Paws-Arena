import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'duel_events.dart';

/// Output sink for synthesized cues. Abstracted so tests can record plays
/// without a platform audio stack.
abstract class SfxOutput {
  /// [asset] is the path under `assets/` (e.g. `generated/audio/sfx_pop.wav`).
  void play(String asset, {required double volume, required double rate});
  Future<void> dispose();
}

/// Haptic intensities mapped to `HapticFeedback` calls.
enum HapticKind { selection, light, medium, heavy }

/// Feedback layer for contract events: one synthesized sound and one haptic
/// per event type, plus cascade pitch on the clear sound. It contains no
/// game rules — it only maps event types to cues and respects the player's
/// sound setting through [enabled].
class DuelAudio {
  DuelAudio({
    bool Function()? enabled,
    bool Function()? hapticsEnabled,
    SfxOutput? output,
    void Function(HapticKind kind)? haptics,
  }) : _enabled = enabled ?? (() => true),
       _hapticsEnabled = hapticsEnabled ?? (() => true),
       _out = output ?? _AudioPlayersOutput(),
       _haptics = haptics ?? _platformHaptics;

  final bool Function() _enabled;
  final bool Function() _hapticsEnabled;
  final SfxOutput _out;
  final void Function(HapticKind kind) _haptics;

  /// Consecutive clear-family steps in the current resolution chain; the
  /// pop/special pitch rises with each step.
  int _cascade = 0;

  /// Specials fired inside the current move: the second and beyond mean
  /// a special+special combination, which earns the heavy haptic.
  int _specialsThisMove = 0;

  void play(BoardEvent event) {
    if (!_enabled()) return;
    final rate = _rateFor(event);
    final cue = _cueFor(event);
    _out.play(cue.asset, volume: cue.volume, rate: rate);
    final h = cue.haptic;
    if (h != null && _hapticsEnabled()) _haptics(h);
  }

  /// Last-seconds warning — a discrete tick per second while the turn
  /// clock burns its final stretch (4s), not as urgent as a timer bomb.
  void countdownTick() {
    if (!_enabled()) return;
    _out.play(
      'audio/sfx_timer_tick.wav',
      volume: 0.75,
      rate: 1.1,
    );
    if (_hapticsEnabled()) _haptics(HapticKind.selection);
  }

  double _rateFor(BoardEvent e) {
    final clearStep = e is Cleared || e is SpecialFired;
    final moveStart =
        e is Swapped ||
        e is SwapRejected ||
        e is PowerFired ||
        e is Shuffled ||
        e is TurnEnded ||
        e is MatchEnded ||
        e is ObstacleQueued ||
        e is BoardReset;
    if (moveStart) {
      _cascade = 0;
      _specialsThisMove = 0;
    }
    if (e is SpecialFired) _specialsThisMove++;
    if (!clearStep) return 1;
    _cascade = _cascade >= 8 ? 8 : _cascade + 1;
    return 1 + 0.12 * _cascade;
  }

  ({String asset, double volume, HapticKind? haptic}) _cueFor(BoardEvent e) =>
      switch (e) {
        Swapped() => (
          asset: 'audio/sfx_swap.wav',
          volume: 0.5,
          haptic: HapticKind.selection,
        ),
        SwapRejected() => (
          asset: 'audio/sfx_invalid.wav',
          volume: 0.55,
          haptic: HapticKind.medium,
        ),
        Cleared() => (
          asset: _cascade <= 1
              ? 'audio/sfx_match.wav'
              : _cascade == 2
              ? 'audio/sfx_combo_2.wav'
              : 'audio/sfx_combo_3.wav',
          volume: 0.6,
          haptic: HapticKind.light,
        ),
        SpecialCreated() => (
          asset: 'audio/sfx_special_create.wav',
          volume: 0.55,
          haptic: HapticKind.medium,
        ),
        SpecialFired(:final kind) => (
          asset: switch (kind) {
            SpecialKind.lineHorizontal || SpecialKind.lineVertical =>
              'audio/sfx_rocket.wav',
            SpecialKind.bomb => 'audio/sfx_bomb.wav',
            SpecialKind.copter => 'audio/sfx_copter.wav',
            SpecialKind.rainbow => 'audio/sfx_rainbow.wav',
            SpecialKind.none => 'audio/sfx_match.wav',
          },
          volume: 0.65,
          // Second+ special inside one move = a special+special
          // combination — the heavy haptic marks the big one.
          haptic: _specialsThisMove >= 2
              ? HapticKind.heavy
              : HapticKind.medium,
        ),
        Fell() => (
          asset: 'generated/audio/sfx_tick.wav',
          volume: 0.35,
          haptic: HapticKind.selection,
        ),
        Refilled() => (
          asset: 'generated/audio/sfx_plip.wav',
          volume: 0.45,
          haptic: HapticKind.selection,
        ),
        ObstacleLanded() => (
          asset: 'audio/sfx_box_break.wav',
          volume: 0.6,
          haptic: HapticKind.medium,
        ),
        ObstacleBroken() => (
          asset: 'audio/sfx_box_break.wav',
          volume: 0.7,
          haptic: HapticKind.light,
        ),
        ObstacleQueued() => (
          asset: 'generated/audio/sfx_ding.wav',
          volume: 0.5,
          haptic: HapticKind.selection,
        ),
        PowerCharged() => (
          asset: 'generated/audio/sfx_charge.wav',
          volume: 0.45,
          haptic: HapticKind.selection,
        ),
        PowerFired(:final power) => (
          asset: switch (power) {
            PowerKind.zoomies => 'audio/sfx_power_zoomies.wav',
            PowerKind.shadowPounce => 'audio/sfx_power_shadow_pounce.wav',
            PowerKind.laserChase => 'audio/sfx_power_laser_chase.wav',
          },
          volume: 0.8,
          haptic: HapticKind.heavy,
        ),
        Shuffled() => (
          asset: 'generated/audio/sfx_swish.wav',
          volume: 0.6,
          haptic: HapticKind.medium,
        ),
        TurnEnded() => (
          asset: 'generated/audio/sfx_round.wav',
          volume: 0.7,
          haptic: HapticKind.heavy,
        ),
        MatchEnded(:final outcome) => (
          asset: outcome == MatchOutcome.secondWin
              ? 'audio/sfx_defeat.wav'
              : 'audio/sfx_victory.wav',
          volume: 0.85,
          haptic: HapticKind.heavy,
        ),
        BoardReset() => (
          asset: 'generated/audio/sfx_round.wav',
          volume: 0.45,
          haptic: HapticKind.medium,
        ),
      };

  Future<void> dispose() => _out.dispose();
}

void _platformHaptics(HapticKind kind) {
  final f = switch (kind) {
    HapticKind.selection => HapticFeedback.selectionClick(),
    HapticKind.light => HapticFeedback.lightImpact(),
    HapticKind.medium => HapticFeedback.mediumImpact(),
    HapticKind.heavy => HapticFeedback.heavyImpact(),
  };
  unawaited(f.catchError((Object _) {}));
}

/// Looping music bed (`generated/audio/music_*.wav`, synthesized
/// in-house). One dedicated [AudioPlayer] with game audio focus;
/// honours the player's Music toggle live and pauses when the app is
/// backgrounded. Used for the battle loop and the calmer lobby bed.
class DuelMusic {
  DuelMusic({
    required this.enabled,
    this.asset = 'audio/bgm_battle_loop.wav',
    this.volume = 0.32,
  }) : _player = AudioPlayer() {
    unawaited(
      _player.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            usageType: AndroidUsageType.game,
            contentType: AndroidContentType.music,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      ),
    );
    unawaited(_player.setReleaseMode(ReleaseMode.loop));
  }

  /// Whether the player's Music setting is on — read on every [sync].
  final bool Function() enabled;

  /// Loop asset under `assets/` and its base volume.
  final String asset;
  final double volume;

  final AudioPlayer _player;
  bool _started = false;
  bool _backgrounded = false;

  /// Call on every state change — starts the loop when music is enabled
  /// and a duel is active, pauses it when disabled or backgrounded.
  void sync() {
    final want = enabled() && !_backgrounded;
    if (want && !_started) {
      _started = true;
      unawaited(
        _player.play(
          AssetSource(asset),
          volume: volume,
        ).catchError((Object _) {}),
      );
    } else if (!want && _started) {
      _started = false;
      unawaited(_player.pause().catchError((Object _) {}));
    }
  }

  void setBackgrounded(bool value) {
    _backgrounded = value;
    sync();
  }

  Future<void> dispose() async {
    _started = false;
    await _player.stop().catchError((Object _) {});
    await _player.dispose();
  }
}

/// Pool of [AudioPlayer]s so overlapping cues (staggered clears) do not cut
/// each other off; round-robin picks the next free voice.
class _AudioPlayersOutput implements SfxOutput {
  _AudioPlayersOutput() {
    for (var i = 0; i < 4; i++) {
      final p = AudioPlayer();
      // Low-latency mode for short cues; transient focus ducks the music
      // bed instead of pausing it or fighting for the stream.
      unawaited(p.setPlayerMode(PlayerMode.lowLatency));
      unawaited(
        p.setAudioContext(
          AudioContext(
            android: AudioContextAndroid(
              usageType: AndroidUsageType.game,
              contentType: AndroidContentType.sonification,
              audioFocus: AndroidAudioFocus.gainTransientMayDuck,
            ),
          ),
        ),
      );
      _players.add(p);
    }
  }

  final List<AudioPlayer> _players = [];
  int _next = 0;

  @override
  void play(String asset, {required double volume, required double rate}) {
    if (_players.isEmpty) return;
    final p = _players[_next++ % _players.length];
    unawaited(
      p
          .setPlaybackRate(rate)
          // The rate is a nicety — if the device rejects it, still play.
          .catchError((Object _) {})
          .then((_) => p.play(AssetSource(asset), volume: volume))
          .catchError((Object _) {}),
    );
  }

  @override
  Future<void> dispose() async {
    for (final p in _players) {
      await p.dispose();
    }
    _players.clear();
  }
}

/// Lightweight UI sound: one shared click for menu/nav taps, bound once
/// to the player's Efecte sonore setting. No-op until [bind] is called —
/// the home shell binds it at start-up, so tests never touch the audio
/// stack.
class UiSfx {
  UiSfx._();

  static bool Function() enabled = () => false;
  static AudioPlayer? _player;

  /// Bind the player's SFX toggle; called once by the shell.
  static void bind(bool Function() isEnabled) => enabled = isEnabled;

  /// A short, quiet click — the same synthesized tick used on the board.
  static void tap() {
    if (!enabled()) return;
    final p = _player ??= AudioPlayer()
      ..setPlayerMode(PlayerMode.lowLatency);
    unawaited(
      p
          .play(
            AssetSource('generated/audio/sfx_tick.wav'),
            volume: 0.3,
          )
          .catchError((Object _) {}),
    );
  }
}
