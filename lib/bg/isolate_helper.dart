import 'dart:isolate';

import 'package:bg_service/api_client.dart';

class IsolateHelper {
  Future<Map<String, dynamic>> processDataInBackground(String userId) async {
    final receivePort = ReceivePort();


    await Isolate.spawn(handleMessageFromIsolate, [userId, receivePort.sendPort]);
    final result = await receivePort.first;
    return result as Map<String, dynamic>;
  }

  void handleMessageFromIsolate(dynamic message) async {
    final userId = message[0] as String;
    final sendPort = message[1] as SendPort;
    final result = await ApiClient.instance.get(id: userId);

    sendPort.send(result);
  }
}
