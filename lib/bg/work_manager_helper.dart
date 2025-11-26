import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('===== WorkManager task started: $task =====');
    print('Task time: ${DateTime.now()}');

    // Initialize notification plugin
    final FlutterLocalNotificationsPlugin notificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await notificationsPlugin.initialize(initializationSettings);

    // if (task != 'simpleTask') {
    //   print('Unknown task: $task');
    //   return false;
    // }

    // Show notification when task starts
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'background_fetch_channel',
          'Background Fetch',
          channelDescription: 'Shows notifications for background fetch tasks',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          showWhen: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await notificationsPlugin.show(
      0,
      'Background Task Running',
      'Fetching data from server...',
      platformChannelSpecifics,
    );

    try {
      // Create a fresh Dio instance for background isolate
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://rocket.builtlab.io.vn',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      // Perform the background fetch
      final response = await dio.post(
        '/api/v1/notifications/send/00002103-6101-4065-b10a-3eaa12cccefe/e4Mey_o4NUvgoPnQIjmKN7:APA91bEdat2GGavaZopm-KEVfDvLNSzix0HW8lKKd3MQoME3Qx6YGYsabQDATpBDC1ebHJ8B9l-X6ipDG8GYyvXyOfTkPXfLXvuzsNG4vBhwby1HpJcxTHU',
        data: {
          'title':
              'Background Notification. ${kDebugMode ? "Debug" : "Release"}',
          'body': 'This notification was sent from a background task (Xiaomi).',
        },
      );

      print('WorkManager fetch completed: ${response.statusCode}');

      // Print data in smaller chunks to avoid truncation
      final data = response.data.toString();
      if (data.length > 500) {
        print('WorkManager data (first 500): ${data.substring(0, 500)}...');
      } else {
        log('WorkManager data: $data');
      }

      print('WorkManager task SUCCESS');

      // Update notification with success
      await notificationsPlugin.show(
        0,
        'Background Task Complete',
        'Data fetched successfully at ${DateTime.now().hour}:${DateTime.now().minute}',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'background_fetch_channel',
            'Background Fetch',
            channelDescription:
                'Shows notifications for background fetch tasks',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: false,
            autoCancel: true,
            timeoutAfter: 3000, // Auto dismiss after 3 seconds
          ),
        ),
      );

      // Small delay to ensure logs are printed before isolate closes
      await Future.delayed(const Duration(milliseconds: 100));

      // Cancel notification after delay
      await Future.delayed(const Duration(seconds: 3));
      await notificationsPlugin.cancel(0);

      print('===== WorkManager task completed successfully =====');

      // Return true to indicate success
      return true;
    } catch (e, st) {
      print('WorkManager error: $e');
      print('Stack trace: $st');

      // Update notification with error
      await notificationsPlugin.show(
        0,
        'Background Task Failed',
        'Error: ${e.toString().substring(0, 50)}...',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'background_fetch_channel',
            'Background Fetch',
            channelDescription:
                'Shows notifications for background fetch tasks',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: false,
            autoCancel: true,
            timeoutAfter: 5000,
          ),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 100));

      // Cancel error notification after delay
      await Future.delayed(const Duration(seconds: 5));
      await notificationsPlugin.cancel(0);

      // Return false to reschedule the task
      return false;
    }
  });
}
