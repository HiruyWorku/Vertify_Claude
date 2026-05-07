import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/jump_record.dart';
import '../services/history_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _service = HistoryService();
  List<JumpRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await _service.load();
    if (mounted) setState(() { _records = records; _loading = false; });
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Clear history?', style: TextStyle(color: Colors.white)),
        content: const Text('This cannot be undone.', style: TextStyle(color: Colors.white60)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.clear();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Jump History'),
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          : _records.isEmpty
              ? _EmptyState()
              : _HistoryBody(records: _records),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart, color: Colors.white24, size: 64),
          SizedBox(height: 16),
          Text('No jumps recorded yet', style: TextStyle(color: Colors.white38, fontSize: 16)),
          SizedBox(height: 8),
          Text('Complete a jump to see your history', style: TextStyle(color: Colors.white24, fontSize: 13)),
        ],
      ),
    );
  }
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({required this.records});
  final List<JumpRecord> records;

  List<JumpRecord> get _withHeight => records.where((r) => r.heightCm != null).toList();

  @override
  Widget build(BuildContext context) {
    final withHeight = _withHeight;
    final pb = withHeight.isEmpty ? null
        : withHeight.reduce((a, b) => a.heightCm! > b.heightCm! ? a : b);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (pb != null) ...[
          _PBCard(record: pb),
          const SizedBox(height: 20),
        ],
        if (withHeight.length >= 2) ...[
          _ChartCard(records: withHeight.reversed.toList()),
          const SizedBox(height: 20),
        ],
        const Text('RECENT JUMPS', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 2)),
        const SizedBox(height: 12),
        ...records.map((r) => _JumpTile(record: r, isPB: r.id == pb?.id)),
      ],
    );
  }
}

class _PBCard extends StatelessWidget {
  const _PBCard({required this.record});
  final JumpRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 36)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PERSONAL BEST', style: TextStyle(color: Color(0xFFFFD700), fontSize: 11, letterSpacing: 2)),
                const SizedBox(height: 4),
                Text(
                  '${record.heightInches!.toStringAsFixed(1)}"  ·  ${record.heightCm!.toStringAsFixed(1)} cm',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  _formatDate(record.timestamp),
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.records});
  final List<JumpRecord> records;

  @override
  Widget build(BuildContext context) {
    final spots = records.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.heightCm!))
        .toList();

    final maxY = (records.map((r) => r.heightCm!).reduce((a, b) => a > b ? a : b) * 1.2).ceilToDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('JUMP HEIGHT OVER TIME', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 2)),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: Colors.white10,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}',
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF00E5FF),
                    barWidth: 2.5,
                    dotData: FlDotData(
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 3,
                        color: const Color(0xFF00E5FF),
                        strokeWidth: 0,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerRight,
            child: Text('cm', style: TextStyle(color: Colors.white24, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _JumpTile extends StatelessWidget {
  const _JumpTile({required this.record, required this.isPB});
  final JumpRecord record;
  final bool isPB;

  @override
  Widget build(BuildContext context) {
    final detected = record.result.jumpDetected && record.heightCm != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: isPB
            ? Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      detected
                          ? '${record.heightInches!.toStringAsFixed(1)}"  ·  ${record.heightCm!.toStringAsFixed(1)} cm'
                          : 'No jump detected',
                      style: TextStyle(
                        color: detected ? Colors.white : Colors.white38,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isPB) ...[
                      const SizedBox(width: 8),
                      const Text('🏆', style: TextStyle(fontSize: 13)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(record.timestamp),
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          if (detected)
            Text(
              '${(record.result.confidence * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: _confidenceColor(record.result.confidence),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
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

String _formatDate(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.month}/${dt.day}/${dt.year}';
}
