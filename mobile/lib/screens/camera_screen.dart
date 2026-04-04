import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../services/pose_painter.dart';
import 'result_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  late PoseDetector _poseDetector;
  List<Pose> _poses = [];
  Size? _imageSize;
  bool _isRecording = false;
  bool _isProcessingFrame = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.accurate,
      ),
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // Use platform-appropriate image format for MLKit
      final format = Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.nv21;

      _controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: format,
      );

      await _controller!.initialize();
      if (!mounted) return;

      await _controller!.startImageStream(_onCameraFrame);
      setState(() {});
    } catch (e) {
      setState(() => _initError = e.toString());
    }
  }

  Future<void> _onCameraFrame(CameraImage image) async {
    if (_isProcessingFrame) return;
    _isProcessingFrame = true;

    try {
      final inputImage = _toInputImage(image);
      if (inputImage == null) return;

      final poses = await _poseDetector.processImage(inputImage);
      if (!mounted) return;

      setState(() {
        _poses = poses;
        _imageSize = Size(image.width.toDouble(), image.height.toDouble());
      });
    } catch (_) {
      // Drop frame on error — don't block the stream
    } finally {
      _isProcessingFrame = false;
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final camera = _controller?.description;
    if (camera == null) return null;

    final rotation = InputImageRotationValue.fromRawValue(
          camera.sensorOrientation,
        ) ??
        InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // iOS: bgra8888 has a single plane
    // Android: nv21 has a single plane too but needs full buffer
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _toggleRecording() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (_isRecording) {
      try {
        await controller.stopImageStream();
      } catch (_) {}
      final file = await controller.stopVideoRecording();
      setState(() => _isRecording = false);

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(videoFile: File(file.path)),
        ),
      );
      // Restart preview on return
      try {
        await controller.startImageStream(_onCameraFrame);
      } catch (_) {}
    } else {
      try {
        await controller.stopImageStream();
      } catch (_) {}
      await controller.startVideoRecording();
      setState(() => _isRecording = true);
      // Keep pose overlay running during recording
      try {
        await controller.startImageStream(_onCameraFrame);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam_off, color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                const Text('Camera failed to start',
                    style: TextStyle(color: Colors.white, fontSize: 18)),
                const SizedBox(height: 8),
                Text(_initError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _initError = null);
                    _initCamera();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('Starting camera…', style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),

          if (_poses.isNotEmpty && _imageSize != null)
            LayoutBuilder(
              builder: (_, constraints) => CustomPaint(
                painter: PosePainter(
                  _poses,
                  _imageSize!,
                  Size(constraints.maxWidth, constraints.maxHeight),
                ),
              ),
            ),

          const Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: _TipBanner(),
          ),

          if (_isRecording)
            const Positioned(
              top: 60,
              right: 20,
              child: _RecordingBadge(),
            ),

          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(
              child: _RecordButton(
                isRecording: _isRecording,
                onTap: _toggleRecording,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipBanner extends StatelessWidget {
  const _TipBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'Stand 6–8 ft away • Full body in frame • Camera level',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70, fontSize: 13),
      ),
    );
  }
}

class _RecordingBadge extends StatelessWidget {
  const _RecordingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: Colors.white, size: 10),
          SizedBox(width: 6),
          Text('REC',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.isRecording, required this.onTap});
  final bool isRecording;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isRecording ? 32 : 60,
            height: isRecording ? 32 : 60,
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius:
                  BorderRadius.circular(isRecording ? 6 : 30),
            ),
          ),
        ),
      ),
    );
  }
}
