import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/jump_provider.dart';
import '../models/jump_result.dart';
import '../services/history_service.dart';

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
          AnalysisState.error =>
            _ErrorView(message: provider.errorMessage ?? 'Unknown error'),
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
  late final _sub = Stream.periodic(const Duration(seconds: 1))
      .listen((_) { if (mounted) setState(() => _seconds++); });

  @override
  void dispose() { _sub.cancel(); super.dispose(); }

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
            Text(_hint, style: const TextStyle(color: Colors.white, fontSize: 17)),
            const SizedBox(height: 8),
            Text('${_seconds}s', style: const TextStyle(color: Colors.white38, fontSize: 13)),
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

class _ResultView extends StatefulWidget {
  const _ResultView({required this.result});
  final JumpResult result;

  @override
  State<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<_ResultView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _arcAnim =
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);

  bool _isPB = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    if (widget.result.jumpDetected) {
      _animController.forward();
      _saveAndCheckPB();
    }
  }

  Future<void> _saveAndCheckPB() async {
    final svc = HistoryService();
    final pb = await svc.personalBest();
    await svc.save(widget.result);
    final newPB = pb == null ||
        (widget.result.jumpHeightCm != null &&
            widget.result.jumpHeightCm! > (pb.heightCm ?? 0));
    if (mounted) setState(() { _isPB = newPB; _saved = true; });
  }

  @override
  void dispose() { _animController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (!widget.result.jumpDetected) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 64),
              const SizedBox(height: 16),
              const Text('No jump detected',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (widget.result.processingNotes.isNotEmpty)
                Text(
                  widget.result.processingNotes.first,
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
          if (_isPB && _saved)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PBBanner(),
            ),

          _HeightCard(
            heightCm: widget.result.jumpHeightCm!,
            heightInches: widget.result.jumpHeightInches!,
            arcAnim: _arcAnim,
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Hang Time',
                  value: '${(widget.result.hangTimeMs! / 1000).toStringAsFixed(2)}s',
                  icon: Icons.timer_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Confidence',
                  value: '${(widget.result.confidence * 100).toStringAsFixed(0)}%',
                  icon: Icons.verified_outlined,
                  valueColor: _confidenceColor(widget.result.confidence),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          _ConfidenceBar(confidence: widget.result.confidence),

          if (widget.result.processingNotes.isNotEmpty) ...[
            const SizedBox(height: 20),
            ...widget.result.processingNotes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.amber, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(note,
                          style: const TextStyle(color: Colors.white60, fontSize: 13)),
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

class _PBBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🏆', style: TextStyle(fontSize: 18)),
          SizedBox(width: 8),
          Text('New Personal Best!',
              style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _HeightCard extends StatelessWidget {
  const _HeightCard({
    required this.heightCm,
    required this.heightInches,
    required this.arcAnim,
  });
  final double heightCm;
  final double heightInches;
  final Animation<double> arcAnim;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
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
          const Text('VERTICAL JUMP',
              style: TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 2)),
          const SizedBox(height: 16),

          // Animated arc
          SizedBox(
            height: 100,
            child: AnimatedBuilder(
              animation: arcAnim,
              builder: (_, __) => CustomPaint(
                painter: _ArcPainter(progress: arcAnim.value),
                size: const Size(double.infinity, 100),
              ),
            ),
          ),

          const SizedBox(height: 8),
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

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;

    final path = Path();
    const steps = 60;
    final totalSteps = (steps * progress).round();

    for (int i = 0; i <= totalSteps; i++) {
      final t = i / steps;
      final x = t * size.width;
      // Parabola: y = 4h * t * (1 - t), inverted (goes up then down)
      final y = size.height - (4 * size.height * 0.9 * t * (1 - t));

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);

    // Moving dot at tip of arc
    if (progress > 0) {
      final t = progress;
      final dotX = t * size.width;
      final dotY = size.height - (4 * size.height * 0.9 * t * (1 - t));
      canvas.drawCircle(Offset(dotX, dotY), 4, dotPaint);
    }

    // Ground line
    final groundPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width * progress, size.height),
      groundPaint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}

class _ConfidenceBar extends StatelessWidget {
  const _ConfidenceBar({required this.confidence});
  final double confidence;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('MEASUREMENT CONFIDENCE',
            style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 1.5)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: confidence,
            minHeight: 6,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(_barColor(confidence)),
          ),
        ),
      ],
    );
  }

  Color _barColor(double c) {
    if (c >= 0.75) return Colors.greenAccent;
    if (c >= 0.5) return Colors.amber;
    return Colors.redAccent;
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });
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
            const Text('Analysis failed',
                style: TextStyle(color: Colors.white, fontSize: 20)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 13)),
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
