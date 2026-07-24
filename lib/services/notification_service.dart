import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionsGranted = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _permissionsGranted = await _requestPermissions();
    _initialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  Future<bool> _requestPermissions() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        if (granted != true) return false;
      }

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        if (granted != true) return false;
      }
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
      return false;
    }

    return true;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) await init();
    if (!_permissionsGranted) return;

    const androidDetails = AndroidNotificationDetails(
      'housekeeping_channel',
      'Housekeeping Notifications',
      channelDescription: 'Notifications for room assignments and status changes',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  Future<void> notifyRoomAssigned({
    required String roomNumber,
    required String staffName,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch % 2147483647,
      title: 'Room Assigned',
      body: '$staffName has been assigned to room $roomNumber',
    );
  }

  Future<void> notifyStatusChanged({
    required String roomNumber,
    required String newStatus,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch % 2147483647,
      title: 'Room Status Updated',
      body: 'Room $roomNumber is now $newStatus',
    );
  }

  Future<void> notifyNoteAdded({
    required String roomNumber,
    required String authorName,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch % 2147483647,
      title: 'New Note',
      body: '$authorName added a note to room $roomNumber',
    );
  }

  Future<void> notifyError({
    required String title,
    required String message,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch % 2147483647,
      title: title,
      body: message,
    );
  }
}
