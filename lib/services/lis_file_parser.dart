// LIS File Parser - converted from CLisFile C++ class

import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import '../models/lis_record.dart';
import '../models/blank_record.dart';
import '../models/datum_spec_block.dart';
import '../models/well_info_block.dart';
import '../models/data_format_spec.dart';
import '../constants/lis_constants.dart';
import 'code_reader.dart';

class LisFileParser {
  int fileType = LisConstants.fileTypeLis;
  String fileName = '';
  bool isFileOpen = false;

  List<BlankRecord> blankRecords = [];
  List<LisRecord> lisRecords = [];
  List<DatumSpecBlock> datumBlocks = [];
  List<WellInfoBlock> consBlocks = [];
  List<WellInfoBlock> outpBlocks = [];
  List<WellInfoBlock> ak73Blocks = [];
  List<WellInfoBlock> cb3Blocks = [];
  List<WellInfoBlock> toolBlocks = [];
  List<WellInfoBlock> chanBlocks = [];

  DataFormatSpec dataFormatSpec = DataFormatSpec();

  // File parsing indices
  int dataFSRIdx = -1;
  int ak73Idx = -1;
  int cb3Idx = -1;
  int consIdx = -1;
  int outpIdx = -1;
  int toolIdx = -1;
  int chanIdx = -1;

  // Depth and data info
  int step = 0;
  double startDepth = 0.0;
  double endDepth = 0.0;
  int startDataRec = -1;
  int endDataRec = -1;
  int depthCurveIdx = -1;
  double currentDepth = 0.0;
  int currentDataRec = -1;

  // Data buffers
  late Uint8List byteData;
  late Float32List fileData;

  RandomAccessFile? file;

  LisFileParser() {
    byteData = Uint8List(150000);
    fileData = Float32List(60000);
    dataFormatSpec.init();
  }

  Future<void> openLisFile(
    String filePath, {
    Function(double)? onProgress,
  }) async {
    try {
      print('Opening LIS file: $filePath');
      await closeLisFile();

      fileName = filePath;
      file = await File(filePath).open();
      print('File opened successfully, size: ${await file!.length()} bytes');

      if (onProgress != null) onProgress(10);

      // Detect file type (LIS or NTI)
      print('Detecting file type...');
      await _detectFileType();
      print(
        'File type detected: ${fileType == LisConstants.fileTypeNti ? "NTI" : "LIS"}',
      );

      if (onProgress != null) onProgress(30);

      if (fileType == LisConstants.fileTypeNti) {
        await _openNTI(onProgress);
      } else {
        await _openLIS(onProgress);
      }

      if (onProgress != null) onProgress(100);
      isFileOpen = true;
      print('File parsing completed successfully');
    } catch (e) {
      print('Error opening LIS file: $e');
      rethrow;
    }
  }

