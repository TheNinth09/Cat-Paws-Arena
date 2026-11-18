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

  void play(BoardEvent event) {
    if (!_enabled()) return;
    final rate = _rateFor(event);
    final cue = _cueFor(event);
    _out.play(cue.asset, volume: cue.volume, rate: rate);
    final h = cue.haptic;
    if (h != null && _hapticsEnabled()) _haptics(h);
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
    if (moveStart) _cascade = 0;
    if (!clearStep) return 1;
    _cascade = _cascade >= 8 ? 8 : _cascade + 1;
    return 1 + 0.12 * _cascade;
  }

  ({String asset, double volume, HapticKind? haptic}) _cueFor(BoardEvent e) =>
      switch (e) {
        Swapped() => (
          asset: 'generated/audio/sfx_swap.wav',
          volume: 0.5,
          haptic: HapticKind.selection,
        ),
        SwapRejected() => (
          asset: 'generated/audio/sfx_reject.wav',
          volume: 0.55,
          haptic: HapticKind.medium,
        ),
        Cleared() => (
          asset: 'generated/audio/sfx_pop.wav',
          volume: 0.6,
          haptic: HapticKind.light,
        ),
        SpecialCreated() => (
          asset: 'generated/audio/sfx_chime.wav',
          volume: 0.55,
          haptic: HapticKind.selection,
        ),
        SpecialFired() => (
          asset: 'generated/audio/sfx_special.wav',
          volume: 0.6,
          haptic: HapticKind.medium,
        ),
        Fell() => (
          asset: 'generated/audio/sfx_tick.wav',
          volume: 0.45,
          haptic: HapticKind.selection,
        ),
        Refilled() => (
          asset: 'generated/audio/sfx_plip.wav',
          volume: 0.5,
          haptic: HapticKind.selection,
        ),
        ObstacleLanded() => (
          asset: 'generated/audio/sfx_thud.wav',
          volume: 0.7,
          haptic: HapticKind.medium,
        ),
        ObstacleBroken() => (
          asset: 'generated/audio/sfx_crack.wav',
          volume: 0.6,
          haptic: HapticKind.medium,
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
        PowerFired() => (
          asset: 'generated/audio/sfx_power.wav',
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
        MatchEnded() => (
          asset: 'generated/audio/sfx_end.wav',
          volume: 0.8,
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

/// Pool of [AudioPlayer]s so overlapping cues (staggered clears) do not cut
/// each other off; round-robin picks the next free voice.
class _AudioPlayersOutput implements SfxOutput {
  _AudioPlayersOutput() {
    for (var i = 0; i < 4; i++) {
      _players.add(AudioPlayer());
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
