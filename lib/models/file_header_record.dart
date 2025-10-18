// FileHeaderRecord model - for LIS File Header Record (type 128)

class FileHeaderRecord {
  final int address;
  final int length;
  final int logicalIndex;
  final int physicalIndex;
  final int type; // always 128

  final String fileName; // 10 bytes
  final String serviceName; // 6 bytes
  final String fileNumber; // 3 bytes
  final String serviceSubLevelName; // 6 bytes
  final String versionNumber; // 8 bytes
  final int year; // 2 bytes
  final int month; // 2 bytes
  final int day; // 2 bytes
  final String maxPhysicalRecordLength; // 5 bytes (can convert to int)
  final String fileType; // 2 bytes
  final String previousFileName; // 10 bytes

  const FileHeaderRecord({
    required this.address,
    required this.length,
    required this.logicalIndex,
    required this.physicalIndex,
    this.type = 128,
    this.fileName = '',
    this.serviceName = '',
    this.fileNumber = '',
    this.serviceSubLevelName = '',
    this.versionNumber = '',
    this.year = 0,
    this.month = 0,
    this.day = 0,
    this.maxPhysicalRecordLength = '',
    this.fileType = '',
    this.previousFileName = '',
  });

  @override
  String toString() {
    return 'FileHeaderRecord(address: $address, length: $length, logicalIndex: $logicalIndex, physicalIndex: $physicalIndex, type: $type, fileName: $fileName, serviceName: $serviceName, fileNumber: $fileNumber, serviceSubLevelName: $serviceSubLevelName, versionNumber: $versionNumber, year: $year, month: $month, day: $day, maxPhysicalRecordLength: $maxPhysicalRecordLength, fileType: $fileType, previousFileName: $previousFileName)';
  }
}
