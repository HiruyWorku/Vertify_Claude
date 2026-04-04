import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/jump_result.dart';

// Change this to your Mac's local IP before running on a physical device.
// Run `ipconfig getifaddr en0` on your Mac to get the current IP.
// Simulator: use 127.0.0.1
// Physical device via iPhone hotspot: typically 172.20.10.x
const String kApiBaseUrl = 'http://172.20.10.3:8000/api/v1';

class ApiService {
  Future<JumpResult> analyzeJump({
    required File videoFile,
    required double userHeightCm,
  }) async {
    final uri = Uri.parse('$kApiBaseUrl/jump/analyze');
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
