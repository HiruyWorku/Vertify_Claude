import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/jump_result.dart';
import '../services/api_service.dart';

enum AnalysisState { idle, uploading, done, error }

class JumpProvider extends ChangeNotifier {
  final _api = ApiService();

  AnalysisState state = AnalysisState.idle;
  JumpResult? result;
  String? errorMessage;

  double userHeightCm = 180.0;

  Future<void> analyze(File videoFile) async {
    state = AnalysisState.uploading;
    result = null;
    errorMessage = null;
    notifyListeners();

    try {
      result = await _api.analyzeJump(
        videoFile: videoFile,
        userHeightCm: userHeightCm,
      );
      state = AnalysisState.done;
    } catch (e) {
      errorMessage = e.toString();
      state = AnalysisState.error;
    }
    notifyListeners();
  }

  void reset() {
    state = AnalysisState.idle;
    result = null;
    errorMessage = null;
    notifyListeners();
  }
}
