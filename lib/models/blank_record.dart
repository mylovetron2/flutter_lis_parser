// BlankRecord model - converted from CBlankRecord C++ class

class BlankRecord {
  final int prevAddr;
  final int addr;
  final int nextAddr;
  final int nextRecLen;
  final int num;

  BlankRecord({
    required this.prevAddr,
    required this.addr,
    required this.nextAddr,
    required this.nextRecLen,
    this.num = 0,
  });

  factory BlankRecord.fromBytes(
    List<int> group2,
    List<int> group3,
    List<int> group4,
  ) {
    const int l16x2 = 256;
    const int l16x4 = 65536;
    const int l16x6 = 16777216;

    final prevAddr =
        group2[0] + group2[1] * l16x2 + group2[2] * l16x4 + group2[3] * l16x6;
    final nextAddr =
        group3[0] + group3[1] * l16x2 + group3[2] * l16x4 + group3[3] * l16x6;
    final nextRecLen = group4[1] + group4[0] * l16x2;
    final num = group4[3];

    return BlankRecord(
      prevAddr: prevAddr,
      addr: 0, // Will be set later
      nextAddr: nextAddr,
      nextRecLen: nextRecLen,
      num: num,
    );
  }

  // Chuyển BlankRecord thành mảng bytes (giả định 16 bytes, cần chỉnh lại đúng format thực tế nếu cần)
  List<int> toBytes() {
    final bytes = <int>[];
    bytes.addAll(_int32ToBytesLE(prevAddr));
    bytes.addAll(_int32ToBytesLE(addr));
    bytes.addAll(_int32ToBytesLE(nextAddr));
    bytes.addAll(_int32ToBytesLE(nextRecLen));
    // Nếu có trường num hoặc các trường khác, bổ sung vào đây
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
    return 'BlankRecord(prevAddr: $prevAddr, addr: $addr, nextAddr: $nextAddr, nextRecLen: $nextRecLen, num: $num)';
  }
}
