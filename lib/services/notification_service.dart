import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notification service for EDSA Carousel alerts
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Notification channel configuration
  static const String _channelId = 'edsa_carousel_alerts';
  static const String _channelName = 'Station Alerts';
  static const String _channelDescription = 
      'Notifications for approaching your destination station';

  // Notification IDs
  static const int stationAlertId = 1;
  static const int arrivalNotificationId = 2;
  static const int trackingActiveId = 100;

  /// Initialize the notification service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Android initialization settings
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Initialize with callback for notification taps
      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
        onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTapped,
      );

      if (initialized == true) {
        // Create notification channel for Android
        await _createNotificationChannel();
        _isInitialized = true;
        debugPrint('NotificationService initialized successfully');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
      return false;
    }
  }

  /// Create the notification channel for Android
  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Request notification permission (Android 13+)
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      final granted = await androidPlugin?.requestNotificationsPermission();
      return granted ?? false;
    } else if (Platform.isIOS) {
      final iosPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      
      final granted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  /// Check if notifications are permitted
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      return await androidPlugin?.areNotificationsEnabled() ?? false;
    }
    return true;
  }

  /// Show a basic notification (for testing)
  Future<void> showTestNotification() async {
    if (!_isInitialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Test notification',
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      0,
      '🚌 EDSA Carousel',
      'Notifications are working! You will be alerted when approaching your station.',
      details,
    );
  }

  /// Show station approaching alert
  Future<void> showStationAlert({
    required String stationName,
    required int stationsAway,
    String? eta,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    String title;
    String body;
    
    if (stationsAway <= 1) {
      title = '🚨 PREPARE TO ALIGHT!';
      body = '$stationName is the next stop!';
    } else if (stationsAway == 2) {
      title = '⚠️ Almost There!';
      body = '$stationName is 2 stations away${eta != null ? ' (~$eta)' : ''}';
    } else {
      title = '📍 Approaching Destination';
      body = '$stationName is $stationsAway stations away${eta != null ? ' (~$eta)' : ''}';
    }

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ticker: title,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(body),
      category: AndroidNotificationCategory.navigation,
      visibility: NotificationVisibility.public,
      fullScreenIntent: stationsAway <= 1, // Full screen for urgent alerts
      ongoing: false,
      autoCancel: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      stationAlertId,
      title,
      body,
      details,
    );
  }

  /// Show arrival notification
  Future<void> showArrivalNotification({
    required String stationName,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      ticker: 'You have arrived!',
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.navigation,
      visibility: NotificationVisibility.public,
      fullScreenIntent: true,
      ongoing: false,
      autoCancel: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      arrivalNotificationId,
      '🎉 You Have Arrived!',
      'Welcome to $stationName. Time to alight!',
      details,
    );
  }

  /// Show persistent tracking notification (foreground service style)
  Future<void> showTrackingNotification({
    required String destination,
    required int stationsAway,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      icon: '@mipmap/ic_launcher',
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      category: AndroidNotificationCategory.service,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: true,
      presentSound: false,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      trackingActiveId,
      '🚌 Tracking to $destination',
      '$stationsAway stations remaining',
      details,
    );
  }

  /// Update the tracking notification
  Future<void> updateTrackingNotification({
    required String destination,
    required int stationsAway,
  }) async {
    await showTrackingNotification(
      destination: destination,
      stationsAway: stationsAway,
    );
  }

  /// Cancel the tracking notification
  Future<void> cancelTrackingNotification() async {
    await _notifications.cancel(trackingActiveId);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Handle navigation based on payload if needed
  }

  /// Handle background notification tap
  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTapped(NotificationResponse response) {
    debugPrint('Background notification tapped: ${response.payload}');
  }
}

// ============ PROVIDERS ============

/// Provider for notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Provider for notification initialization state
final notificationInitializedProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  return await service.initialize();
});

/// Provider for notification permission state
final notificationPermissionProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  await service.initialize();
  return await service.areNotificationsEnabled();
});
