import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:bg_service/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

@pragma('vm:entry-point')
class BackgroundServiceHelper {
  static final service = FlutterBackgroundService();
  static Timer? _periodicTimer;
  static int _fetchCount = 0;
  static int _errorCount = 0;
  static DateTime? _lastSuccessfulFetch;

  @pragma('vm:entry-point')
  static Future<void> initialize() async {
    if (Platform.isAndroid || Platform.isIOS) {
      service.configure(
        iosConfiguration: IosConfiguration(
          autoStart: false, // Don't auto-start on iOS for battery optimization
          onForeground: onStart,
          onBackground: iosBackground,
        ),
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: true,
          isForegroundMode: true,
          notificationChannelId: 'background_service',
          initialNotificationTitle: 'Caching Data By Polaris Edge',
          initialNotificationContent: 'Connecting to server...',
          foregroundServiceNotificationId: 999,
          autoStartOnBoot: false,
        ),
      );
    }
  }

  @pragma('vm:entry-point')
  static bool iosBackground(ServiceInstance service) {
    WidgetsFlutterBinding.ensureInitialized();
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) {
    WidgetsFlutterBinding.ensureInitialized();

    // Listen for stop command
    service.on('stopService').listen((event) {
      _cleanup();
      service.stopSelf();
    });

    // Listen for custom commands
    service.on('setInterval').listen((event) {
      if (event?['seconds'] != null) {
        _restartTimer(service, Duration(seconds: event!['seconds'] as int));
      }
    });

    // Start periodic task with optimized interval
    // _startPeriodicTask(
    //   service,
    //   const Duration(seconds: 5),
    // ); // Increased from 10s to 30s
    if (Platform.isAndroid) {
      // Update notification to show activity
      service.invoke('update', {
        'notification_title': 'Background Service Active',
        'notification_content':
            'Last update: ${DateTime.now().hour}:${DateTime.now().minute}',
      });
    }
    _performBackgroundTask(service);

  }

  static void _startPeriodicTask(ServiceInstance service, Duration interval) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (timer) async {
      if (Platform.isAndroid) {
        // Update notification to show activity
        service.invoke('update', {
          'notification_title': 'Background Service Active',
          'notification_content':
              'Last update: ${DateTime.now().hour}:${DateTime.now().minute}',
        });
      }

      await _performBackgroundTask(service);
    });

    // Perform initial fetch
    _performBackgroundTask(service);
  }

  static void _restartTimer(ServiceInstance service, Duration newInterval) {
    _periodicTimer?.cancel();
    _startPeriodicTask(service, newInterval);
    log('Timer restarted with interval: ${newInterval.inSeconds}s');
  }

  static Future<void> _performBackgroundTask(ServiceInstance service) async {
    try {
      final stopwatch = Stopwatch()..start();

      final res = await ApiClient.instance
          .get(id: '00002103-6101-4065-b10a-3eaa12cccefe')
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException('API request timed out');
            },
          );

      stopwatch.stop();
      _fetchCount++;
      _lastSuccessfulFetch = DateTime.now();
      _errorCount = 0; // Reset error count on success

      log(
        'Background fetch #$_fetchCount completed in ${stopwatch.elapsedMilliseconds}ms',
      );

      log('BG fetched data: $res');

      // Send data back to UI if needed
      service.invoke('update', {
        'status': 'success',
        'data': res,
        'fetchCount': _fetchCount,
        'timestamp': _lastSuccessfulFetch?.toIso8601String(),
      });
    } on TimeoutException catch (e) {
      _errorCount++;
      log('BG Timeout error ($_errorCount): $e');
      _handleError(service, 'Timeout');
    } catch (e, st) {
      _errorCount++;
      log("BG error ($_errorCount): $e\n$st");
      _handleError(service, 'Error');

      // If too many consecutive errors, back off
      if (_errorCount >= 3) {
        log('Too many errors, increasing interval to reduce resource usage');
        _restartTimer(service, const Duration(minutes: 2));
      }
    }
  }

  static void _handleError(ServiceInstance service, String errorType) {
    service.invoke('update', {
      'status': 'error',
      'errorType': errorType,
      'errorCount': _errorCount,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void _cleanup() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    log('Background service cleanup completed');
  }

  // Helper method to start service from UI
  static Future<bool> startService() async {
    final isRunning = await service.isRunning();
    if (isRunning) {
      // If already running, restart the timer
      log('Service already running, restarting timer');
      return true;
    }
    return await service.startService();
  }

  // Helper method to stop service
  static Future<void> stopService() async {
    service.invoke('stopService');
  }

  // Helper method to check if service is running
  static Future<bool> isServiceRunning() async {
    return await service.isRunning();
  }
}
