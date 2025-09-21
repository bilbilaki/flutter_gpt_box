import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper around flutter_local_notifications.
/// On Android we typically rely on background_downloader built-in notifications
/// for progress. We can still show summary notifications on complete/error.
/// On Linux/Windows we show progress and final state ourselves.
class NotificationService {
  NotificationService._();
  static final NotificationService I = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'downloads_channel';
  static const String channelName = 'Downloads';
  static const String channelDescription = 'Download progress and results';

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    ); // customize
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open',
      // appName will be inherited from app
    );
    const windowsSettings = WindowsInitializationSettings(
      appName: 'Download Manager', appUserModelId: '', guid: '',
      // Provide a GUID if you want to use advanced features
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      linux: linuxSettings,
      windows: windowsSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) async {
        // If you pass a file path in payload, you can handle file opening in app
        // The DownloadManagerService also supports auto-open via background_downloader
      },
    );

    // Android channel (ignored on Desktop platforms)
    const androidChannel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.high,
      showBadge: false,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);

    // Android 13+ permissions
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  Future<void> showOrUpdateProgress({
    required int id,
    required String title,
    required String body,
    required int progressPercent, // 0..100
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        onlyAlertOnce: true,
        showProgress: true,
        maxProgress: 100,
        progress: progressPercent.clamp(0, 100),
        playSound: false,
        enableVibration: false,
      ),
      linux: LinuxNotificationDetails(
        defaultActionName: '$title $body ($progressPercent%)',
        urgency: LinuxNotificationUrgency.normal,
        // Many Linux servers don't have progress bars; emulate with % text
      ),
      windows: const WindowsNotificationDetails(),
    );
    await _plugin.show(id, title, body, details, payload: null);
  }

  Future<void> showSummary({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final details = NotificationDetails(
      android: const AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      linux: const LinuxNotificationDetails(),
      windows: const WindowsNotificationDetails(),
    );
    await _plugin.show(id, title, body, details, payload: payload);
  }

  Future<void> cancel(int id) => _plugin.cancel(id);
  Future<void> cancelAll() => _plugin.cancelAll();
}
