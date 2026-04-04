import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/jump_provider.dart';
import 'camera_screen.dart';

/// First-run screen: user enters their height before recording.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  double _heightCm = 180;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              const Text(
                'Jumpology',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Measure your vertical jump with your phone camera.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 15),
              ),
              const Spacer(),
              const Text(
                'YOUR HEIGHT',
                style: TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 2),
              ),
              const SizedBox(height: 12),
              // Height display
              Text(
                '${_heightCm.round()} cm  ·  ${(_heightCm / 2.54).toStringAsFixed(1)}"',
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Slider
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF00E5FF),
                  inactiveTrackColor: Colors.white12,
                  thumbColor: const Color(0xFF00E5FF),
                  overlayColor: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                ),
                child: Slider(
                  value: _heightCm,
                  min: 120,
                  max: 230,
                  divisions: 110,
                  onChanged: (v) => setState(() => _heightCm = v),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  context.read<JumpProvider>().userHeightCm = _heightCm;
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CameraScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Start Recording', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
