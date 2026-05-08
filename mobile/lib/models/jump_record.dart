import 'dart:convert';
import 'jump_result.dart';

class JumpRecord {
  final String id;
  final DateTime timestamp;
  final JumpResult result;

  const JumpRecord({
    required this.id,
    required this.timestamp,
    required this.result,
  });

  double? get heightCm => result.jumpHeightCm;
  double? get heightInches => result.jumpHeightInches;

  factory JumpRecord.fromResult(JumpResult result) => JumpRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        result: result,
      );

  factory JumpRecord.fromJson(Map<String, dynamic> json) => JumpRecord(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        result: JumpResult.fromJson(json['result'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'result': result.toJson(),
      };

  static String encode(List<JumpRecord> records) =>
      jsonEncode(records.map((r) => r.toJson()).toList());

  static List<JumpRecord> decode(String raw) =>
      (jsonDecode(raw) as List)
          .map((e) => JumpRecord.fromJson(e as Map<String, dynamic>))
          .toList();
}
