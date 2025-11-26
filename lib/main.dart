import 'dart:async';

import 'package:bg_service/api_client.dart';
import 'package:bg_service/bg/background_service_helper.dart';
import 'package:bg_service/bg/compute_helper.dart';
import 'package:bg_service/bg/isolate_helper.dart';
import 'package:bg_service/bg/work_manager_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:workmanager/workmanager.dart';

// Import the callback dispatcher
export 'package:bg_service/bg/work_manager_helper.dart' show callbackDispatcher;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }

  if (await Permission.scheduleExactAlarm.isDenied) {
    await Permission.scheduleExactAlarm.request();
  }

  if (await Permission.location.isDenied) {
    await Permission.location.request();
  }

  if (await Permission.locationAlways.isDenied) {
    await Permission.locationAlways.request();
  }

  if (await Permission.locationWhenInUse.isDenied) {
    await Permission.locationWhenInUse.request();
  }

  if (await Permission.ignoreBatteryOptimizations.isDenied) {
    await Permission.ignoreBatteryOptimizations.request();
  }

  // Initialize WorkManager with callback dispatcher
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: kDebugMode, // Auto-detect debug mode
  );

  // Register task only once based on build mode
  if (kDebugMode) {
    // Debug: One-off task for quick testing (1 second delay)
    await Workmanager().registerOneOffTask(
      "debug_task",
      "simpleTask",
      initialDelay: const Duration(seconds: 1),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep, // Don't replace if exists
    );
  } else {
    // Release: Register periodic task for every 15 minutes
    await Workmanager().registerPeriodicTask(
      "periodic_task",
      "simpleTask",
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
  print('WorkManager tasks registered.');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final userId = '00002103-6101-4065-b10a-3eaa12cccefe';
  String _data = '';
  bool _isServiceRunning = false;
  StreamSubscription? _serviceSubscription;

  void _fetch() async {
    final res = await ApiClient.instance.get(id: userId);
    setState(() {
      _data = res.toString();
    });
  }

  void _fetchWithIsolate() async {
    setState(() {
      _data = 'Loading...';
    });
    final res = await IsolateHelper().processDataInBackground(userId);
    setState(() {
      _data = res.toString();
    });
  }

  void _fetchWithCompute() async {
    setState(() {
      _data = 'Loading...';
    });
    final res = await ComputeHelper().processLargeDataSet(userId);
    setState(() {
      _data = res.toString();
    });
  }

  @override
  void initState() {
    super.initState();
    _checkServiceStatus();

    // Listen to service updates
    _serviceSubscription = FlutterBackgroundService().on('update').listen((
      event,
    ) async {
      if (event?['data'] != null) {
        setState(() {
          _data = event!['data'].toString();
        });
        await Future.delayed(const Duration(seconds: 1));
        setState(() {
          _data = '';
        });
      }
    });
  }

  @override
  void dispose() {
    _serviceSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkServiceStatus() async {
    final isRunning = await BackgroundServiceHelper.isServiceRunning();
    setState(() {
      _isServiceRunning = isRunning;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          spacing: 12,
          children: <Widget>[
            CircularProgressIndicator(),
            const Text('Data from API:'),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _data,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium!.copyWith(fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'work',
            onPressed: () async {
              // Trigger WorkManager task immediately
              await Workmanager().registerOneOffTask(
                DateTime.now().millisecondsSinceEpoch.toString(),
                "simpleTask",
                initialDelay: const Duration(seconds: 1),
              );
              setState(() {
                _data = 'WorkManager task triggered';
              });
            },
            tooltip: 'Trigger WorkManager',
            child: const Icon(Icons.work),
          ),
          FloatingActionButton(
            heroTag: 'isolate',
            onPressed: _fetchWithIsolate,
            tooltip: 'Isolate',
            child: Text(
              'Isolate',
              style: Theme.of(context).textTheme.bodySmall!,
            ),
          ),
          FloatingActionButton(
            heroTag: 'compute',
            onPressed: _fetchWithCompute,
            tooltip: 'Compute',
            child: Text(
              'Compute',
              style: Theme.of(context).textTheme.bodySmall!,
            ),
          ),
          FloatingActionButton(
            heroTag: 'service',
            onPressed: () async {
              if (_isServiceRunning) {
                await BackgroundServiceHelper.stopService();
                await Future.delayed(const Duration(milliseconds: 500));
                final isRunning =
                    await BackgroundServiceHelper.isServiceRunning();
                setState(() {
                  _isServiceRunning = isRunning;
                  _data = isRunning
                      ? 'Service still running'
                      : 'Service stopped';
                });
              } else {
                await BackgroundServiceHelper.startService();
                await Future.delayed(const Duration(milliseconds: 500));
                final isRunning =
                    await BackgroundServiceHelper.isServiceRunning();
                setState(() {
                  _isServiceRunning = isRunning;
                  _data = isRunning
                      ? 'Service started'
                      : 'Failed to start service';
                });
              }
            },
            tooltip: _isServiceRunning ? 'Stop' : 'Start',
            backgroundColor: _isServiceRunning ? Colors.red : Colors.green,
            child: Icon(_isServiceRunning ? Icons.stop : Icons.play_arrow),
          ),
        ],
      ),
    );
  }
}
