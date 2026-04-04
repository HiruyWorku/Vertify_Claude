import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/jump_provider.dart';
import '../models/jump_result.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.videoFile});
  final File videoFile;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JumpProvider>().analyze(widget.videoFile);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Jump Result'),
      ),
      body: Consumer<JumpProvider>(
        builder: (_, provider, __) => switch (provider.state) {
          AnalysisState.idle || AnalysisState.uploading => const _LoadingView(),
          AnalysisState.done => _ResultView(result: provider.result!),
          AnalysisState.error => _ErrorView(message: provider.errorMessage ?? 'Unknown error'),
        },
      ),
    );
  }
}

// --- Loading ---

class _LoadingView extends StatefulWidget {
  const _LoadingView();

  @override
  State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView> {
  int _seconds = 0;
  late final _ticker = Stream.periodic(const Duration(seconds: 1));
  late final _sub = _ticker.listen((_) {
    if (mounted) setState(() => _seconds++);
  });

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  String get _hint {
    if (_seconds < 15) return 'Uploading video…';
    if (_seconds < 40) return 'Running pose detection…';
    if (_seconds < 80) return 'Detecting jump arc…';
    return 'Almost done…';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF00E5FF)),
            const SizedBox(height: 24),
            Text(
              _hint,
              style: const TextStyle(color: Colors.white, fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(
              '${_seconds}s',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 20),
            const Text(
              'Processing on CPU can take 1–3 minutes.\nKeep the app open.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Result ---

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});
  final JumpResult result;

  @override
  Widget build(BuildContext context) {
    if (!result.jumpDetected) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 64),
              const SizedBox(height: 16),
              const Text(
                'No jump detected',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (result.processingNotes.isNotEmpty)
                Text(
                  result.processingNotes.first,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 14),
                ),
              const SizedBox(height: 32),
              _RetakeButton(),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Main height card
          _HeightCard(
            heightCm: result.jumpHeightCm!,
            heightInches: result.jumpHeightInches!,
          ),
          const SizedBox(height: 20),

          // Stats row
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Hang Time',
                  value: '${(result.hangTimeMs! / 1000).toStringAsFixed(2)}s',
                  icon: Icons.timer_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Confidence',
                  value: '${(result.confidence * 100).toStringAsFixed(0)}%',
                  icon: Icons.verified_outlined,
                  valueColor: _confidenceColor(result.confidence),
                ),
              ),
            ],
          ),

          // Warnings
          if (result.processingNotes.isNotEmpty) ...[
            const SizedBox(height: 20),
            ...result.processingNotes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.amber, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(note, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),
          _RetakeButton(),
        ],
      ),
    );
  }

  Color _confidenceColor(double c) {
    if (c >= 0.75) return Colors.greenAccent;
    if (c >= 0.5) return Colors.amber;
    return Colors.redAccent;
  }
}

class _HeightCard extends StatelessWidget {
  const _HeightCard({required this.heightCm, required this.heightInches});
  final double heightCm;
  final double heightInches;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Text('VERTICAL JUMP', style: TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 2)),
          const SizedBox(height: 12),
          Text(
            '${heightInches.toStringAsFixed(1)}"',
            style: const TextStyle(
              color: Color(0xFF00E5FF),
              fontSize: 72,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${heightCm.toStringAsFixed(1)} cm',
            style: const TextStyle(color: Colors.white54, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, this.valueColor});
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white38, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}

class _RetakeButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        context.read<JumpProvider>().reset();
        Navigator.pop(context);
      },
      icon: const Icon(Icons.replay),
      label: const Text('Retake Jump'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00E5FF),
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// --- Error ---

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
            const SizedBox(height: 16),
            const Text('Analysis failed', style: TextStyle(color: Colors.white, fontSize: 20)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 13)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white12,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
