// Chart Screen with TIME and DEPTH tracks using Syncfusion

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../models/chart_data.dart' as chart_data;
import '../services/lis_file_parser.dart';
import '../constants/lis_constants.dart';

class ChartScreen extends StatefulWidget {
  final LisFileParser parser;

  const ChartScreen({super.key, required this.parser});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  late chart_data.ChartConfig chartConfig;
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeChart();
  }

  Future<void> _initializeChart() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      await _loadChartData();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading chart data: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _loadChartData() async {
    // Get all curves from datum blocks
    final curves = widget.parser.curves;

    // Initialize time and depth tracks
    final timeTrackCurves = <chart_data.CurveConfig>[];
    final depthTrackCurves = <chart_data.CurveConfig>[];

    // Process first few data records to get sample data
    final maxRecords = 50; // Limit for performance
    final startRecord = widget.parser.startDataRec;
    final endRecord = widget.parser.endDataRec;

    if (startRecord < 0 || endRecord < 0) {
      throw Exception('No data records found');
    }

    for (int curveIndex = 0; curveIndex < curves.length; curveIndex++) {
      final datum = curves[curveIndex];

      // Skip DEPT and array datums for now
      if (datum.mnemonic == 'DEPT' || datum.size > 4) {
        continue;
      }

      final dataPoints = <chart_data.LisChartPoint>[];
      double minValue = double.infinity;
      double maxValue = double.negativeInfinity;

      // Load data for this curve
      for (
        int recordIdx = startRecord;
        recordIdx <= endRecord && recordIdx < startRecord + maxRecords;
        recordIdx++
      ) {
        final allData = await widget.parser.getAllData(recordIdx);
        if (allData.isEmpty) continue;

        final frameNum = widget.parser.getFrameNum(recordIdx);

        // Get starting depth for this record (same logic as table)
        final startingDepth = widget.parser.currentDepth;

        // Calculate how much data each frame contains (same logic as table)
        int singleValuesPerFrame = 0;
        int arrayElementsPerFrame = 0;

        for (var datum in curves) {
          if (widget.parser.entryBlock.nDepthRecordingMode == 0 &&
              datum.mnemonic == 'DEPT') {
            continue; // Skip DEPT in depth-per-frame mode
          }

          if (datum.size <= 4) {
            singleValuesPerFrame += 1;
          } else {
            arrayElementsPerFrame += datum.dataItemNum;
          }
        }

        int totalValuesPerFrame = singleValuesPerFrame + arrayElementsPerFrame;

        // Extract values for each frame
        for (int frame = 0; frame < frameNum; frame++) {
          // Calculate frame depth (same logic as table)
          double frameDepth = startingDepth;
          if (widget.parser.entryBlock.nDirection == LisConstants.dirDown) {
            frameDepth += frame * (widget.parser.step / 1000.0);
          } else {
            frameDepth -= frame * (widget.parser.step / 1000.0);
          }

          // Calculate data index for this curve in this frame (same logic as table)
          int frameDataStartIndex = frame * totalValuesPerFrame;
          int currentIndex = frameDataStartIndex;

          // Find the index for this specific curve
          for (int i = 0; i < curveIndex; i++) {
            final otherDatum = curves[i];
            if (widget.parser.entryBlock.nDepthRecordingMode == 0 &&
                otherDatum.mnemonic == 'DEPT') {
              continue; // Skip DEPT in depth-per-frame mode
            }

            if (otherDatum.size <= 4) {
              currentIndex += 1; // Single value
            } else {
              currentIndex += otherDatum.dataItemNum; // Array values
            }
          }

          if (currentIndex < allData.length) {
            final value = allData[currentIndex];

            if (!value.isNaN && value.isFinite) {
              dataPoints.add(
                chart_data.LisChartPoint(
                  x: frameDepth, // Use real depth as x for depth track
                  y: value,
                  depth: frameDepth,
                  time: frame.toDouble(), // Use frame index as time
                ),
              );

              if (value < minValue) minValue = value;
              if (value > maxValue) maxValue = value;
            }
          }
        }
      }

      if (dataPoints.isNotEmpty) {
        // Add to both tracks with different x-axis mapping
        final timeTrackConfig = chart_data.CurveConfig(
          name: datum.mnemonic,
          color: chart_data.CurveColors.getColorForIndex(curveIndex),
          lineWidth: 1.5,
          minValue: minValue,
          maxValue: maxValue,
          dataPoints: dataPoints
              .map(
                (point) => chart_data.LisChartPoint(
                  x: point.time!, // Use frame index as x for time track
                  y: point.y,
                  depth: point.depth,
                  time: point.time,
                ),
              )
              .toList(),
          isVisible: true,
        );

        final depthTrackConfig = chart_data.CurveConfig(
          name: datum.mnemonic,
          color: chart_data.CurveColors.getColorForIndex(curveIndex),
          lineWidth: 1.5,
          minValue: minValue,
          maxValue: maxValue,
          dataPoints: dataPoints, // Use depth as x for depth track
          isVisible: true,
        );

        timeTrackCurves.add(timeTrackConfig);
        depthTrackCurves.add(depthTrackConfig);
      }
    }

    // Create chart configuration
    chartConfig = chart_data.ChartConfig(
      timeTrack: chart_data.TrackConfig(
        name: 'Frame Index Track',
        axisLabel: 'Frame Index',
        curves: timeTrackCurves,
        autoScale: true,
      ),
      depthTrack: chart_data.TrackConfig(
        name: 'Depth Track',
        axisLabel: 'Depth (meters)',
        curves: depthTrackCurves,
        autoScale: true,
      ),
    );

    // Auto-scale tracks
    _autoScaleTracks();
  }

  void _autoScaleTracks() {
    // Auto-scale frame index track
    if (chartConfig.timeTrack.autoScale &&
        chartConfig.timeTrack.curves.isNotEmpty) {
      double minFrame = double.infinity;
      double maxFrame = double.negativeInfinity;

      for (final curve in chartConfig.timeTrack.curves) {
        if (curve.isVisible && curve.dataPoints.isNotEmpty) {
          for (final point in curve.dataPoints) {
            if (point.x < minFrame) minFrame = point.x;
            if (point.x > maxFrame) maxFrame = point.x;
          }
        }
      }

      if (minFrame.isFinite && maxFrame.isFinite) {
        chartConfig.timeTrack.minValue = minFrame;
        chartConfig.timeTrack.maxValue = maxFrame;
      }
    }

    // Auto-scale depth track
    if (chartConfig.depthTrack.autoScale &&
        chartConfig.depthTrack.curves.isNotEmpty) {
      double minDepth = double.infinity;
      double maxDepth = double.negativeInfinity;

      for (final curve in chartConfig.depthTrack.curves) {
        if (curve.isVisible && curve.dataPoints.isNotEmpty) {
          for (final point in curve.dataPoints) {
            if (point.x < minDepth)
              minDepth = point.x; // x is depth for depth track
            if (point.x > maxDepth) maxDepth = point.x;
          }
        }
      }

      if (minDepth.isFinite && maxDepth.isFinite) {
        chartConfig.depthTrack.minValue = minDepth;
        chartConfig.depthTrack.maxValue = maxDepth;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LIS Data Charts'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: 'Chart Settings',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeChart,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading chart data...'),
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
              onPressed: _initializeChart,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Top sidebar for curve selection
        Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
            ),
          ),
          child: _buildCurveSelector(),
        ),

        // Main chart area
        Expanded(
          child: Row(
            children: [
              // Frame Index Track (Left)
              Expanded(
                flex: 1,
                child: _buildTrackChart(chartConfig.timeTrack, true),
              ),

              // Divider
              Container(
                width: 1,
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),

              // Depth Track (Right)
              Expanded(
                flex: 1,
                child: _buildTrackChart(chartConfig.depthTrack, false),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurveSelector() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Text('', style: Theme.of(context).textTheme.titleMedium),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _buildTrackCurveList(
                  'Frame Index Track',
                  chartConfig.timeTrack,
                ),
              ),
              const VerticalDivider(),
              Expanded(
                child: _buildTrackCurveList(
                  'Depth Track',
                  chartConfig.depthTrack,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrackCurveList(String trackName, chart_data.TrackConfig track) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            trackName,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView(
            children: track.curves
                .map((curve) => _buildCurveItem(curve, track))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCurveItem(
    chart_data.CurveConfig curve,
    chart_data.TrackConfig track,
  ) {
    return ListTile(
      dense: true,
      leading: Checkbox(
        value: curve.isVisible,
        onChanged: (value) {
          setState(() {
            curve.isVisible = value ?? false;
          });
        },
      ),
      title: Text(curve.name),
      subtitle: Text(
        'Min: ${curve.minValue.toStringAsFixed(2)}, Max: ${curve.maxValue.toStringAsFixed(2)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: curve.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.settings, size: 16),
            onPressed: () => _showCurveSettings(curve, track),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackChart(chart_data.TrackConfig track, bool isTimeTrack) {
    final visibleCurves = track.curves
        .where((curve) => curve.isVisible)
        .toList();

    if (visibleCurves.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'No curves selected for ${track.name}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              track.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: SfCartesianChart(
              primaryXAxis: NumericAxis(
                title: AxisTitle(text: 'Value'),
                enableAutoIntervalOnZooming: true,
              ),
              primaryYAxis: NumericAxis(
                title: AxisTitle(text: track.axisLabel),
                enableAutoIntervalOnZooming: true,
                isInversed:
                    true, // Đảo ngược trục Y để giá trị tăng từ trên xuống
              ),
              zoomPanBehavior: ZoomPanBehavior(
                enablePinching: true,
                enablePanning: true,
                enableDoubleTapZooming: true,
                enableMouseWheelZooming: true,
              ),
              legend: Legend(
                isVisible: true,
                position: LegendPosition.bottom,
                overflowMode: LegendItemOverflowMode.wrap,
              ),
              tooltipBehavior: TooltipBehavior(enable: true),
              series: visibleCurves
                  .map((curve) => _createLineSeries(curve, isTimeTrack))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  LineSeries<chart_data.LisChartPoint, double> _createLineSeries(
    chart_data.CurveConfig curve,
    bool isTimeTrack,
  ) {
    return LineSeries<chart_data.LisChartPoint, double>(
      name: curve.name,
      dataSource: curve.dataPoints,
      xValueMapper: (chart_data.LisChartPoint point, _) =>
          point.y, // Values as X
      yValueMapper: (chart_data.LisChartPoint point, _) => isTimeTrack
          ? point.x
          : (point.depth ?? 0), // Frame Index or Depth as Y
      color: curve.color,
      width: curve.lineWidth,
      enableTooltip: true,
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chart Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Auto Scale Frame Index Track'),
              value: chartConfig.timeTrack.autoScale,
              onChanged: (value) {
                setState(() {
                  chartConfig.timeTrack.autoScale = value;
                  if (value) _autoScaleTracks();
                });
              },
            ),
            SwitchListTile(
              title: const Text('Auto Scale Depth Track'),
              value: chartConfig.depthTrack.autoScale,
              onChanged: (value) {
                setState(() {
                  chartConfig.depthTrack.autoScale = value;
                  if (value) _autoScaleTracks();
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showCurveSettings(
    chart_data.CurveConfig curve,
    chart_data.TrackConfig track,
  ) {
    showDialog(
      context: context,
      builder: (context) => _CurveSettingsDialog(
        curve: curve,
        track: track,
        onChanged: () => setState(() {}),
      ),
    );
  }
}

class _CurveSettingsDialog extends StatefulWidget {
  final chart_data.CurveConfig curve;
  final chart_data.TrackConfig track;
  final VoidCallback onChanged;

  const _CurveSettingsDialog({
    required this.curve,
    required this.track,
    required this.onChanged,
  });

  @override
  State<_CurveSettingsDialog> createState() => _CurveSettingsDialogState();
}

class _CurveSettingsDialogState extends State<_CurveSettingsDialog> {
  late TextEditingController minController;
  late TextEditingController maxController;
  late double lineWidth;
  late Color selectedColor;

  @override
  void initState() {
    super.initState();
    minController = TextEditingController(
      text: widget.curve.minValue.toStringAsFixed(2),
    );
    maxController = TextEditingController(
      text: widget.curve.maxValue.toStringAsFixed(2),
    );
    lineWidth = widget.curve.lineWidth;
    selectedColor = widget.curve.color;
  }

  @override
  void dispose() {
    minController.dispose();
    maxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Settings for ${widget.curve.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Color selection
            const Text('Color:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chart_data.CurveColors.predefinedColors.map((color) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedColor = color;
                    });
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: selectedColor == color
                          ? Border.all(color: Colors.black, width: 2)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Line width
            Text('Line Width: ${lineWidth.toStringAsFixed(1)}'),
            Slider(
              value: lineWidth,
              min: 0.5,
              max: 5.0,
              divisions: 18,
              onChanged: (value) {
                setState(() {
                  lineWidth = value;
                });
              },
            ),

            const SizedBox(height: 16),

            // Min/Max values
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: minController,
                    decoration: const InputDecoration(
                      labelText: 'Min Value',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: maxController,
                    decoration: const InputDecoration(
                      labelText: 'Max Value',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            // Apply changes
            widget.curve.color = selectedColor;
            widget.curve.lineWidth = lineWidth;

            final minValue = double.tryParse(minController.text);
            final maxValue = double.tryParse(maxController.text);

            if (minValue != null) widget.curve.minValue = minValue;
            if (maxValue != null) widget.curve.maxValue = maxValue;

            widget.onChanged();
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
