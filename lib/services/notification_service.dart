import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Called when a background FCM message arrives (process-level, no UI)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background isolate — only show local notification
  await NotificationService.instance.showLocalNotification(
    title: message.notification?.title ?? message.data['senderName'] ?? 'PeerLink',
    body: message.notification?.body ?? 'New message',
    payload: message.data['senderId'],
  );
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channelId = 'peerlink_chat';
  static const _channelName = 'Chat Notifications';

  // Set this in main.dart so we can navigate from notification taps
  static GlobalKey<NavigatorState>? navigatorKey;

  // Emits the senderId when a notification is tapped
  final _notificationTapController = StreamController<String>.broadcast();
  Stream<String> get notificationTapStream => _notificationTapController.stream;

  Future<void> initialize() async {
    // Android notification channel
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Chat requests and incoming messages',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Local notifications init
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Foreground FCM → show local notification
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Notification tap while app was in background (not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // App opened from terminated state via notification
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _handleNotificationTap(initial);
  }

  // Request permission — call this at app launch
  Future<void> requestPermission() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _localNotifications.show(
      payload.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: payload,
    );
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ??
        message.data['senderName'] ??
        'PeerLink';
    final body =
        message.notification?.body ?? 'Wants to chat';
    final senderId = message.data['senderId'] as String?;
    showLocalNotification(title: title, body: body, payload: senderId);
  }

  void _handleNotificationTap(RemoteMessage message) {
    final senderId = message.data['senderId'] as String?;
    if (senderId != null) _notificationTapController.add(senderId);
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    final senderId = response.payload;
    if (senderId != null && senderId.isNotEmpty) {
      _notificationTapController.add(senderId);
    }
  }
}
