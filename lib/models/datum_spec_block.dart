// DatumSpecBlock model - converted from CDatumSpecBlk C++ class

class DatumSpecBlock {
  factory DatumSpecBlock.empty(String mnemonic) {
    return DatumSpecBlock(
      mnemonic: mnemonic,
      serviceId: '',
      serviceOrderNb: '',
      units: '',
      fileNb: 0,
      size: 4,
      nbSample: 1,
      reprCode: 68,
      offset: 0,
      dataItemNum: 1,
      realSize: 1,
    );
  }
  final String mnemonic;
  final String serviceId;
  final String serviceOrderNb;
  final String units;
  final int fileNb;
  final int size;
  final int nbSample;
  final int reprCode;
  final int offset;
  final int dataItemNum;
  final int realSize;

  DatumSpecBlock({
    required this.mnemonic,
    required this.serviceId,
    required this.serviceOrderNb,
    required this.units,
    required this.fileNb,
    required this.size,
    required this.nbSample,
    required this.reprCode,
    required this.offset,
    required this.dataItemNum,
    required this.realSize,
  });

  factory DatumSpecBlock.fromBytes(List<int> data, int startIndex) {
    int index = startIndex;

    // Read mnemonic (4 bytes)
    final mnemonicBytes = data.sublist(index, index + 4);
    index += 4;
    String mnemonic = String.fromCharCodes(mnemonicBytes).trim();

    // Read service ID (6 bytes)
    final serviceIdBytes = data.sublist(index, index + 6);
    index += 6;
    String serviceId = String.fromCharCodes(serviceIdBytes).trim();

    // Read service order number (8 bytes)
    final serviceOrderNbBytes = data.sublist(index, index + 8);
    index += 8;
    String serviceOrderNb = String.fromCharCodes(serviceOrderNbBytes).trim();

    // Read units (4 bytes)
    final unitsBytes = data.sublist(index, index + 4);
    index += 4;
    String units = String.fromCharCodes(unitsBytes).trim();

    // Skip API codes (4 bytes)
    index += 4;

    // Read file number (2 bytes)
    final fileNb = data[index] + data[index + 1] * 256;
    index += 2;

    // Read size (2 bytes)
    final size = data[index] + data[index + 1] * 256;
    index += 2;

    // Skip 3 bytes
    index += 3;

    // Read number of samples (1 byte)
    final nbSample = data[index];
    index += 1;

    // Read representation code (1 byte)
    final reprCode = data[index];
    index += 1;

    return DatumSpecBlock(
      mnemonic: mnemonic,
      serviceId: serviceId,
      serviceOrderNb: serviceOrderNb,
      units: units,
      fileNb: fileNb,
      size: size,
      nbSample: nbSample,
      reprCode: reprCode,
      offset: 0, // Will be calculated
      dataItemNum: 0, // Will be calculated
      realSize: 0, // Will be calculated
    );
  }

  @override
  String toString() {
    return 'DatumSpecBlock(mnemonic: $mnemonic, units: $units, size: $size, reprCode: $reprCode)';
  }
}
