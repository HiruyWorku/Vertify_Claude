import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/jump_result.dart';

class ApiService {
  // For local dev: iOS simulator uses localhost, physical device needs your Mac's IP
  static const String _baseUrl = 'http://172.20.10.3:8000/api/v1';

  Future<JumpResult> analyzeJump({
    required File videoFile,
    required double userHeightCm,
  }) async {
    final uri = Uri.parse('$_baseUrl/jump/analyze');
    final request = http.MultipartRequest('POST', uri);

    request.fields['user_height_cm'] = userHeightCm.toString();
    request.files.add(await http.MultipartFile.fromPath('video', videoFile.path));

    final streamed = await request.send().timeout(const Duration(minutes: 5));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      return JumpResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Server error ${response.statusCode}: ${response.body}');
  }
}
