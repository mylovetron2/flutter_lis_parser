// Chart data models for Syncfusion charts

import 'package:flutter/material.dart';

/// Point data for chart series
class LisChartPoint {
  final double x;
  final double y;
  final double? depth;
  final double? time;

  LisChartPoint({required this.x, required this.y, this.depth, this.time});
}

/// Configuration for individual curve display
class CurveConfig {
  final String name;
  bool isVisible;
  Color color;
  double lineWidth;
  double minValue;
  double maxValue;
  List<LisChartPoint> dataPoints;

  CurveConfig({
    required this.name,
    this.isVisible = true,
    this.color = Colors.blue,
    this.lineWidth = 2.0,
    this.minValue = 0.0,
    this.maxValue = 100.0,
    this.dataPoints = const [],
  });

  CurveConfig copyWith({
    String? name,
    bool? isVisible,
    Color? color,
    double? lineWidth,
    double? minValue,
    double? maxValue,
    List<LisChartPoint>? dataPoints,
  }) {
    return CurveConfig(
      name: name ?? this.name,
      isVisible: isVisible ?? this.isVisible,
      color: color ?? this.color,
      lineWidth: lineWidth ?? this.lineWidth,
      minValue: minValue ?? this.minValue,
      maxValue: maxValue ?? this.maxValue,
      dataPoints: dataPoints ?? this.dataPoints,
    );
  }
}

/// Track configuration for TIME or DEPTH axis
class TrackConfig {
  final String name;
  final String axisLabel;
  double minValue;
  double maxValue;
  bool autoScale;
  List<CurveConfig> curves;

  TrackConfig({
    required this.name,
    required this.axisLabel,
    this.minValue = 0.0,
    this.maxValue = 100.0,
    this.autoScale = true,
    this.curves = const [],
  });

  TrackConfig copyWith({
    String? name,
    String? axisLabel,
    double? minValue,
    double? maxValue,
    bool? autoScale,
    List<CurveConfig>? curves,
  }) {
    return TrackConfig(
      name: name ?? this.name,
      axisLabel: axisLabel ?? this.axisLabel,
      minValue: minValue ?? this.minValue,
      maxValue: maxValue ?? this.maxValue,
      autoScale: autoScale ?? this.autoScale,
      curves: curves ?? this.curves,
    );
  }
}

/// Main chart configuration
class ChartConfig {
  final TrackConfig timeTrack;
  final TrackConfig depthTrack;
  double zoomLevel;
  double panOffset;

  ChartConfig({
    required this.timeTrack,
    required this.depthTrack,
    this.zoomLevel = 1.0,
    this.panOffset = 0.0,
  });

  ChartConfig copyWith({
    TrackConfig? timeTrack,
    TrackConfig? depthTrack,
    double? zoomLevel,
    double? panOffset,
  }) {
    return ChartConfig(
      timeTrack: timeTrack ?? this.timeTrack,
      depthTrack: depthTrack ?? this.depthTrack,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      panOffset: panOffset ?? this.panOffset,
    );
  }
}

/// Available curve colors
class CurveColors {
  static const List<Color> predefinedColors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.cyan,
    Colors.lime,
    Colors.amber,
    Colors.deepOrange,
    Colors.lightBlue,
    Colors.lightGreen,
    Colors.yellow,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];

  static Color getColorForIndex(int index) {
    return predefinedColors[index % predefinedColors.length];
  }
}
