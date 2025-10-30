class FrameData {
  final int frameIdx; // Chỉ số frame trong record
  final double depth; // Độ sâu (nếu có)
  final int recordIdx; // Chỉ số record chứa frame này
  final List<dynamic>
  values; // Mỗi giá trị có thể là double hoặc List<double> (array)

  FrameData({
    required this.frameIdx,
    required this.depth,
    required this.recordIdx,
    required this.values,
  });

  factory FrameData.fromMap(Map<String, dynamic> map) {
    return FrameData(
      frameIdx: map['frameIdx'] ?? 0,
      depth: (map['depth'] ?? 0).toDouble(),
      recordIdx: map['recordIdx'] ?? 0,
      values: (map['values'] as List<dynamic>? ?? []).map((e) {
        if (e is num) return e.toDouble();
        if (e is List) return e.map((v) => (v as num).toDouble()).toList();
        return e;
      }).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'frameIdx': frameIdx,
      'depth': depth,
      'recordIdx': recordIdx,
      'values': values,
    };
  }
}
