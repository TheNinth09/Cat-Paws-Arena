import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local daily-reward reminder — one inexact repeating notification that
/// invites the player back to claim the free shop gift. Honest preset
/// copy only, no countdown or purchase pressure, and fully disabled when
/// the Notificări toggle is off. Initialisation is lazy and best-effort:
/// on platforms without the plugin (tests, web) every call is a no-op.
class GameNotifications {
  GameNotifications._();

  static const _id = 42;
  static const _channelId = 'daily_reward';
  static const _channelName = 'Recompensa zilnică';
  static const _channelDesc =
      'Memento zilnic pentru recompensa gratuită din magazin.';

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _scheduled = false;

  /// First-call setup: creates the plugin instance and the Android
  /// channel. Never throws — a failed init just disables notifications.
  static Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      final ok = await _plugin.initialize(settings: settings);
      _initialized = ok != false;
    } on MissingPluginException {
      _initialized = false;
    } on Object {
      _initialized = false;
    }
  }

  /// Bind the player's Notificări toggle. `enabled` is a getter so the
  /// shell can re-sync on every settings change.
  static Future<void> sync(bool Function() enabled) async {
    if (kIsWeb) return;
    await _init();
    if (!_initialized) return;
    if (!enabled()) {
      if (_scheduled) {
        await _cancel();
      }
      return;
    }
    if (_scheduled) return;
    try {
      // Android 13+ needs the runtime permission; request it once.
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      if (Platform.isAndroid && granted == false) return;
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      );
      await _plugin.periodicallyShow(
        id: _id,
        title: 'O recompensă te așteaptă! 🐾',
        body: 'Recompensa zilnică din magazin e pregătită — vino să o ridici.',
        repeatInterval: RepeatInterval.daily,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      _scheduled = true;
    } on Object {
      // Scheduling is best-effort; never crash the shell over it.
    }
  }

  static Future<void> _cancel() async {
    try {
      await _plugin.cancel(id: _id);
    } on MissingPluginException {
      // No notification stack on this platform — nothing to cancel.
    } on Object {
      // Cancelling is best-effort; keep _scheduled consistent anyway.
    }
    _scheduled = false;
  }
}
