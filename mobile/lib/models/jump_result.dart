class JumpResult {
  final bool jumpDetected;
  final double? jumpHeightCm;
  final double? jumpHeightInches;
  final double? hangTimeMs;
  final double confidence;
  final List<String> processingNotes;

  const JumpResult({
    required this.jumpDetected,
    this.jumpHeightCm,
    this.jumpHeightInches,
    this.hangTimeMs,
    required this.confidence,
    this.processingNotes = const [],
  });

  factory JumpResult.fromJson(Map<String, dynamic> json) {
    final result = json['result'] as Map<String, dynamic>? ?? json;
    return JumpResult(
      jumpDetected: result['jump_detected'] as bool? ?? false,
      jumpHeightCm: (result['jump_height_cm'] as num?)?.toDouble(),
      jumpHeightInches: (result['jump_height_inches'] as num?)?.toDouble(),
      hangTimeMs: (result['hang_time_ms'] as num?)?.toDouble(),
      confidence: (result['confidence'] as num?)?.toDouble() ?? 0.0,
      processingNotes: List<String>.from(result['processing_notes'] ?? []),
    );
  }
}
