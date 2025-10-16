// LisRecord model - converted from CLisRecord C++ class

class LisRecord {
  final int type;
  final int addr;
  final int length;
  final String name;
  final int blockNum;
  final int frameNum;
  final double depth;

  LisRecord({
    required this.type,
    required this.addr,
    required this.length,
    required this.name,
    this.blockNum = 0,
    this.frameNum = 0,
    this.depth = -999.25,
  });

  String get typeName {
    switch (type) {
      case 0:
        return 'Data';
      case 34:
        return 'Well Info';
      case 64:
        return 'Data Format Specification';
      case 128:
        return 'File Header Logical Record';
      case 129:
        return 'File Trailer Record';
      case 130:
        return 'Tape Header Record';
      case 131:
        return 'Tape Trailer Record';
      case 132:
        return 'Real Header Record';
      case 133:
        return 'Real Trailer Record';
      case 232:
        return 'Comment';
      default:
        return 'Unknown';
    }
  }

  bool get isDataRecord => type == 0;
  bool get isWellInfoRecord => type == 34;
  bool get isDataFormatSpecRecord => type == 64;

  // Chuyển LisRecord thành mảng bytes (giả định, cần chỉnh lại đúng format thực tế nếu cần)
  List<int> toBytes() {
    final bytes = <int>[];
    bytes.addAll(_int32ToBytesLE(type));
    bytes.addAll(_int32ToBytesLE(addr));
    bytes.addAll(_int32ToBytesLE(length));
    // Nếu có các trường dữ liệu khác, bổ sung vào đây
    return bytes;
  }

  List<int> _int32ToBytesLE(int value) => [
    value & 0xFF,
    (value >> 8) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 24) & 0xFF,
  ];

  @override
  String toString() {
    return 'LisRecord(type: $type, name: $name, addr: $addr, length: $length)';
  }
}
