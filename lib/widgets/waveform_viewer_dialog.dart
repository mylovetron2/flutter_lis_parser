import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/lis_file_parser.dart';

class WaveformViewerDialog extends StatefulWidget {
  final LisFileParser parser;
  final String datumName;
  final int recordIdx;
  final int frameIdx;
  final double depth;

  const WaveformViewerDialog({
    super.key,
    required this.parser,
    required this.datumName,
    required this.recordIdx,
    required this.frameIdx,
    required this.depth,
  });

  @override
  State<WaveformViewerDialog> createState() => _WaveformViewerDialogState();
}

class _WaveformViewerDialogState extends State<WaveformViewerDialog> {
  List<double> waveformData = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadWaveformData();
  }

  Future<void> _loadWaveformData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      final data = await widget.parser.getArrayData(
        widget.datumName,
        widget.recordIdx,
        widget.frameIdx,
      );

      setState(() {
        waveformData = data;
        isLoading = false;
      });

      if (waveformData.isEmpty) {
        setState(() {
          errorMessage = 'No waveform data available';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading waveform: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.show_chart,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Waveform: ${widget.datumName}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Depth: ${widget.depth.toStringAsFixed(3)}m | Record: ${widget.recordIdx} | Frame: ${widget.frameIdx}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(child: _buildContent()),

            // Footer with stats
            if (waveformData.isNotEmpty) _buildStatsFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading waveform data...'),
          ],
        ),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadWaveformData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (waveformData.isEmpty) {
      return const Center(child: Text('No waveform data available'));
    }

    return _buildChart();
  }

  Widget _buildChart() {
    final spots = waveformData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value);
    }).toList();

    final minY = waveformData.reduce((a, b) => a < b ? a : b);
    final maxY = waveformData.reduce((a, b) => a > b ? a : b);
    final range = maxY - minY;
    final padding = range * 0.1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  strokeWidth: 1,
                );
              },
              getDrawingVerticalLine: (value) {
                return FlLine(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  strokeWidth: 1,
                );
              },
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 60,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.bodySmall,
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: (waveformData.length / 10).clamp(
                    1,
                    double.infinity,
                  ),
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toInt().toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: (waveformData.length - 1).toDouble(),
            minY: minY - padding,
            maxY: maxY + padding,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                color: Theme.of(context).colorScheme.primary,
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((LineBarSpot touchedSpot) {
                    return LineTooltipItem(
                      'Index: ${touchedSpot.x.toInt()}\nValue: ${touchedSpot.y.toStringAsFixed(3)}',
                      Theme.of(
                        context,
                      ).textTheme.bodySmall!.copyWith(color: Colors.white),
                    );
                  }).toList();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsFooter() {
    final minValue = waveformData.reduce((a, b) => a < b ? a : b);
    final maxValue = waveformData.reduce((a, b) => a > b ? a : b);
    final avgValue = waveformData.reduce((a, b) => a + b) / waveformData.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Points', waveformData.length.toString()),
            _buildStatItem('Min', minValue.toStringAsFixed(3)),
            _buildStatItem('Max', maxValue.toStringAsFixed(3)),
            _buildStatItem('Avg', avgValue.toStringAsFixed(3)),
            _buildStatItem('Range', (maxValue - minValue).toStringAsFixed(3)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
