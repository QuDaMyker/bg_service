  import 'package:bg_service/api_client.dart';
import 'package:flutter/foundation.dart';


class ComputeHelper {

  Future<Map<String, dynamic>> processLargeDataSet(String id) async {
    return await compute(_processData, id);
  }
  static Future<Map<String, dynamic>> _processData(String userId) async {
    final result = await ApiClient.instance.get(id: userId);
    return result;
  }
}