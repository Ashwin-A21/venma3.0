import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  // Callback for when notification is tapped
  static Function(String? payload)? onNotificationTap;

  Future<void> initialize() async {
    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Initialization settings
    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        if (onNotificationTap != null) {
          onNotificationTap!(response.payload);
        }
      },
    );

    // Create notification channels for Android
    await _createNotificationChannels();
  }

  Future<void> _createNotificationChannels() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      // Message channel - high importance
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'messages',
          'Messages',
          description: 'New message notifications',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );

      // Calls channel - max importance
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'calls',
          'Calls',
          description: 'Incoming call notifications',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );

      // Status channel - default importance
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'status',
          'Status Updates',
          description: 'Friend status notifications',
          importance: Importance.defaultImportance,
          playSound: false,
          showBadge: true,
        ),
      );
    }
  }

  /// Show a message notification
  Future<void> showMessageNotification({
    required String senderName,
    required String message,
    String? senderAvatar,
    String? friendshipId,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'messages',
      'Messages',
      channelDescription: 'New message notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      category: AndroidNotificationCategory.message,
      styleInformation: null, // Can add BigTextStyleInformation for long messages
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    // Generate notification ID from friendship ID or random
    final notificationId = friendshipId?.hashCode ?? DateTime.now().millisecondsSinceEpoch;

    await _notifications.show(
      notificationId,
      senderName,
      message,
      notificationDetails,
      payload: friendshipId,
    );
  }

  /// Show an incoming call notification
  Future<void> showCallNotification({
    required String callerName,
    required bool isVideo,
    String? callId,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'calls',
      'Calls',
      channelDescription: 'Incoming call notifications',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      ongoing: true,
      autoCancel: false,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      callId?.hashCode ?? 0,
      isVideo ? 'Incoming Video Call' : 'Incoming Call',
      '$callerName is calling...',
      notificationDetails,
      payload: 'call:$callId',
    );
  }

  /// Show a status update notification
  Future<void> showStatusNotification({
    required String friendName,
    String? message,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'status',
      'Status Updates',
      channelDescription: 'Friend status notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      enableVibration: false,
      playSound: false,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '$friendName posted a status',
      message ?? 'Tap to view',
      notificationDetails,
    );
  }

  /// Show a nudge notification
  Future<void> showNudgeNotification({
    required String senderName,
    String? friendshipId,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'messages',
      'Messages',
      channelDescription: 'New message notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Nudge!',
      '$senderName sent you a nudge 👋',
      notificationDetails,
      payload: friendshipId,
    );
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Cancel call notification
  Future<void> cancelCallNotification(String? callId) async {
    if (callId != null) {
      await _notifications.cancel(callId.hashCode);
    }
  }
}
