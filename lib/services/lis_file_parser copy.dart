import '../models/entry_block.dart';
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
import '../models/file_header_record.dart';
import 'code_reader.dart';

class LisFileParser {
  /// Mã hóa EntryBlock và lưu ra file LIS mới
  Future<bool> saveEntryBlockToNewFile(String newFilePath) async {
    try {
      final entryBlockBytes = encodeEntryBlock(entryBlock);
      print('DEBUG: entryBlockBytes length: ${entryBlockBytes.length}');
      print('DEBUG: entryBlockBytes hex trước lưu: ${entryBlockBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      // Đọc toàn bộ file gốc vào buffer
      final originalFile = File(fileName);
      final originalBytes = await originalFile.readAsBytes();
      // Tính offset thực tế
      int fileOffset = lisRecords[dataFSRIdx].addr + entryBlockOffset;
      print('DEBUG: fileOffset calculation:');
      print('  lisRecords[dataFSRIdx].addr = ${lisRecords[dataFSRIdx].addr}');
      print('  entryBlockOffset = $entryBlockOffset');
      print('  calculated fileOffset = $fileOffset');


      fileOffset = lisRecords[dataFSRIdx].addr + 2;
      // Ghi ra file mới
      final newBytes = Uint8List.fromList(originalBytes);
      for (int i = 0; i < entryBlockBytes.length; i++) {
        if (fileOffset + i < newBytes.length) {
          newBytes[fileOffset + i] = entryBlockBytes[i];
        }
      }
      await File(newFilePath).writeAsBytes(newBytes);
      return true;
    } catch (e) {
      print('Error saving EntryBlock to new file: $e');
      return false;
    }
  }
  /// Ghi đè EntryBlock đã mã hóa vào file LIS
  Future<bool> saveEntryBlock() async {
    if (file == null) return false;
    final entryBlockBytes = encodeEntryBlock(entryBlock);
    // Tính offset thực tế trong file
    int fileOffset = lisRecords[dataFSRIdx].addr + entryBlockOffset;
    await file!.setPosition(fileOffset);
    await file!.writeFrom(entryBlockBytes);
    await file!.flush();
    return true;
  }
  /// Mã hóa EntryBlock thành Uint8List để ghi lại vào file LIS
  Uint8List encodeEntryBlock(EntryBlock entryBlock) {
    final bytes = <int>[];
    // Ví dụ: mã hóa từng trường, cần đúng thứ tự và cấu trúc
    // entryType, size, reprCode, entryData
    // Trường 1: nDataRecordType
    bytes.add(1); // entryType
    bytes.add(1); // size
    bytes.add(66); // reprCode (ví dụ: 66 = 1 byte int)
    bytes.add(entryBlock.nDataRecordType & 0xFF);

    // Trường 2: nDatumSpecBlockType
    bytes.add(2);
    bytes.add(1);
    bytes.add(66);
    bytes.add(entryBlock.nDatumSpecBlockType & 0xFF);

  // Trường 3: nDataFrameSize (2 byte, reprCode 79, big endian)
  bytes.add(3);
  bytes.add(2);
  bytes.add(79); // 2 byte int
  bytes.add((entryBlock.nDataFrameSize >> 8) & 0xFF); // byte cao
  bytes.add(entryBlock.nDataFrameSize & 0xFF);        // byte thấp

    // Trường 4: nDirection
    bytes.add(4);
    bytes.add(1);
    bytes.add(66);
    bytes.add(entryBlock.nDirection & 0xFF);

    // Trường 5: nOpticalDepthUnit
    bytes.add(5);
    bytes.add(1);
    bytes.add(66);
    bytes.add(entryBlock.nOpticalDepthUnit & 0xFF);

    // Trường 6: fDataRefPoint (4 byte float, reprCode 68)
    bytes.add(6);
    bytes.add(4);
    bytes.add(68);
    final refPointBytes = ByteData(4)..setFloat32(0, entryBlock.fDataRefPoint, Endian.little);
    bytes.addAll(refPointBytes.buffer.asUint8List());

    // Trường 7: strDataRefPointUnit (4 byte ASCII, reprCode 65)
    bytes.add(7);
    bytes.add(4);
    bytes.add(65);
    final unitBytes = entryBlock.strDataRefPointUnit.padRight(4).codeUnits;
    bytes.addAll(unitBytes.take(4));

    // Trường 8: fFrameSpacing (4 byte float, reprCode 68)
    bytes.add(8);
    bytes.add(4);
    bytes.add(68);
    final spacingBytes = _encodeRussianLisFloat(entryBlock.fFrameSpacing);
    bytes.addAll(spacingBytes);

    // Trường 9: strFrameSpacingUnit (4 byte ASCII, reprCode 65)
    bytes.add(9);
    bytes.add(4);
    bytes.add(65);
    final spacingUnitBytes = entryBlock.strFrameSpacingUnit.padRight(4).codeUnits;
    bytes.addAll(spacingUnitBytes.take(4));

    // Trường 11: nMaxFramesPerRecord (1 byte int, reprCode 66)
    bytes.add(11);
    bytes.add(2);
    bytes.add(79);
    //bytes.add(entryBlock.nMaxFramesPerRecord & 0xFF);
    final absentBytes = ByteData(2);
    absentBytes.setUint8(0, 0x00);
    absentBytes.setUint8(1, 0x00);
    bytes.addAll(absentBytes.buffer.asUint8List());

    //Trường 12: fAbsentValue (4 byte float, reprCode 68)
    bytes.add(12);
    bytes.add(4);
    bytes.add(68);
    // final absentBytes = _encodeRussianLisFloat(entryBlock.fAbsentValue);
    // bytes.addAll(absentBytes);

    final absentBytes2 = ByteData(4);
    absentBytes2.setUint8(0, 0xb7);
    absentBytes2.setUint8(1, 0xc0);
    absentBytes2.setUint8(2, 0x00);
    absentBytes2.setUint8(3, 0x00);
    bytes.addAll(absentBytes2.buffer.asUint8List());

    // Trường 13: nDepthRecordingMode (1 byte int, reprCode 66)
    bytes.add(13);
    bytes.add(1);
    bytes.add(66);
    bytes.add(entryBlock.nDepthRecordingMode & 0xFF);

    // Trường 14: strDepthUnit (4 byte ASCII, reprCode 65)
    bytes.add(14);
    bytes.add(4);
    bytes.add(65);
    final depthUnitBytes = entryBlock.strDepthUnit.padRight(4).codeUnits;
    bytes.addAll(depthUnitBytes.take(4));

    // Trường 15: nDepthRepr (1 byte int, reprCode 66)
    bytes.add(15);
    bytes.add(1);
    bytes.add(66);
    bytes.add(entryBlock.nDepthRepr & 0xFF);

    // Trường 16: nDatumSpecBlockSubType (1 byte int, reprCode 66)
    bytes.add(16);
    bytes.add(1);
    bytes.add(66);
    bytes.add(entryBlock.nDatumSpecBlockSubType & 0xFF);

    // Kết thúc EntryBlock
    bytes.add(0); // entryType = 0 (end)
    return Uint8List.fromList(bytes);
  }

  /// Offset (vị trí) của EntryBlock trong file, dùng để edit/save lại
  int entryBlockOffset = -1;
  // Danh sách các File Header Record đã parse
  final List<FileHeaderRecord> fileHeaderRecords = [];

  /// Returns the mnemonic (column name) of the first datum in the LIS file, or empty string if not available
  String get firstColumnName =>
      datumBlocks.isNotEmpty ? datumBlocks.first.mnemonic : '';
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
  EntryBlock entryBlock = EntryBlock();

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

  // Pending changes storage

  LisFileParser() {
    // LisFileParser constructor initialized
    byteData = Uint8List(200000); // Increase buffer size for larger records
    fileData = Float32List(60000);
    dataFormatSpec.init();
    entryBlock = EntryBlock();
  }

  // Track deleted rows as pending changes
  void markRowDeleted(int rowIndex) {
    final changeKey = 'delete_row_$rowIndex';
    if (!_pendingChanges.containsKey(changeKey)) {
      _pendingChanges[changeKey] = {'rowIndex': rowIndex, 'type': 'delete'};
      // Marked row $rowIndex as deleted (pending change)
    }
  }

  Future<void> openLisFile(
    String filePath, {
    Function(double)? onProgress,
  }) async {
    try {
      // Opening LIS file: $filePath
      await closeLisFile();

      fileName = filePath;
      file = await File(filePath).open();
      // File opened successfully

      if (onProgress != null) onProgress(10);

      // Detect file type (LIS or NTI)
      // Detecting file type...
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

      // After parsing records and datum blocks, compute depth-related values
      // Set step based on frame spacing (convert to milliseconds-based integer like original C++ lStep)
      // Keep step as an integer representing frame spacing in milliseconds (consistent with original logic)
      try {
        final spacing = dataFormatSpec.frameSpacing; // in original units
        // Convert to milliseconds similar to C++ logic: multiply by 1000
        step = (spacing * 1000).round();
      } catch (_) {
        step = 0;
      }

      // Compute startDepth and endDepth using existing helpers (they handle unit conversion)
      try {
        startDepth = await _getStartDepth();
      } catch (_) {
        startDepth = 0.0;
      }
      try {
        endDepth = await _getEndDepth();
      } catch (_) {
        endDepth = startDepth;
      }

      if (onProgress != null) onProgress(100);
      isFileOpen = true;
      // File parsing completed successfully
    } catch (e) {
      // Error opening LIS file: $e
      rethrow;
    }
  }

  Future<void> _detectFileType() async {
    if (file == null) return;

    try {
      // Starting file type detection...
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

      // Follow C++ logic exactly - start at position 0 and read blank records
      await file!.setPosition(0);

      // Start with addr from position 0 (as per C++: long lAddr=0)
      int addr = 0;
      int maxIterations = 100; // Safety limit
      int iteration = 0;

      while (iteration < maxIterations) {
        // Reading blank record at position: $addr

        if (addr + 16 >= await file!.length()) {
          // Reached end of file
          break;
        }

        // Move to current addr position
        await file!.setPosition(addr);

        // Skip first 4 bytes (as per C++: hFile.Seek(4,SEEK_CUR))
        await file!.setPosition(addr + 4);

        // Read group2, group3, group4 (as per C++)
        final group2 = await file!.read(4);
        final group3 = await file!.read(4);
        final group4 = await file!.read(4);

        if (group2.length < 4 || group3.length < 4 || group4.length < 4) {
          // Insufficient data read, breaking
          break;
        }

        final blankRec = BlankRecord.fromBytes(group2, group3, group4);
        // Create a new BlankRecord with the correct addr (current addr)
        final correctedBlankRec = BlankRecord(
          prevAddr: blankRec.prevAddr,
          addr: addr, // Current position
          nextAddr: blankRec.nextAddr,
          nextRecLen: blankRec.nextRecLen,
          num: blankRec.num,
        );
        tempBlankRecords.add(correctedBlankRec);

        // Blank record ${iteration} at addr=${addr}

        if (correctedBlankRec.nextAddr < 0 ||
            correctedBlankRec.nextAddr >= await file!.length()) {
          // Invalid nextAddr, breaking
          break;
        }

        // Update addr to nextAddr (as per C++ logic: lAddr=lNextAddr)
        addr = correctedBlankRec.nextAddr;

        // Move to next record: seek to nextRecLen - 4 (as per C++ logic)
        await file!.setPosition(correctedBlankRec.nextRecLen - 4);

        // Check if we reached near end of file (as per C++)
        if (await file!.position() >= await file!.length() - 16) {
          // Near end of file, breaking
          break;
        }

        iteration++;
      }

      // File type detection based on blank record address consistency
      // Default to LIS (Russian format) first - matching C++ logic
      fileType = LisConstants.fileTypeLis;
      // Read ${tempBlankRecords.length} blank records for file type detection

      // Match C++ logic exactly: need > 5 blank records for reliable LIS detection
      if (tempBlankRecords.length > 5) {
        bool isConsistent = true;
        for (int i = 1; i < tempBlankRecords.length - 1; i++) {
          // Check address consistency between consecutive blank records
          // In Russian LIS: blankArr[i]->lAddr == blankArr[i+1]->lPrevAddr
          // and blankArr[i]->lNextAddr == blankArr[i+1]->lAddr
          if (tempBlankRecords[i].addr != tempBlankRecords[i + 1].prevAddr) {
            // Address inconsistency at record $i
            isConsistent = false;
            break;
          }
          if (tempBlankRecords[i].nextAddr != tempBlankRecords[i + 1].addr) {
            // NextAddr inconsistency at record $i
            isConsistent = false;
            break;
          }
        }

        if (!isConsistent) {
          fileType = LisConstants.fileTypeNti; // Halliburton format
          // File type detected as NTI due to blank record inconsistency
        } else {
          // File type detected as LIS (Russian) - blank records are consistent
        }
      } else {
        fileType = LisConstants.fileTypeNti; // Less than 5 records = NTI
        // File type detected as NTI - insufficient blank records
      }

      // File type detection completed
    } catch (e) {
      // Error in file type detection: $e
      fileType = LisConstants.fileTypeNti; // Default to NTI on error
    }
  }

  Future<void> _openNTI(Function(double)? onProgress) async {
    if (file == null) return;

    try {
      // Starting NTI parsing
      await file!.setPosition(0);
      int currentPos = 0;
      int fileLength = await file!.length();
      int recordIndex = 0;
      int maxRecords = 1000; // Safety limit

      // File length: $fileLength bytes

      // Read first 20 bytes to understand structure
      final firstBytes = await file!.read(20);
      // First 20 bytes read

      // Check if first 8 bytes are zeros (header/padding)
      bool hasZeroHeader = firstBytes.take(8).every((b) => b == 0);
      if (hasZeroHeader) {
        // Detected zero header, starting from position 8
        currentPos = 8; // Skip potential header
      } else {
        // No zero header detected, starting from position 0
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
            // Insufficient blank header bytes
            break;
          }

          // Parse Blank Record Header
          // Bytes 0-3: Record length (little endian) - value not used here

          // Bytes 8-11: Next record address (little endian)
          int nextAddr =
              blankHeader[8] +
              (blankHeader[9] << 8) +
              (blankHeader[10] << 16) +
              (blankHeader[11] << 24);

          // Bytes 12-13: Next record length (big endian)
          int nextRecLength = (blankHeader[12] << 8) + blankHeader[13];

          // Record $recordIndex at pos $currentPos

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

              // Data Record: type=$type, length=$nextRecLength

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

              // Nếu là File Header Record (type 128) thì parse và lưu vào fileHeaderRecords
              if (type == 128) {
                await file!.setPosition(dataPos);
                final recordBytes = await file!.read(nextRecLength);
                final fileName = String.fromCharCodes(
                  recordBytes.sublist(2, 12),
                ).trim();
                final serviceName = String.fromCharCodes(
                  recordBytes.sublist(12, 18),
                ).trim();
                final fileNumber = String.fromCharCodes(
                  recordBytes.sublist(19, 22),
                ).trim();
                final serviceSubLevelName = String.fromCharCodes(
                  recordBytes.sublist(24, 30),
                ).trim();
                final versionNumber = String.fromCharCodes(
                  recordBytes.sublist(30, 38),
                ).trim();
                final year =
                    int.tryParse(
                      String.fromCharCodes(recordBytes.sublist(38, 40)).trim(),
                    ) ??
                    0;
                final month =
                    int.tryParse(
                      String.fromCharCodes(recordBytes.sublist(41, 43)).trim(),
                    ) ??
                    0;
                final day =
                    int.tryParse(
                      String.fromCharCodes(recordBytes.sublist(44, 46)).trim(),
                    ) ??
                    0;
                final maxPhysicalRecordLength = String.fromCharCodes(
                  recordBytes.sublist(47, 52),
                ).trim();
                final fileTypeStr = String.fromCharCodes(
                  recordBytes.sublist(57, 59),
                ).trim();
                final previousFileName = String.fromCharCodes(
                  recordBytes.sublist(61, 71),
                ).trim();
                fileHeaderRecords.add(
                  FileHeaderRecord(
                    address: dataPos,
                    length: nextRecLength,
                    logicalIndex: recordIndex,
                    physicalIndex: 0,
                    fileName: fileName,
                    serviceName: serviceName,
                    fileNumber: fileNumber,
                    serviceSubLevelName: serviceSubLevelName,
                    versionNumber: versionNumber,
                    year: year,
                    month: month,
                    day: day,
                    maxPhysicalRecordLength: maxPhysicalRecordLength,
                    fileType: fileTypeStr,
                    previousFileName: previousFileName,
                  ),
                );
              }

              // Store important record indices
              _storeRecordIndices(type, recordName, lisRecords.length - 1);
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
          // Error processing record $recordIndex: $e
          // Try to continue from next position
          currentPos += 16; // Skip to next potential blank header
          continue;
        }
      }

      // Processed $recordIndex records

      if (onProgress != null) onProgress(90);

      // Set some default values to prevent crashes
      dataFormatSpec.depthRepr = 68;
      dataFormatSpec.frameSpacing = 1.0;
      dataFormatSpec.direction = LisConstants.dirDown;
      dataFormatSpec.dataFrameSize = 100; // Default frame size

      // Read data format specification and datum blocks
      await _readDataFormatSpecification();
      await _findDataRecordRange();

      if (onProgress != null) onProgress(95);

      print('NTI parsing completed');
    } catch (e) {
      print('Error in _openNTI: $e');
      rethrow;
    }
  }

  Future<void> _openLIS(Function(double)? onProgress) async {
    // Implementation for Russian LIS format (from C++ OpenLIS method)
    if (file == null) return;

    try {
      print('Starting Russian LIS format parsing...');
      await file!.setPosition(0);

      blankRecords.clear();
      print('[LisFileParser] _openLIS: blankRecords cleared');
      lisRecords.clear();
      print('[LisFileParser] _openLIS: lisRecords cleared');

      // Read Blank Table Content (similar to C++ OpenLIS)
      int currentAddr = 0;

      while (true) {
        final currentPos = await file!.position();
        if (currentPos + 16 >= await file!.length()) {
          break;
        }

        await file!.setPosition(currentPos + 4);

        final group2 = await file!.read(4);
        final group3 = await file!.read(4);
        final group4 = await file!.read(4);

        if (group2.length < 4 || group3.length < 4 || group4.length < 4) {
          break;
        }

        final blankRec = BlankRecord(
          prevAddr:
              group2[0] +
              group2[1] * 256 +
              group2[2] * 65536 +
              group2[3] * 16777216,
          addr: currentAddr,
          nextAddr:
              group3[0] +
              group3[1] * 256 +
              group3[2] * 65536 +
              group3[3] * 16777216,
          nextRecLen: group4[1] + group4[0] * 256,
          num: group4[3],
        );
        blankRecords.add(blankRec);

        if (blankRec.nextAddr < 0 || blankRec.nextAddr > await file!.length()) {
          break;
        }

        currentAddr = blankRec.nextAddr;
        await file!.setPosition(
          await file!.position() + blankRec.nextRecLen - 4,
        );

        if (await file!.position() >= await file!.length() - 16) {
          break;
        }
      }

      // Read ${blankRecords.length} blank records

      // Read Record Table Content
      List<LisRecord> tempRecords = [];

      for (int i = 0; i < blankRecords.length; i++) {
        final blankRec = blankRecords[i];

        // Handle multi-block records (Russian LIS specific)
        if (blankRec.num >= 1) {
          if (tempRecords.isNotEmpty) {
            // Create new record with extended length
            final lastRecord = tempRecords.last;
            final newRecord = LisRecord(
              type: lastRecord.type,
              addr: lastRecord.addr,
              length: lastRecord.length + blankRec.nextRecLen - 4,
              name: lastRecord.name,
              blockNum: lastRecord.blockNum,
              frameNum: lastRecord.frameNum,
              depth: lastRecord.depth,
            );
            tempRecords.removeLast();
            tempRecords.add(newRecord);
          }
          continue;
        }

        final recordAddr = blankRec.addr + 16;
        await file!.setPosition(recordAddr);

        final typeBytes = await file!.read(1);
        if (typeBytes.isEmpty) continue;

        final recordType = typeBytes[0];
        await file!.setPosition(await file!.position() + 1); // Skip one byte

        String recordName = _getRecordName(recordType, recordAddr);

        // Handle special record type 34 (WELLSITE_DATA) parsing
        if (recordType == 34) {
          // For now, use the generic name
          recordName = 'WELLSITE_DATA';
        }

        final lisRecord = LisRecord(
          type: recordType,
          addr: recordAddr,
          length: blankRec.nextRecLen - 4,
          name: recordName,
        );

        tempRecords.add(lisRecord);

        // Store important record indices
        _storeRecordIndices(recordType, recordName, tempRecords.length - 1);

        // Update progress
        if (onProgress != null) {
          onProgress(i / blankRecords.length);
        }
      }

      lisRecords = tempRecords;
      print(
        '[LisFileParser] After parse: lisRecords.length = ${lisRecords.length}',
      );
      print(
        '[LisFileParser] Before save: lisRecords.length = ${lisRecords.length}',
      );
      print('Parsed ${lisRecords.length} LIS records');

      // Read data format specification and datum blocks
      await _readDataFormatSpecification();
      await _findDataRecordRange();

      isFileOpen = true;
    } catch (e) {
      print('Error in Russian LIS parsing: $e');
      rethrow;
    }
  }

  // Read Data Format Specification Record (converted from C++ ReadDataFormatSpecificationRecord)
  Future<void> _readDataFormatSpecification() async {
    print(
      '_readDataFormatSpecification called: dataFSRIdx=$dataFSRIdx, lisRecords.length=${lisRecords.length}',
    );

    if (dataFSRIdx < 0 || dataFSRIdx >= lisRecords.length) {
      print(
        'Data Format Specification record not found: dataFSRIdx=$dataFSRIdx',
      );

      // Try to find it manually
      for (int i = 0; i < lisRecords.length; i++) {
        final record = lisRecords[i];
        print('Record $i: type=${record.type}, name=${record.name}');
        if (record.type == 64) {
          print('Found Data Format Specification at index $i');
          dataFSRIdx = i;
          break;
        }
      }

      if (dataFSRIdx < 0) {
        print(
          'No Data Format Specification record found in ${lisRecords.length} records',
        );
        return;
      }
    }

    try {
      final lisRecord = lisRecords[dataFSRIdx];
      print(
        'Reading DataFormatSpec record: addr=${lisRecord.addr}, length=${lisRecord.length}, type=${lisRecord.type}',
      );

      await file!.setPosition(lisRecord.addr);
      print('Set file position to ${lisRecord.addr}');

      Uint8List recordData;

      if (fileType == LisConstants.fileTypeLis) {
        // Russian format
        final recordLen = lisRecord.length;
        recordData = Uint8List.fromList(await file!.read(recordLen));
      } else {
        // NTI format - handle multi-block
        print('NTI format: moving to position ${lisRecord.addr + 2}');
        await file!.setPosition(lisRecord.addr + 2);

        // Read size
        final sizeBytes = await file!.read(4);
        print('Size bytes: ${sizeBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

        int recordLen = sizeBytes[1] + sizeBytes[0] * 256;
        int continueFlag = sizeBytes[3];
        print('Record length: $recordLen, continue flag: $continueFlag');

        await file!.setPosition(await file!.position() + 2);
        print('Skipped type, now at position ${await file!.position()}');

        List<int> allData = [];
        recordLen = recordLen - 2; // DFSR chỉ có 2 byte header
        print('Adjusted record length: $recordLen');

        if (continueFlag == 1) {
          print('Multi-block record detected');
          while (true) {
            print('Reading $recordLen bytes');
            final data = await file!.read(recordLen);
            allData.addAll(data);
            print('Read ${data.length} bytes, total: ${allData.length}');

            final nextSizeBytes = await file!.read(4);
            recordLen = nextSizeBytes[1] + nextSizeBytes[0] * 256;
            recordLen = recordLen - 4;
            continueFlag = nextSizeBytes[3];
            print('Next block: length=$recordLen, continue=$continueFlag');

            if (continueFlag == 2) {
              print('End of multi-block record detected');
              break;
            }
          }
        } else {
          print('Single block record, reading $recordLen bytes');
          final data = await file!.read(recordLen);
          allData.addAll(data);
          print('Read ${data.length} bytes');
        }

        // Chỉ tạo recordData từ allData.sublist(2) để loại bỏ 2 byte đầu
        recordData = Uint8List.fromList(allData.length > 2 ? allData.sublist(2) : []);
        print('Total record data: ${recordData.length} bytes');
      }

      // Parse the data format specification
  // Luôn bỏ qua 2 byte đầu (header/padding) để EntryBlock bắt đầu từ 01 01
  await _parseDataFormatSpec(recordData.length > 2 ? recordData.sublist(2) : Uint8List(0));
    } catch (e) {
      print('Error reading Data Format Specification: $e');
    }
  }

  // Parse Data Format Specification data (converted from C++ logic)
  Future<void> _parseDataFormatSpec(Uint8List data) async {
    print('_parseDataFormatSpec called with ${data.length} bytes');
    // Debug: In ra giá trị raw của EntryBlock (từ đầu đến khi gặp entryType == 0)
  int rawIdx = 0;
  List<int> entryBlockRaw = [];
  // Lưu lại offset entryBlock (tính từ đầu file DataFormatSpec record)
  entryBlockOffset = 0; // Nếu cần offset thực tế trong file, cần cộng thêm addr của record
    while (rawIdx < data.length - 1) {
      final entryType = data[rawIdx];
      if (entryBlockOffset == 0) {
        entryBlockOffset = rawIdx; // Lưu offset entryBlock đầu tiên
      }
      entryBlockRaw.add(entryType);
      if (entryType == 0) {
        break;
      }
      if (rawIdx + 2 >= data.length) break;
      final size = data[rawIdx + 1];
      final reprCode = data[rawIdx + 2];
      entryBlockRaw.add(size);
      entryBlockRaw.add(reprCode);
      if (rawIdx + 3 + size > data.length) break;
      entryBlockRaw.addAll(data.sublist(rawIdx + 3, rawIdx + 3 + size));
      rawIdx += 3 + size;
    }
    print(
      'RAW ENTRYBLOCK BYTES: ${entryBlockRaw.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );
    int index = 0;
    entryBlock = EntryBlock();
    int entryFieldCount = 0;
    // Chỉ đọc tối đa 16 trường EntryBlock, dừng khi gặp entryType == 0 hoặc index vượt quá data
    while (index < data.length - 1 && entryFieldCount < 16) {
      if (index >= data.length) break;
      final entryType = data[index++];
      if (entryType == 0) {
        print(
          'DEBUG: entryFieldCount=$entryFieldCount, index=$index, entryType=0 (end)',
        );
        break; // End of entry blocks
      }
      if (index + 1 >= data.length) {
        print(
          'DEBUG: entryFieldCount=$entryFieldCount, index=$index, out of bounds for size/reprCode',
        );
        break;
      }
      final size = data[index++];
      final reprCode = data[index++];
      if (index + size > data.length) {
        print(
          'DEBUG: entryFieldCount=$entryFieldCount, index=$index, size=$size, reprCode=$reprCode, out of bounds for entryData',
        );
        break;
      }
      final entryData = data.sublist(index, index + size);
      print(
        'DEBUG: entryFieldCount=$entryFieldCount, index=$index, entryType=$entryType, size=$size, reprCode=$reprCode, entryData=${entryData.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );
      index += size;
      entryFieldCount++;
      final value = CodeReader.readCode(entryData, reprCode, size);
      switch (entryType) {
        case 1:
          entryBlock.nDataRecordType = value is num ? value.toInt() : 0;
          break;
        case 2:
          entryBlock.nDatumSpecBlockType = value is num ? value.toInt() : 0;
          break;
        case 3:
          entryBlock.nDataFrameSize = value is num ? value.toInt() : 0;
          print('Set nDataFrameSize to ${entryBlock.nDataFrameSize}');
          break;
        case 4:
          entryBlock.nDirection = value is num ? value.toInt() : 0;
          break;
        case 5:
          entryBlock.nOpticalDepthUnit = value is num ? value.toInt() : 0;
          break;
        case 6:
          entryBlock.fDataRefPoint = value is num ? value.toDouble() : 0.0;
          break;
        case 7:
          entryBlock.strDataRefPointUnit = value is String ? value : '';
          break;
        case 8:
          entryBlock.fFrameSpacing = value is num ? value.toDouble() : 0.0;
          break;
        case 9:
          entryBlock.strFrameSpacingUnit = value is String ? value : '';
          break;
        case 10:
          entryBlock.nMaxFramesPerRecord = value is num ? value.toInt() : 0;
          break;
        case 12:
          entryBlock.fAbsentValue = value is num ? value.toDouble() : -999.255;
          break;
        case 13:
          entryBlock.nDepthRecordingMode = value is num ? value.toInt() : 0;
          break;
        case 14:
          entryBlock.strDepthUnit = value is String ? value : '';
          break;
        case 15:
          entryBlock.nDepthRepr = value is num ? value.toInt() : 68;
          break;
        case 16:
          entryBlock.nDatumSpecBlockSubType = value is num ? value.toInt() : 0;
          break;
      }
    }

    //Đọc xong EntryBlock
    //Đọc Datum Spec Blocks
    // Đọc Datum Spec Blocks
    datumBlocks.clear();
    print('Starting to read Datum Spec Blocks from index $index');

    int nCurPos = index+3;
    int nTotalSize = data.length;
    int offset = 0;

    print('nCurPos=$nCurPos, nTotalSize=$nTotalSize');

    while (nCurPos < nTotalSize) {
      if (nTotalSize - nCurPos < 40) {
        print('Remaining bytes < 40, breaking: ${nTotalSize - nCurPos}');
        break;
      }

      print('Reading DatumSpecBlock at position $nCurPos');
      
      // Read mnemonic (4 bytes, repr code 65 - ASCII)
      if (nCurPos + 4 > nTotalSize) break;
      final mnemonicBytes = data.sublist(nCurPos, nCurPos + 4);
      String mnemonic = String.fromCharCodes(mnemonicBytes).trim().replaceAll('\x00', '');
      nCurPos += 4;
      print('Mnemonic: "$mnemonic"');

      // Read service ID (6 bytes, repr code 65 - ASCII)
      if (nCurPos + 6 > nTotalSize) break;
      final serviceIdBytes = data.sublist(nCurPos, nCurPos + 6);
      String serviceId = String.fromCharCodes(serviceIdBytes).trim().replaceAll('\x00', '');
      nCurPos += 6;
      print('ServiceID: "$serviceId"');

      // Read service order number (8 bytes, repr code 65 - ASCII)
      if (nCurPos + 8 > nTotalSize) break;
      final serviceOrderBytes = data.sublist(nCurPos, nCurPos + 8);
      String serviceOrderNb = String.fromCharCodes(serviceOrderBytes).trim().replaceAll('\x00', '');
      nCurPos += 8;
      print('ServiceOrderNb: "$serviceOrderNb"');

      // Read units (4 bytes, repr code 65 - ASCII)
      if (nCurPos + 4 > nTotalSize) break;
      final unitsBytes = data.sublist(nCurPos, nCurPos + 4);
      String units = String.fromCharCodes(unitsBytes).trim().replaceAll('\x00', '');
      nCurPos += 4;
      print('Units: "$units"');

      // Skip API Codes (4 bytes)
      nCurPos += 4;

      // Read file number (2 bytes, repr code 79 - 16-bit integer)
      if (nCurPos + 2 > nTotalSize) break;
      final fileNbBytes = data.sublist(nCurPos, nCurPos + 2);
      int fileNb = fileNbBytes[1] + (fileNbBytes[0] << 8); // Big endian
      nCurPos += 2;
      print('FileNb: $fileNb');

      // Read size (2 bytes, repr code 79 - 16-bit integer)
      if (nCurPos + 2 > nTotalSize) break;
      final sizeBytes = data.sublist(nCurPos, nCurPos + 2);
      int size = sizeBytes[1] + (sizeBytes[0] << 8); // Big endian
      nCurPos += 2;
      print('Size: $size');

      // Skip Process Level (3 bytes)
      nCurPos += 3;

      // Read number of samples (1 byte, repr code 66 - 8-bit integer)
      if (nCurPos + 1 > nTotalSize) break;
      int nbSamples = data[nCurPos];
      nCurPos += 1;
      print('NbSamples: $nbSamples');

      // Read representation code (1 byte, repr code 66 - 8-bit integer)
      if (nCurPos + 1 > nTotalSize) break;
      int reprCode = data[nCurPos];
      nCurPos += 1;
      print('ReprCode: $reprCode');

      // Skip Process Indication (5 bytes)
      nCurPos += 5;

      // Calculate derived values
      final codeSize = CodeReader.getCodeSize(reprCode);
      final dataItemNum = nbSamples > 0 ? (size ~/ codeSize) ~/ nbSamples : (size ~/ codeSize);
      final realSize = dataItemNum;

      print('CodeSize: $codeSize, DataItemNum: $dataItemNum, RealSize: $realSize');

      // Create DatumSpecBlock
      final datumSpecBlock = DatumSpecBlock(
        mnemonic: mnemonic,
        serviceId: serviceId,
        serviceOrderNb: serviceOrderNb,
        units: units,
        fileNb: fileNb,
        size: size,
        nbSample: nbSamples,
        reprCode: reprCode,
        offset: offset,
        dataItemNum: dataItemNum,
        realSize: realSize,
      );

      datumBlocks.add(datumSpecBlock);
      offset += size;

      print('Added DatumSpecBlock: ${datumSpecBlock.mnemonic}, offset updated to $offset');
    }

    print('Finished reading ${datumBlocks.length} Datum Spec Blocks');

    // Update DataFormatSpec with calculated values
    dataFormatSpec.depthRepr = entryBlock.nDepthRepr;
    dataFormatSpec.frameSpacing = entryBlock.fFrameSpacing;
    dataFormatSpec.direction = entryBlock.nDirection;
    dataFormatSpec.depthUnit = entryBlock.nOpticalDepthUnit;
    dataFormatSpec.absentValue = entryBlock.fAbsentValue;
    dataFormatSpec.depthRecordingMode = entryBlock.nDepthRecordingMode;

    // Calculate total frame size from datum blocks
    int totalFrameSize = 0;
    for (final datum in datumBlocks) {
      totalFrameSize += datum.size;
    }
    if (dataFormatSpec.depthRecordingMode == 0) {
      // Add depth size for depth-per-frame mode
      totalFrameSize += CodeReader.getCodeSize(dataFormatSpec.depthRepr);
    }
    dataFormatSpec.dataFrameSize = totalFrameSize;

    print('DataFormatSpec updated: frameSize=$totalFrameSize, depthRepr=${dataFormatSpec.depthRepr}');

  }

  // Parse individual Datum Spec Block (converted from C++ logic)
  DatumSpecBlock? _parseDatumSpecBlock(Uint8List data, int offset) {
    try {
      print('DatumSpecBlock raw bytes: ' + data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '));
      int index = 0;

      final mnemonicBytes = data.sublist(index, index + 4);
      print('mnemonicBytes: ' + mnemonicBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '));
      index += 4;
      String mnemonic = String.fromCharCodes(mnemonicBytes).trim().replaceAll('\x00', '');
      print('mnemonic: $mnemonic');

      if (offset > 0 && mnemonic == 'DEPT') {
        mnemonic = 'DEP1';
      }

      final serviceIdBytes = data.sublist(index, index + 6);
      print('serviceIdBytes: ' + serviceIdBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '));
      index += 6;
      String serviceId = String.fromCharCodes(serviceIdBytes).trim().replaceAll('\x00', '');
      print('serviceId: $serviceId');

      final serviceOrderBytes = data.sublist(index, index + 8);
      print('serviceOrderBytes: ' + serviceOrderBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '));
      index += 8;
      String serviceOrderNb = String.fromCharCodes(serviceOrderBytes).trim().replaceAll('\x00', '');
      print('serviceOrderNb: $serviceOrderNb');

      final unitsBytes = data.sublist(index, index + 4);
      print('unitsBytes: ' + unitsBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '));
      index += 4;
      String units = String.fromCharCodes(unitsBytes).trim().replaceAll('\x00', '');
      print('units: $units');

      final apiCodeBytes = data.sublist(index, index + 4);
      print('apiCodeBytes (skip): ' + apiCodeBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '));
      index += 4;

      final fileNb = data[index] * 256 + data[index + 1];
      print('fileNbBytes: ' + data.sublist(index, index + 2).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '));
      index += 2;
      print('fileNb: $fileNb');

      final size = data[index] * 256 + data[index + 1];
      print('sizeBytes: ' + data.sublist(index, index + 2).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '));
      index += 2;
      print('size: $size');

      final skip3Bytes = data.sublist(index, index + 3);
      print('skip3Bytes: ' + skip3Bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '));
      index += 3;

      final nbSample = data[index];
      print('nbSampleByte: ' + data.sublist(index, index + 1).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '));
      index += 1;
      print('nbSample: $nbSample');

      final reprCode = data[index];
      print('reprCodeByte: ' + data.sublist(index, index + 1).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '));
      index += 1;
      print('reprCode: $reprCode');

      final codeSize = CodeReader.getCodeSize(reprCode);
      final dataItemNum = size ~/ codeSize;
      final realSize = dataItemNum ~/ (nbSample > 0 ? nbSample : 1);

      print('codeSize: $codeSize, dataItemNum: $dataItemNum, realSize: $realSize');

      return DatumSpecBlock(
        mnemonic: mnemonic,
        serviceId: serviceId,
        serviceOrderNb: serviceOrderNb,
        units: units,
        fileNb: fileNb,
        size: size,
        nbSample: nbSample,
        reprCode: reprCode,
        offset: 0, // Will be calculated later
        dataItemNum: dataItemNum,
        realSize: realSize,
      );
    } catch (e) {
      print('Error parsing datum spec block: $e');
      return null;
    }
  }

  String _getRecordName(int type, int position) {
    switch (type) {
      case 0x80: // 128 - File Header
        return 'FILE_HEADER';
      case 0x22: // 34 - Well Site Data
        return 'WELLSITE_DATA';
      case 0x40: // 64 - Data Format Specification
        return 'Data Format Specification';
      case 0: // Data Record
        return 'Data';
      case 232: // Comment
        return 'Comment';
      case 129: // File Trailer Record
        return 'File Trailer Record';
      case 130: // Tape Header Record
        return 'Tape Header Record';
      case 131: // Tape Trailer Record
        return 'Tape Trailer Record';
      case 132: // Real Header Record
        return 'Real Header Record';
      case 133: // Real Trailer Record
        return 'Real Trailer Record';
      default:
        return 'Unknown';
    }
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

  // ignore: unused_element
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

    print(
      '[DEBUG] StartDepth raw value: $depth, bytes: ${depthBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );

    double convertedDepth = _convertToMeter(depth, dataFormatSpec.depthUnit);
    print(
      '[DEBUG] StartDepth converted to meter: $convertedDepth, unit: ${dataFormatSpec.depthUnit}',
    );

    return convertedDepth;
  }

  // ignore: unused_element
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
        // Convert feet to meters
        return depth * 0.3048;
      case LisConstants.depthUnitCm:
        return depth / 100.0;
      case LisConstants.depthUnitM:
        return depth;
      case LisConstants.depthUnitMm:
        return depth / 1000.0;
      case LisConstants.depthUnitHmm:
        // .5MM representation: half-millimeter -> convert to meters
        return depth / 2000.0;
      case LisConstants.depthUnitP1in:
        // 0.1 inch -> meter conversion: 0.1 in = 0.00254 m
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
    print('[LisFileParser] closeLisFile: blankRecords cleared');
    lisRecords.clear();
    print('[LisFileParser] closeLisFile: lisRecords cleared');
    datumBlocks.clear();
    print('[LisFileParser] closeLisFile: datumBlocks cleared');
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

  // ==================== DATA READING METHODS ====================

  // Get all data for a specific data record (converted from C++ GetAllData)
  Future<List<double>> getAllData(int currentDataRec) async {
    if (file == null ||
        currentDataRec < 0 ||
        currentDataRec >= lisRecords.length) {
      return [];
    }

    final lisRecord = lisRecords[currentDataRec];
    if (lisRecord.type != 0) {
      print('Returning empty list - not a data record');
      return []; // Not a data record
    }

    try {
      final oldPosition = await file!.position();

      // curveNum calculation removed (not used)

      List<double> result = [];

      if (fileType == LisConstants.fileTypeNti) {
        // Halliburton format
        await file!.setPosition(lisRecord.addr + 6);
        await file!.setPosition(await file!.position() - 6);

        // Read size
        final sizeBytes = await file!.read(4);
        int recordLen = sizeBytes[1] + sizeBytes[0] * 256;
        int continueFlag = sizeBytes[3];

        // Skip type
        await file!.setPosition(await file!.position() + 2);

        // Read depth
        final depthRepr = dataFormatSpec.depthRepr;
        final depthSize = CodeReader.getCodeSize(depthRepr);
        final depthBytes = await file!.read(depthSize);
        currentDepth = CodeReader.readCode(depthBytes, depthRepr, depthSize);

        // Read data
        int index = 0;
        recordLen = recordLen - 10; // 4 for len, 2 for type, 4 for depth

        if (continueFlag == 0) {
          final dataBytes = await file!.read(recordLen);
          byteData.setRange(index, index + dataBytes.length, dataBytes);
          index += dataBytes.length;
        } else {
          // Handle multi-block records
          while (true) {
            final dataBytes = await file!.read(recordLen);
            byteData.setRange(index, index + dataBytes.length, dataBytes);
            index += dataBytes.length;

            if (continueFlag == 2) break;

            final nextSizeBytes = await file!.read(4);
            recordLen = nextSizeBytes[1] + nextSizeBytes[0] * 256;
            recordLen = recordLen - 4;
            continueFlag = nextSizeBytes[3];
          }
        }

        currentDepth = _convertToMeter(currentDepth, dataFormatSpec.depthUnit);

        // Parse frames
        final frameNum = getFrameNum(currentDataRec);
        int byteDataIdx = 0;
        int fileDataIdx = 0;

        for (int frame = 0; frame < frameNum; frame++) {
          for (int i = 0; i < datumBlocks.length; i++) {
            if (i == 0 && dataFormatSpec.depthRecordingMode == 0) {
              continue; // Skip depth in depth-per-frame mode
            }

            final datum = datumBlocks[i];
            if (datum.size <= 4) {
              final entryBytes = byteData.sublist(
                byteDataIdx,
                byteDataIdx + datum.size,
              );
              byteDataIdx += datum.size;

              final value = CodeReader.readCode(
                entryBytes,
                datum.reprCode,
                datum.size,
              );
              final finalValue =
                  (value - dataFormatSpec.absentValue).abs() < 0.00001
                  ? double.nan
                  : value;

              if (fileDataIdx < fileData.length) {
                fileData[fileDataIdx++] = finalValue;
              }
            } else {
              // Handle arrays
              final codeSize = CodeReader.getCodeSize(datum.reprCode);
              final numItems = datum.size ~/ codeSize;

              for (int j = 0; j < numItems; j++) {
                final entryBytes = byteData.sublist(
                  byteDataIdx,
                  byteDataIdx + codeSize,
                );
                byteDataIdx += codeSize;

                final value = CodeReader.readCode(
                  entryBytes,
                  datum.reprCode,
                  codeSize,
                );
                final finalValue =
                    (value - dataFormatSpec.absentValue).abs() < 0.00001
                    ? double.nan
                    : value;

                if (fileDataIdx < fileData.length) {
                  fileData[fileDataIdx++] = finalValue;
                }
              }
            }
          }

          // Skip depth in depth-per-frame mode
          if (dataFormatSpec.depthRecordingMode == 0) {
            byteDataIdx += 4; // Skip depth bytes
          }
        }

        result = fileData
            .sublist(0, fileDataIdx)
            .map((e) => e.toDouble())
            .toList();
      } else {
        // Russian LIS format
        await file!.setPosition(lisRecord.addr + 2);

        final fileSize = await file!.length();
        final currentPos = await file!.position();
        final recordLen = lisRecord.length;

        Uint8List dataBytes;
        if (currentPos + recordLen > fileSize) {
          print(
            'Warning: Record length ($recordLen) exceeds file bounds. Available: ${fileSize - currentPos}',
          );
          final availableBytes = fileSize - currentPos;
          dataBytes = await file!.read(availableBytes);
        } else {
          dataBytes = await file!.read(recordLen);
        }

        if (dataBytes.isEmpty) {
          print('No data bytes read, returning empty result');
          await file!.setPosition(oldPosition);
          return [];
        }

        // Ensure we don't exceed buffer size
        final maxBytes = (dataBytes.length < byteData.length)
            ? dataBytes.length
            : byteData.length;
        if (dataBytes.length > byteData.length) {
          print(
            'Warning: Record data (${dataBytes.length}) exceeds buffer size (${byteData.length}), truncating',
          );
        }

        byteData.setRange(0, maxBytes, dataBytes);

        final depthSize = CodeReader.getCodeSize(dataFormatSpec.depthRepr);
        final depthBytes = byteData.sublist(0, depthSize);
        currentDepth = CodeReader.readCode(
          depthBytes,
          dataFormatSpec.depthRepr,
          depthSize,
        );
        currentDepth = _convertToMeter(currentDepth, dataFormatSpec.depthUnit);

        // Parse frames for Russian format
        final frameNum = getFrameNum(currentDataRec);
        int byteDataIdx = depthSize;
        int fileDataIdx = 0;
        final actualDataSize = maxBytes; // Use the actual data we read

        for (int frame = 0; frame < frameNum; frame++) {
          for (int i = 0; i < datumBlocks.length; i++) {
            if (i == 0 && dataFormatSpec.depthRecordingMode == 0) {
              print('Skipping depth datum at frame $frame, datum $i');
              continue; // Skip depth in depth-per-frame mode
            }

            final datum = datumBlocks[i];

            // Calculate actual bytes needed for this datum block (following C++ logic)
            int actualBytesNeeded;
            if (datum.size <= 4) {
              actualBytesNeeded = datum.size; // Single value - read entire size
            } else {
              actualBytesNeeded =
                  datum.size; // Array - read all elements in this frame
            }

            // Check bounds before accessing data
            if (byteDataIdx + actualBytesNeeded > actualDataSize) {
              break; // Exit if we don't have enough data
            }

            if (datum.size <= 4) {
              // Single value datum - read the entire size (following C++ logic)
              final entryBytes = byteData.sublist(
                byteDataIdx,
                byteDataIdx + datum.size,
              );
              byteDataIdx += datum.size;

              final value = CodeReader.readCode(
                entryBytes,
                datum.reprCode,
                datum.size,
              );
              final finalValue =
                  (value - dataFormatSpec.absentValue).abs() < 0.00001
                  ? double.nan
                  : value;

              if (fileDataIdx < fileData.length) {
                fileData[fileDataIdx++] = finalValue;
              }
            } else {
              // Handle multi-value arrays - following C++ logic, read ALL elements in one frame
              final codeSize = CodeReader.getCodeSize(datum.reprCode);
              final numElements =
                  datum.size ~/ codeSize; // Calculate number of elements

              // Read all elements of the array in this frame (following C++ approach)
              for (int j = 0; j < numElements; j++) {
                final entryBytes = byteData.sublist(
                  byteDataIdx,
                  byteDataIdx + codeSize,
                );
                byteDataIdx += codeSize;

                final value = CodeReader.readCode(
                  entryBytes,
                  datum.reprCode,
                  codeSize, // Use codeSize instead of datum.size for individual elements
                );
                final finalValue =
                    (value - dataFormatSpec.absentValue).abs() < 0.00001
                    ? double.nan
                    : value;

                if (fileDataIdx < fileData.length) {
                  fileData[fileDataIdx++] = finalValue;
                }
              }
            }
          }

          // Skip depth in depth-per-frame mode
          if (dataFormatSpec.depthRecordingMode == 0) {
            final depthSize = CodeReader.getCodeSize(dataFormatSpec.depthRepr);
            if (byteDataIdx + depthSize > actualDataSize) {
              break; // Exit frame loop if no more data
            }
            byteDataIdx += depthSize;
          }
        }

        result = fileData
            .sublist(0, fileDataIdx)
            .map((e) => e.toDouble())
            .toList();
      }

      await file!.setPosition(oldPosition);
      return result;
    } catch (e) {
      print('Error in getAllData: $e');
      return [];
    }
  }

  // Get frame number for a data record (converted from C++ GetFrameNum)
  int getFrameNum(int currentDataRec) {
    if (currentDataRec < 0 || currentDataRec >= lisRecords.length) {
      return 0;
    }

    final lisRecord = lisRecords[currentDataRec];
    int recordLen = lisRecord.length;

    if (fileType == LisConstants.fileTypeLis) {
      // Russian format
      recordLen -= 2; // Subtract 2 bytes
      if (dataFormatSpec.depthRecordingMode == 1) {
        recordLen -= CodeReader.getCodeSize(dataFormatSpec.depthRepr);
      }
    } else {
      // NTI format
      recordLen -= 6; // Subtract 6 bytes
      if (dataFormatSpec.depthRecordingMode == 1) {
        recordLen -= CodeReader.getCodeSize(dataFormatSpec.depthRepr);
      }
    }

    if (dataFormatSpec.dataFrameSize > 0) {
      return recordLen ~/ dataFormatSpec.dataFrameSize;
    }

    return 0;
  }

  // Get column names for data table
  List<String> getColumnNames() {
    List<String> columns = [];

    // Add depth column first
    columns.add('DEPTH');

    // Add curve columns
    for (var datum in datumBlocks) {
      if (dataFormatSpec.depthRecordingMode == 0 && datum.mnemonic == 'DEPT') {
        continue; // Skip DEPT in depth-per-frame mode
      }

      // For both single values and arrays, just add one column
      // Arrays will display "..." and be clickable to show waveform
      columns.add(datum.mnemonic);
    }

    // If no datum blocks found, create sample columns for testing
    if (datumBlocks.isEmpty) {
      print('No datum blocks found, creating sample columns');
      columns.addAll(['SAMPLE_CURVE_1', 'SAMPLE_CURVE_2', 'SAMPLE_CURVE_3']);
    }

    return columns;
  }

  // Check if a column represents an array datum
  bool isArrayColumn(String columnName) {
    if (columnName == 'DEPTH') return false;

    final datum = datumBlocks.firstWhere(
      (d) => d.mnemonic == columnName,
      orElse: () => datumBlocks.first, // fallback
    );

    return datum.size > 4; // Array datums have size > 4
  }

  // Get array data for a specific datum at a specific record and frame
  Future<List<double>> getArrayData(
    String columnName,
    int recordIdx,
    int frameIdx,
  ) async {
    try {
      print(
        'getArrayData called: columnName=$columnName, recordIdx=$recordIdx, frameIdx=$frameIdx',
      );

      final datum = datumBlocks.firstWhere(
        (d) => d.mnemonic == columnName,
        orElse: () => throw Exception('Datum $columnName not found'),
      );

      if (datum.size <= 4) {
        // Not an array, return empty list
        print('$columnName is not an array (size=${datum.size})');
        return [];
      }

      print(
        'Found array datum $columnName with size=${datum.size}, dataItemNum=${datum.dataItemNum}',
      );

      // Use existing getAllData method to get the full data
      final allData = await getAllData(recordIdx);
      if (allData.isEmpty) {
        print('No data returned from getAllData for record $recordIdx');
        return [];
      }

      // Calculate total values per frame
      int valuesPerFrame = 0;
      for (final d in datumBlocks) {
        if (d.size <= 4) {
          valuesPerFrame += 1; // Single values
        } else {
          valuesPerFrame += d.dataItemNum; // Array values
        }
      }

      // Calculate start index for this frame
      final frameStartIdx = frameIdx * valuesPerFrame;

      // Calculate start index for this specific datum in the frame
      int datumStartIdx = frameStartIdx;
      for (int i = 0; i < datumBlocks.length; i++) {
        if (datumBlocks[i].mnemonic == columnName) {
          break;
        }
        if (datumBlocks[i].size <= 4) {
          datumStartIdx += 1; // Single value
        } else {
          datumStartIdx += datumBlocks[i].dataItemNum; // Array values
        }
      }

      final datumEndIdx = datumStartIdx + datum.dataItemNum;

      if (datumEndIdx <= allData.length) {
        final arrayData = allData.sublist(datumStartIdx, datumEndIdx);
        print(
          'Extracted ${arrayData.length} values for $columnName from indices $datumStartIdx to $datumEndIdx',
        );
        return arrayData;
      } else {
        print(
          'Index out of bounds: trying to extract $datumStartIdx to $datumEndIdx from ${allData.length} values',
        );
        return [];
      }
    } catch (e) {
      print('Error in getArrayData: $e');
      return [];
    }
  }

  // Get data for table display
  Future<List<Map<String, dynamic>>> getTableData({int maxRows = 1000}) async {
    print(
      'getTableData called: isFileOpen=$isFileOpen, startDataRec=$startDataRec, endDataRec=$endDataRec',
    );
    print('datumBlocks count: ${datumBlocks.length}');
    print('dataFSRIdx: $dataFSRIdx');

    if (!isFileOpen) {
      print('File not open');
      return [];
    }

    List<Map<String, dynamic>> tableData = [];
    final columnNames = getColumnNames();

    // If we have no real data, create sample data for testing
    if (startDataRec < 0 || endDataRec < 0 || datumBlocks.isEmpty) {
      print(
        'Creating sample data: startDataRec=$startDataRec, endDataRec=$endDataRec, datumBlocks=${datumBlocks.length}',
      );

      // Create sample data
      for (int i = 0; i < maxRows.clamp(0, 50); i++) {
        Map<String, dynamic> row = {};
        row['DEPTH'] = (1000.0 + i * 0.5).toStringAsFixed(3);

        for (int col = 1; col < columnNames.length; col++) {
          final value = 100.0 + i * 0.1 + col * 10;
          row[columnNames[col]] = value.toStringAsFixed(3);
        }

        tableData.add(row);
      }

      print('Created ${tableData.length} sample rows');
      return tableData;
    }

    int rowCount = 0;

    try {
      for (
        int recordIdx = startDataRec;
        recordIdx <= endDataRec && rowCount < maxRows;
        recordIdx++
      ) {
        final frameData = await getAllData(recordIdx);
        if (frameData.isEmpty) continue;

        final frameNum = getFrameNum(recordIdx);
        final startingDepth = currentDepth;

        for (int frame = 0; frame < frameNum && rowCount < maxRows; frame++) {
          Map<String, dynamic> row = {};

          // Calculate depth for this frame
          double frameDepth = startingDepth;
          if (dataFormatSpec.direction == LisConstants.dirDown) {
            frameDepth += frame * (step / 1000.0);
          } else {
            frameDepth -= frame * (step / 1000.0);
          }

          row['DEPTH'] = frameDepth.toStringAsFixed(3);

          // Add curve values with proper handling for arrays vs singles
          // In frameData, all data for all frames is stored sequentially

          // Calculate how much data each frame contains
          int singleValuesPerFrame = 0;
          int arrayElementsPerFrame = 0;

          for (var datum in datumBlocks) {
            if (dataFormatSpec.depthRecordingMode == 0 &&
                datum.mnemonic == 'DEPT') {
              continue; // Skip DEPT in depth-per-frame mode
            }

            if (datum.size <= 4) {
              singleValuesPerFrame += 1;
            } else {
              arrayElementsPerFrame += datum.dataItemNum;
            }
          }

          int totalValuesPerFrame =
              singleValuesPerFrame + arrayElementsPerFrame;
          int frameDataStartIndex = frame * totalValuesPerFrame;

          int currentIndex = frameDataStartIndex;

          for (int col = 1; col < columnNames.length; col++) {
            final columnName = columnNames[col];

            // Find corresponding datum
            final datum = datumBlocks.firstWhere(
              (d) => d.mnemonic == columnName,
              orElse: () => datumBlocks.first,
            );

            if (datum.size <= 4) {
              // Single value datum
              if (currentIndex < frameData.length) {
                final value = frameData[currentIndex];
                row[columnName] = value.isNaN
                    ? 'NULL'
                    : value.toStringAsFixed(3);
                currentIndex += 1;
              } else {
                row[columnName] = 'NULL';
              }
            } else {
              // Array datum - display "..." and store metadata for waveform viewing
              row[columnName] = {
                'display': '...',
                'isArray': true,
                'recordIdx': recordIdx,
                'frameIdx': frame,
                'datumName': columnName,
              };
              currentIndex += datum.dataItemNum;
            }
          }

          tableData.add(row);
          rowCount++;
        }
      }
    } catch (e) {
      print('Error generating table data: $e');
    }

    return tableData;
  }

  // Method to update a specific data value in memory
  Future<bool> updateDataValue({
    required int recordIndex,
    required int frameIndex,
    required String columnName,
    required double newValue,
  }) async {
    try {
      if (!isFileOpen) {
        print('[updateDataValue] File not open for updating');
        return false;
      }

      // Find the datum for this column
      final datum = datumBlocks.firstWhere(
        (d) => d.mnemonic == columnName,
        orElse: () => throw Exception('Column $columnName not found'),
      );

      // Skip array data for safety, but ALLOW DEPTH/DEPT update
      if (datum.size > 4) {
        print('[updateDataValue] Cannot update array data for $columnName');
        return false;
      }

      // Get the actual record index in the data records range
      final actualRecordIndex = startDataRec + recordIndex;
      if (actualRecordIndex < startDataRec || actualRecordIndex > endDataRec) {
        print(
          '[updateDataValue] Record index out of range: $actualRecordIndex (start=$startDataRec, end=$endDataRec)',
        );
        return false;
      }

      // Calculate the position in the raw data
      final allData = await getAllData(actualRecordIndex);
      if (allData.isEmpty) {
        print('[updateDataValue] No data found for record $actualRecordIndex');
        return false;
      }

      final frameNum = getFrameNum(actualRecordIndex);
      if (frameIndex >= frameNum) {
        print(
          '[updateDataValue] Frame index out of range: $frameIndex >= $frameNum',
        );
        return false;
      }

      // Calculate data positioning (same logic as getTableData)
      int singleValuesPerFrame = 0;
      int arrayElementsPerFrame = 0;

      for (var d in datumBlocks) {
        if (dataFormatSpec.depthRecordingMode == 0 && d.mnemonic == 'DEPT') {
          continue; // Skip DEPT in depth-per-frame mode
        }

        if (d.size <= 4) {
          singleValuesPerFrame += 1;
        } else {
          arrayElementsPerFrame += d.dataItemNum;
        }
      }

      int totalValuesPerFrame = singleValuesPerFrame + arrayElementsPerFrame;
      int frameDataStartIndex = frameIndex * totalValuesPerFrame;
      int currentIndex = frameDataStartIndex;

      // Find the index for this specific column
      for (int i = 0; i < datumBlocks.length; i++) {
        final otherDatum = datumBlocks[i];
        if (dataFormatSpec.depthRecordingMode == 0 &&
            otherDatum.mnemonic == 'DEPT') {
          continue; // Skip DEPT in depth-per-frame mode
        }

        if (otherDatum.mnemonic == columnName) {
          break; // Found our column
        }

        if (otherDatum.size <= 4) {
          currentIndex += 1; // Single value
        } else {
          currentIndex += otherDatum.dataItemNum; // Array values
        }
      }

      if (currentIndex >= allData.length) {
        print(
          '[updateDataValue] Data index out of bounds: $currentIndex >= ${allData.length}',
        );
        return false;
      }

      // Store the change for later file writing
      final changeKey = '${actualRecordIndex}_${frameIndex}_$columnName';
      // DEBUG: In ra index, frame, value trước khi push vào pending changes
      print(
        '[DEBUG][PENDING][BEFORE] recordIndex=$recordIndex (actual=$actualRecordIndex), frameIndex=$frameIndex, newValue=$newValue, oldValue=${allData[currentIndex]}, changeKey=$changeKey',
      );
      if (!_pendingChanges.containsKey(changeKey)) {
        _pendingChanges[changeKey] = {
          'recordIndex': actualRecordIndex,
          'frameIndex': frameIndex,
          'columnName': columnName,
          'dataIndex': currentIndex,
          'oldValue': allData[currentIndex],
          'newValue': newValue,
          'datum': datum,
        };
        print(
          '[updateDataValue] Stored pending change: $changeKey = $newValue (was ${allData[currentIndex]})',
        );
      } else {
        // Update existing pending change
        _pendingChanges[changeKey]!['newValue'] = newValue;
        print(
          '[updateDataValue] Updated pending change: $changeKey = $newValue',
        );
      }
      // DEBUG: In ra index, frame, value sau khi push vào pending changes
      print(
        '[DEBUG][PENDING][AFTER] recordIndex=$recordIndex (actual=$actualRecordIndex), frameIndex=$frameIndex, newValue=${_pendingChanges[changeKey]!['newValue']}, changeKey=$changeKey',
      );
      return true;
    } catch (e) {
      print('[updateDataValue] Error updating data value: $e');
      return false;
    }
  }

  // Pending changes storage
  final Map<String, Map<String, dynamic>> _pendingChanges = {};

  // Get pending changes count
  int get pendingChangesCount => _pendingChanges.length;

  // Clear all pending changes
  void clearPendingChanges() {
    _pendingChanges.clear();
    print('Cleared all pending changes');
  }

  // Method to save all pending changes to the actual LIS file
  Future<bool> savePendingChanges() async {
    print('DEBUG TEST: savePendingChanges called');
    print('');
    print('========================================');
    print('SAVE PENDING CHANGES CALLED!');
    print('File being saved: $fileName');
    print('========================================');
    print('Pending changes count: ${_pendingChanges.length}');

    if (_pendingChanges.isEmpty) {
      print('No pending changes to save');
      return true;
    }

    try {
      print('Saving ${_pendingChanges.length} pending changes to file...');
      print('File name: $fileName');

      // Tạo đường dẫn file mới để lưu (không ghi đè file gốc)
      final extIndex = fileName.lastIndexOf('.');
      final newFileName = extIndex > 0
          ? '${fileName.substring(0, extIndex)}_modified${fileName.substring(extIndex)}'
          : '${fileName}_modified';
      print('Lưu thay đổi vào file mới: $newFileName');

      // Read entire file into memory
      final originalBytes = await File(fileName).readAsBytes();
      final modifiedBytes = Uint8List.fromList(originalBytes);

      // Xác định các dòng bị đánh dấu xóa
      final deletedRows = _pendingChanges.entries
          .where((e) => e.value['type'] == 'delete')
          .map((e) => e.value['rowIndex'] as int)
          .toSet();

      // Lấy danh sách các data records
      final dataRecords = lisRecords.where((r) => r.type == 0).toList();
      print('DEBUG: Có ${dataRecords.length} data records');

      // Tạo danh sách các record cần giữ lại (không bị xóa)
      final recordsToKeep = <LisRecord>[];
      for (int i = 0; i < dataRecords.length; i++) {
        if (!deletedRows.contains(i)) {
          recordsToKeep.add(dataRecords[i]);
        } else {
          print('DEBUG: Loại bỏ data record tại index $i do bị đánh dấu xóa');
        }
      }

      // Áp dụng các thay đổi cập nhật giá trị cho các record còn lại
      for (final entry in _pendingChanges.entries) {
        final change = entry.value;
        if (change['type'] == 'delete') continue;
        final actualRecordIndex = change['recordIndex'] as int;
        final frameIndex = change['frameIndex'] as int;
        final newValue = change['newValue'] as double;
        final datum = change['datum'] as DatumSpecBlock;
        final oldValue = change['oldValue'];
        // Nếu record này bị xóa thì bỏ qua
        final dataRecordIdx = actualRecordIndex - startDataRec;
        if (deletedRows.contains(dataRecordIdx)) continue;
        // DEBUG: In ra index, frame, value trước khi lưu file
        print(
          '[DEBUG][SAVE][BEFORE] recordIndex=$actualRecordIndex, frameIndex=$frameIndex, newValue=$newValue, oldValue=$oldValue, column=${datum.mnemonic}',
        );
        final success = _updateBytesInMemory(
          modifiedBytes,
          actualRecordIndex,
          frameIndex,
          datum,
          newValue,
        );
        print(
          '[DEBUG][SAVE][AFTER] recordIndex=$actualRecordIndex, frameIndex=$frameIndex, newValue=$newValue, column=${datum.mnemonic}, success=$success',
        );
        if (!success) {
          print('[savePendingChanges] Failed to update change for $entry');
        }
      }

      // TODO: Loại bỏ thực sự các record bị xóa khỏi file (cần xử lý lại cấu trúc file LIS)
      // Hiện tại chỉ loại khỏi danh sách, chưa ghi lại file mới với record bị loại bỏ
      // Nếu cần ghi lại file với các record bị loại bỏ, cần tái cấu trúc file và cập nhật lại các chỉ số record

      // Write the modified bytes back to file
      print('Modified bytes length: ${modifiedBytes.length} bytes');

      await File(newFileName).writeAsBytes(modifiedBytes);
      print('DEBUG: Written modified bytes to new file');

      file = await File(newFileName).open(mode: FileMode.read);
      final newFileSize = await File(newFileName).length();
      print('New file size after write: $newFileSize bytes');

      print('Successfully saved ${_pendingChanges.length} changes to file');
      print('========================================');
      print('SAVE COMPLETED SUCCESSFULLY!');
      print('========================================');
      print('');
      _pendingChanges.clear();

      await closeLisFile();
      return true;
    } catch (e) {
      print('Error saving changes to file: $e');
      return false;
    }
  }

  // Helper method to update bytes in memory
  bool _updateBytesInMemory(
    Uint8List bytes,
    int actualRecordIndex,
    int frameIndex,
    DatumSpecBlock datum,
    double newValue,
  ) {
    try {
      print(
        'DEBUG: Updating bytes for record $actualRecordIndex, frame $frameIndex, datum ${datum.mnemonic}',
      );

      // Find the data records in order
      final dataRecords = lisRecords.where((r) => r.type == 0).toList();
      print(
        'DEBUG: Found \u001b[1m${dataRecords.length}\u001b[0m data records, startDataRec=$startDataRec',
      );

      if (dataRecords.isEmpty) {
        print(
          'DEBUG: lisRecords.length = \u001b[1m${lisRecords.length}\u001b[0m',
        );
        for (int i = 0; i < lisRecords.length; i++) {
          final r = lisRecords[i];
          print('  lisRecords[$i]: type=${r.type}, toString=${r.toString()}');
        }
      }

      final dataRecordIdx = actualRecordIndex - startDataRec;
      if (dataRecordIdx < 0 || dataRecordIdx >= dataRecords.length) {
        print(
          'Data record index out of bounds: $dataRecordIdx (range: 0--${dataRecords.length - 1})',
        );
        return false;
      }

      final lisRecord = dataRecords[dataRecordIdx];
      print(
        'DEBUG: Using data record at index $dataRecordIdx, addr=${lisRecord.addr}',
      );

      // Calculate byte position within the record
      int byteOffset = 0;

      if (fileType == LisConstants.fileTypeLis) {
        // Russian LIS format
        byteOffset = 2; // Skip record length
      } else {
        // NTI format
        byteOffset = 6; // Skip header
      }
      print('DEBUG: Initial byteOffset=$byteOffset (after header)');

      // Add frame offset - BUT we need to use the ACTUAL frame size from data
      // Not the theoretical frameSize from spec
      final frameSize = dataFormatSpec.dataFrameSize;
      byteOffset += frameIndex * frameSize;
      print(
        'DEBUG: After frame offset: byteOffset=$byteOffset (frameIndex=$frameIndex, frameSize=$frameSize)',
      );

      // Add datum offset within frame - match EXACT parsing logic
      print('DEBUG: depthRecordingMode=${dataFormatSpec.depthRecordingMode}');
      int datumOffset = 0;

      // CRITICAL: In parsing, byteDataIdx starts at 4 (after depth),
      // but ACHV is at 2068. The difference means DEPT IS included in offset calculation.
      // So we need to add 4 bytes to match parsing position.

      for (int i = 0; i < datumBlocks.length; i++) {
        final d = datumBlocks[i];

        print(
          'DEBUG: Processing datum $i: ${d.mnemonic}, size=${d.size}, looking for ${datum.mnemonic}',
        );

        if (d.mnemonic == datum.mnemonic) {
          print(
            'DEBUG: Found target datum ${datum.mnemonic} at index $i, datumOffset=$datumOffset',
          );
          break; // Found our target datum
        }

        // Add size for each datum before target (including DEPT)
        datumOffset += d.size;
        print('DEBUG: Added ${d.size} to datumOffset, now $datumOffset');
      }

      // CRITICAL FIX: Add 4 bytes to match parsing offset
      // In parsing: ACHV at 2068, in save: ACHV calculated at 2064
      // Need to add 4 bytes difference
      datumOffset += 4;
      print('DEBUG: Added 4 bytes correction, final datumOffset=$datumOffset');

      byteOffset += datumOffset;
      print(
        'DEBUG: After datum offset: byteOffset=$byteOffset (datumOffset=$datumOffset)',
      );

      // Calculate absolute file position
      final filePosition = lisRecord.addr + byteOffset;
      print(
        'DEBUG: Final file position=$filePosition (record.addr=${lisRecord.addr} + byteOffset=$byteOffset)',
      );

      // Validate position
      if (filePosition + datum.size > bytes.length) {
        print(
          'Position out of bounds: ${filePosition + datum.size} > ${bytes.length}',
        );
        return false;
      }

      // Convert new value to bytes based on representation code
      final valueBytes = _encodeValue(newValue, datum.reprCode, datum.size);
      print(
        'DEBUG: Encoded value $newValue (reprCode=${datum.reprCode}) to ${valueBytes.length} bytes: ${valueBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );

      // Read current bytes at this position for comparison
      final currentBytes = bytes.sublist(
        filePosition,
        filePosition + datum.size,
      );
      print(
        'DEBUG: Current bytes at position $filePosition: ${currentBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );

      // VERIFICATION: Let's also check what we would read at the same position
      // to verify our calculation is correct
      final verificationValue = _decodeValue(currentBytes, datum.reprCode);
      print(
        'DEBUG: Current value decoded at position $filePosition: $verificationValue',
      );

      // Update bytes in memory
      for (int i = 0; i < valueBytes.length && i < datum.size; i++) {
        bytes[filePosition + i] = valueBytes[i];
      }

      // Verify the write
      final writtenBytes = bytes.sublist(
        filePosition,
        filePosition + datum.size,
      );
      print(
        'DEBUG: Written bytes at position $filePosition: ${writtenBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );

      // Verify the decoded value
      final verificationAfterWrite = _decodeValue(writtenBytes, datum.reprCode);
      print('DEBUG: New value decoded after write: $verificationAfterWrite');

      print('Updated value $newValue at position $filePosition');
      return true;
    } catch (e) {
      print('Error updating bytes in memory: $e');
      return false;
    }
  }

  // Helper method to decode a value from bytes for verification
  double _decodeValue(Uint8List bytes, int reprCode) {
    try {
      switch (reprCode) {
        case 68: // 4-byte float - Try different approaches
          // Try CodeReader first
          try {
            return CodeReader.readCode(bytes, reprCode, bytes.length);
          } catch (e) {
            print('CodeReader failed, trying ByteData: $e');
            // Fallback to ByteData with big endian
            final buffer = ByteData.sublistView(bytes);
            return buffer.getFloat32(0, Endian.big);
          }

        case 73: // 4-byte int
          return CodeReader.readCode(bytes, reprCode, bytes.length);

        case 70: // 4-byte float (IBM format)
          return CodeReader.readCode(bytes, reprCode, bytes.length);

        case 49: // 2-byte float
          return CodeReader.readCode(bytes, reprCode, bytes.length);

        case 79: // 2-byte int
          return CodeReader.readCode(bytes, reprCode, bytes.length);

        default:
          print('Unsupported representation code for decoding: $reprCode');
          return 0.0;
      }
    } catch (e) {
      print('Error decoding value: $e');
      return 0.0;
    }
  }

  // Helper method to encode a value based on representation code
  Uint8List _encodeValue(double value, int reprCode, int size) {
    try {
      switch (reprCode) {
        case 68: // 4-byte float - Use custom encoding to match CodeReader format
          return _encodeRussianLisFloat(value);

        case 73: // 4-byte int
          final buffer = ByteData(4);
          buffer.setInt32(0, value.round(), Endian.little);
          return buffer.buffer.asUint8List();

        case 70: // 4-byte float (IBM format - simplified)
          final buffer = ByteData(4);
          buffer.setFloat32(0, value, Endian.big);
          return buffer.buffer.asUint8List();

        case 49: // 2-byte float (simplified)
          final buffer = ByteData(2);
          buffer.setInt16(0, (value * 100).round(), Endian.little);
          return buffer.buffer.asUint8List();

        case 79: // 2-byte int
          final buffer = ByteData(2);
          buffer.setInt16(0, value.round(), Endian.little);
          return buffer.buffer.asUint8List();

        default:
          print('Unsupported representation code: $reprCode');
          return Uint8List(size); // Return zeros
      }
    } catch (e) {
      print('Error encoding value: $e');
      return Uint8List(size); // Return zeros on error
    }
  }

  // Russian LIS Float Encoder (reprCode 68) - Exact reverse of C++ ReadCode
  Uint8List _encodeRussianLisFloat(double value) {
    // Custom encoding algorithm matching C++ ReadCode logic
    print('DEBUG ENCODE: input value=$value');

    if (value == 0.0) {
      final result = Uint8List.fromList([0, 0, 0, 0]);
      print('DEBUG ENCODE: zero -> bytes=[${result.join(', ')}]');
      return result;
    }

    // Handle sign bit
    bool isNegative = value < 0;
    double absValue = value.abs();

    // Normalize fraction to [0.5, 1.0) range
    double targetFraction = absValue;
    int exponentBits = isNegative ? 127 : 128;

    while (targetFraction >= 1.0) {
      targetFraction /= 2.0;
      exponentBits++;
    }
    while (targetFraction < 0.5) {
      targetFraction *= 2.0;
      exponentBits--;
    }

    // Clamp exponent to valid range
    exponentBits = exponentBits.clamp(0, 255);

    // Convert fraction to 23-bit mantissa using C++ algorithm
    int mantissaBits = 0;
    double remainingFraction = targetFraction;
    double bitValue = 0.5;
    for (int i = 22; i >= 0; i--) {
      if (remainingFraction >= bitValue) {
        mantissaBits |= (1 << i);
        remainingFraction -= bitValue;
      }
      bitValue /= 2.0;
    }

    // Handle negative numbers - C++ does complement operation
    if (isNegative) {
      mantissaBits = (~mantissaBits + 1) & 0x7FFFFF;
    }

    // Assemble the 32-bit result
    int result = 0;
    if (isNegative) {
      result |= 0x80000000; // Sign bit
    }
    result |= (exponentBits << 23); // Exponent (8 bits)
    result |= mantissaBits; // Mantissa (23 bits)

    // Extract bytes in big-endian order
    int ch0 = (result >> 24) & 0xFF;
    int ch1 = (result >> 16) & 0xFF;
    int ch2 = (result >> 8) & 0xFF;
    int ch3 = result & 0xFF;

    final encoded = Uint8List.fromList([ch0, ch1, ch2, ch3]);
    print(
      'DEBUG ENCODE: value=$value, isNeg=$isNegative, exp=$exponentBits, mantissa=0x${mantissaBits.toRadixString(16).padLeft(6, '0')} -> bytes=[${encoded.join(', ')}]',
    );
    return encoded;
  }
}