  Future<void> _detectFileType() async {
    if (file == null) return;

    try {
      print('Starting file type detection...');
      await file!.setPosition(0);

      // Read first 20 bytes to understand file structure
      final firstBytes = await file!.read(20);
      print(
        'First 20 bytes: ${firstBytes.map((b) => b.toString().padLeft(3)).join(' ')}',
      );
      print(
        'First 20 bytes (hex): ${firstBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );

      List<BlankRecord> tempBlankRecords = [];
      int readCount = 0;

      while (readCount < 10) {
        // Limit reads to prevent infinite loop
        final currentPos = await file!.position();
        print('Reading at position: $currentPos');

        if (currentPos + 16 >= await file!.length()) {
          print('Reached end of file');
          break;
        }

        await file!.setPosition(currentPos + 4);

        final group2 = await file!.read(4);
        final group3 = await file!.read(4);
        final group4 = await file!.read(4);

        if (group2.length < 4 || group3.length < 4 || group4.length < 4) {
          print('Insufficient data read, breaking');
          break;
        }

        final blankRec = BlankRecord.fromBytes(group2, group3, group4);
        tempBlankRecords.add(blankRec);
        print(
          'Blank record: nextAddr=${blankRec.nextAddr}, nextRecLen=${blankRec.nextRecLen}',
        );

        if (blankRec.nextAddr < 0 || blankRec.nextAddr > await file!.length()) {
          print('Invalid nextAddr, breaking');
          break;
        }

        await file!.setPosition(blankRec.nextRecLen - 4);
        readCount++;
      }

      fileType = LisConstants.fileTypeLis;

      if (tempBlankRecords.length > 2) {
        for (int i = 1; i < tempBlankRecords.length - 1; i++) {
          if (tempBlankRecords[i].addr != tempBlankRecords[i + 1].prevAddr ||
              tempBlankRecords[i].nextAddr != tempBlankRecords[i + 1].addr) {
            fileType = LisConstants.fileTypeNti;
            break;
          }
        }
      } else {
        fileType = LisConstants.fileTypeNti;
      }

      print(
        'File type detection completed: ${fileType == LisConstants.fileTypeNti ? "NTI" : "LIS"}',
      );
    } catch (e) {
      print('Error in file type detection: $e');
      fileType = LisConstants.fileTypeNti; // Default to NTI
    }
  }

  Future<void> _openNTI(Function(double)? onProgress) async {
    if (file == null) return;

    try {
      print('Starting NTI parsing...');
      await file!.setPosition(0);
      int currentPos = 0;
      int fileLength = await file!.length();
      int recordIndex = 0;
      int maxRecords = 1000; // Safety limit

      print('File length: $fileLength bytes');

      // Read first 20 bytes to understand structure
      final firstBytes = await file!.read(20);
      print(
        'First 20 bytes: ${firstBytes.map((b) => b.toString().padLeft(3)).join(' ')}',
      );

      // Check if first 8 bytes are zeros (header/padding)
      bool hasZeroHeader = firstBytes.take(8).every((b) => b == 0);
      if (hasZeroHeader) {
        print('Detected zero header, starting from position 8');
        currentPos = 8; // Skip potential header
      } else {
        print('No zero header detected, starting from position 0');
        currentPos = 0;
      }

      // LIS format uses Blank Record Headers (16 bytes) followed by Data Records
      // Reset position to start
      currentPos = 0;

      while (currentPos < fileLength - 16 && recordIndex < maxRecords) {
        try {
          await file!.setPosition(currentPos);

          if (onProgress != null) {
            double progress = 30 + (currentPos / fileLength) * 60; // 30-90%
            onProgress(progress);
          }

          // Read Blank Record Header (16 bytes)
          final blankHeader = await file!.read(16);
          if (blankHeader.length < 16) {
            print('Insufficient blank header bytes at position $currentPos');
            break;
          }

          // Parse Blank Record Header
          // Bytes 0-3: Record length (little endian)
          int recordLength =
              blankHeader[0] +
              (blankHeader[1] << 8) +
              (blankHeader[2] << 16) +
              (blankHeader[3] << 24);

          // Bytes 8-11: Next record address (little endian)
          int nextAddr =
              blankHeader[8] +
              (blankHeader[9] << 8) +
              (blankHeader[10] << 16) +
              (blankHeader[11] << 24);

          // Bytes 12-13: Next record length (big endian)
          int nextRecLength = (blankHeader[12] << 8) + blankHeader[13];

          print('Record $recordIndex at pos $currentPos:');
          print(
            '  Blank Header: recordLength=$recordLength, nextAddr=$nextAddr, nextRecLength=$nextRecLength',
          );

          // Move to data record (right after 16-byte blank header)
          int dataPos = currentPos + 16;

          // Read data record
          if (nextRecLength > 0 && dataPos + nextRecLength <= fileLength) {
            await file!.setPosition(dataPos);
            final dataBytes = await file!.read(
              min(nextRecLength, 6),
            ); // Read first few bytes for type

            if (dataBytes.length >= 2) {
              int type =
                  dataBytes[0] + (dataBytes[1] << 8); // Type in little endian

              print(
                '  Data Record: type=$type (0x${type.toRadixString(16)}), length=$nextRecLength',
              );

              // Determine record name
              String recordName = _getRecordName(type, dataPos);

              // Store record indices
              _storeRecordIndices(type, recordName, recordIndex);

              final lisRecord = LisRecord(
                type: type,
                addr: dataPos,
                length: nextRecLength,
                name: recordName,
                blockNum: 1,
              );

              lisRecords.add(lisRecord);
            }
          }

          // Move to next record
          if (nextAddr > 0 && nextAddr < fileLength) {
            currentPos = nextAddr;
          } else {
            // If nextAddr is invalid, try sequential reading
            currentPos = dataPos + nextRecLength;
          }

          recordIndex++;
        } catch (e) {
          print('Error processing record $recordIndex: $e');
          // Try to continue from next position
          currentPos += 16; // Skip to next potential blank header
          continue;
        }
      }

      print('Processed $recordIndex records');

      if (onProgress != null) onProgress(90);

      // Set some default values to prevent crashes
      dataFormatSpec.depthRepr = 68;
      dataFormatSpec.frameSpacing = 1.0;
      dataFormatSpec.direction = LisConstants.dirDown;
      dataFormatSpec.dataFrameSize = 100; // Default frame size

      await _findDataRecordRange();

      if (onProgress != null) onProgress(95);

      print('NTI parsing completed');
    } catch (e) {
      print('Error in _openNTI: $e');
      rethrow;
    }
  }

  Future<void> _openLIS(Function(double)? onProgress) async {
    // Implementation for Russian LIS format
    // Similar to _openNTI but with different parsing logic
    throw UnimplementedError('LIS format parsing not yet implemented');
  }

  String _getRecordName(int type, int position) {
    switch (type) {
      case 0x80: // 128
        return 'FILE_HEADER';
      case 0x22: // 34
        return 'WELLSITE_DATA';
      case 0x40: // 64
        return 'Data Format Specification';
      case 0:
        return 'Data';
      case 232:
        return 'Comment';
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
      case 128:
        return 'File Header Logical Record';
      case 34:
        return _readWellInfoName(position);
      default:
        return 'Unknown';
    }
  }

  String _readWellInfoName(int position) {
    // Read well info name from position
    // This is a simplified version - full implementation would read the actual name
    return 'Well Info';
  }

  void _storeRecordIndices(int type, String name, int index) {
    if (type == 64) dataFSRIdx = index;
    if (type == 0 && startDataRec < 0) startDataRec = index;
    if (type == 0) endDataRec = index;

    switch (name) {
      case 'CHAN':
        chanIdx = index;
        break;
      case 'AK73':
        ak73Idx = index;
        break;
      case 'TOOL':
        toolIdx = index;
        break;
      case 'CB3':
        cb3Idx = index;
        break;
      case 'CONS':
        consIdx = index;
        break;
      case 'OUTP':
        outpIdx = index;
        break;
    }
  }

  Future<void> _readDataFormatSpecificationRecord() async {
    if (dataFSRIdx < 0 || file == null) return;

    final record = lisRecords[dataFSRIdx];
    await file!.setPosition(record.addr + 6);

    // Read the data format specification record
    // This is a complex parsing operation that would need full implementation
    // For now, we'll set some default values
    dataFormatSpec.depthRepr = 68;
    dataFormatSpec.frameSpacing = 1.0;
    dataFormatSpec.direction = LisConstants.dirDown;
  }

  Future<void> _calculateStep() async {
    step = (dataFormatSpec.frameSpacing * 1000).round();

    switch (dataFormatSpec.frameSpacingUnit) {
      case LisConstants.depthUnitFeet:
        break;
      case LisConstants.depthUnitCm:
        step = step * 10;
        break;
      case LisConstants.depthUnitM:
        step = step * 1000;
        break;
      case LisConstants.depthUnitMm:
        break;
      case LisConstants.depthUnitHmm:
        step = step ~/ 2;
        break;
      case LisConstants.depthUnitP1in:
        step = (dataFormatSpec.frameSpacing * 2.54 * 0.1 * 0.01 * 1000).round();
        break;
    }
  }

  Future<void> _findDataRecordRange() async {
    startDataRec = _getStartDataRecordIdx();
    endDataRec = _getEndDataRecordIdx();
  }

  int _getStartDataRecordIdx() {
    for (int i = 0; i < lisRecords.length; i++) {
      final record = lisRecords[i];
      if (record.type == 0 && record.length > dataFormatSpec.dataFrameSize) {
        return i;
      }
    }
    return -1;
  }

  int _getEndDataRecordIdx() {
    for (int i = lisRecords.length - 1; i >= 0; i--) {
      final record = lisRecords[i];
      if (record.type == 0 && record.length > dataFormatSpec.dataFrameSize) {
        return i;
      }
    }
    return -1;
  }

  Future<void> _readDepthInfo() async {
    if (startDataRec >= 0) {
      startDepth = await _getStartDepth();
      endDepth = await _getEndDepth();
    }
  }

  Future<double> _getStartDepth() async {
    if (file == null || startDataRec < 0) return 0.0;

    final record = lisRecords[startDataRec];
    int offset = fileType == LisConstants.fileTypeNti ? 6 : 2;
    await file!.setPosition(record.addr + offset);

    final depthBytes = await file!.read(
      CodeReader.getCodeSize(dataFormatSpec.depthRepr),
    );
    double depth = CodeReader.readCode(
      Uint8List.fromList(depthBytes),
      dataFormatSpec.depthRepr,
      depthBytes.length,
    );

    return _convertToMeter(depth, dataFormatSpec.depthUnit);
  }

  Future<double> _getEndDepth() async {
    if (file == null || endDataRec < 0) return 0.0;

    final record = lisRecords[endDataRec];
    int offset = fileType == LisConstants.fileTypeNti ? 6 : 2;
    await file!.setPosition(record.addr + offset);

    final depthBytes = await file!.read(
      CodeReader.getCodeSize(dataFormatSpec.depthRepr),
    );
    double depth = CodeReader.readCode(
      Uint8List.fromList(depthBytes),
      dataFormatSpec.depthRepr,
      depthBytes.length,
    );

    depth = _convertToMeter(depth, dataFormatSpec.depthUnit);

    int frameNum = record.length ~/ dataFormatSpec.dataFrameSize;

    if (dataFormatSpec.direction == LisConstants.dirDown) {
      depth += (frameNum - 1) * (step / 1000.0);
    } else if (dataFormatSpec.direction == LisConstants.dirUp) {
      depth -= (frameNum - 1) * (step / 1000.0);
    }

    return depth;
  }

  double _convertToMeter(double depth, int unit) {
    switch (unit) {
      case LisConstants.depthUnitFeet:
        return depth; // Assuming already in proper unit
      case LisConstants.depthUnitCm:
        return depth / 100.0;
      case LisConstants.depthUnitM:
        return depth;
      case LisConstants.depthUnitMm:
        return depth / 1000.0;
      case LisConstants.depthUnitHmm:
        return depth / 2000.0;
      case LisConstants.depthUnitP1in:
        return depth * 0.00254;
      default:
        return depth;
    }
  }

  Future<void> closeLisFile() async {
    if (isFileOpen && file != null) {
      await file!.close();
      file = null;
    }

    // Clear all data
    blankRecords.clear();
    lisRecords.clear();
    datumBlocks.clear();
    consBlocks.clear();
    outpBlocks.clear();
    ak73Blocks.clear();
    cb3Blocks.clear();
    toolBlocks.clear();
    chanBlocks.clear();

    dataFormatSpec.init();
    isFileOpen = false;
  }

  // Getters for UI
  int get recordCount => lisRecords.length;
  List<LisRecord> get records => List.unmodifiable(lisRecords);
  List<DatumSpecBlock> get curves => List.unmodifiable(datumBlocks);
  String get fileTypeString => fileType == LisConstants.fileTypeNti
      ? 'NTI (Halliburton)'
      : 'LIS (Russian)';

  Map<String, dynamic> get fileInfo => {
    'fileName': fileName.split(Platform.pathSeparator).last,
    'fileType': fileTypeString,
    'recordCount': recordCount,
    'startDepth': startDepth.toStringAsFixed(2),
    'endDepth': endDepth.toStringAsFixed(2),
    'direction': dataFormatSpec.directionName,
    'frameSpacing': dataFormatSpec.frameSpacing.toStringAsFixed(3),
    'depthUnit': dataFormatSpec.depthUnitName,
  };
}
