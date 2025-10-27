// WellInfoBlock model - converted from CWellInfoBlk C++ class

import '../constants/lis_constants.dart';

class WellInfoBlock {
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

  WellInfoBlock({
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
      case LisConstants.typeChar:
        return stringValue;
      case LisConstants.typeInt:
        return intValue;
      case LisConstants.typeFloat:
        return floatValue;
      default:
        return null;
    }
  }

  String get valueAsString {
    switch (type) {
      case LisConstants.typeChar:
        return stringValue ?? '';
      case LisConstants.typeInt:
        return intValue?.toString() ?? '';
      case LisConstants.typeFloat:
        return floatValue?.toString() ?? '';
      default:
        return '';
    }
  }

  @override
  String toString() {
    return 'WellInfoBlock(mnemonic: $mnemonic, value: $valueAsString, unit: $unit)';
  }
}
