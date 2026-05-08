import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Draws the detected skeleton overlay on the camera preview.
/// Coordinates from MLKit are in image space — we scale to widget space.
class PosePainter extends CustomPainter {
  PosePainter(this.poses, this.imageSize, this.widgetSize);

  final List<Pose> poses;
  final Size imageSize;
  final Size widgetSize;

  static const _connections = [
    // Torso
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder),
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip),
    (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip),
    (PoseLandmarkType.leftHip, PoseLandmarkType.rightHip),
    // Left arm
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow),
    (PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist),
    // Right arm
    (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow),
    (PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist),
    // Left leg
    (PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee),
    (PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle),
    // Right leg
    (PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee),
    (PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final bonePaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final jointPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..style = PaintingStyle.fill;

    for (final pose in poses) {
      // Draw bones
      for (final (a, b) in _connections) {
        final lmA = pose.landmarks[a];
        final lmB = pose.landmarks[b];
        if (lmA == null || lmB == null) continue;
        if (lmA.likelihood < 0.5 || lmB.likelihood < 0.5) continue;

        canvas.drawLine(
          _scale(lmA.x, lmA.y),
          _scale(lmB.x, lmB.y),
          bonePaint,
        );
      }

      // Draw joints
      for (final lm in pose.landmarks.values) {
        if (lm.likelihood < 0.5) continue;
        canvas.drawCircle(_scale(lm.x, lm.y), 4, jointPaint);
      }
    }
  }

  Offset _scale(double x, double y) {
    return Offset(
      x / imageSize.width * widgetSize.width,
      y / imageSize.height * widgetSize.height,
    );
  }

  @override
  bool shouldRepaint(PosePainter oldDelegate) =>
      oldDelegate.poses != poses;
}
