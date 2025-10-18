// WellDataBlock model - tương tự WellInfoBlock

class WellDataBlock {
  final int no;
  final int reprCode;
  final int size;
  final int category;
  final String mnemonic;
  final String unit;
  final int type;
  final String? stringValue;
  final int? intValue;
  final double? floatValue;

  WellDataBlock({
    required this.no,
    required this.reprCode,
    required this.size,
    required this.category,
    required this.mnemonic,
    required this.unit,
    required this.type,
    this.stringValue,
    this.intValue,
    this.floatValue,
  });

  dynamic get value {
    switch (type) {
      case 0:
        return stringValue;
      case 1:
        return intValue;
      case 2:
        return floatValue;
      default:
        return null;
    }
  }

  String get valueAsString {
    switch (type) {
      case 0:
        return stringValue ?? '';
      case 1:
        return intValue?.toString() ?? '';
      case 2:
        return floatValue?.toString() ?? '';
      default:
        return '';
    }
  }

  @override
  String toString() {
    return 'WellDataBlock(mnemonic: $mnemonic, value: $valueAsString, unit: $unit)';
  }
}
