import 'package:shared_preferences/shared_preferences.dart';
import '../models/jump_record.dart';
import '../models/jump_result.dart';

class HistoryService {
  static const _key = 'jump_history';
  static const _maxRecords = 100;

  Future<List<JumpRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return JumpRecord.decode(raw);
    } catch (_) {
      return [];
    }
  }

  Future<JumpRecord> save(JumpResult result) async {
    final record = JumpRecord.fromResult(result);
    final records = await load();
    records.insert(0, record);
    if (records.length > _maxRecords) records.removeLast();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, JumpRecord.encode(records));
    return record;
  }

  Future<void> delete(String id) async {
    final records = await load();
    records.removeWhere((r) => r.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, JumpRecord.encode(records));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<JumpRecord?> personalBest() async {
    final records = await load();
    final withHeight = records.where((r) => r.heightCm != null).toList();
    if (withHeight.isEmpty) return null;
    return withHeight.reduce((a, b) => a.heightCm! > b.heightCm! ? a : b);
  }
}
