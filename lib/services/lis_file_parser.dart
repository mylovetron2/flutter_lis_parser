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
    byteData = Uint8List(200000); // Increase buffer size for larger records
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

      // Follow C++ logic exactly - start at position 0 and read blank records
      await file!.setPosition(0);

      // Start with addr from position 0 (as per C++: long lAddr=0)
      int addr = 0;
      int maxIterations = 100; // Safety limit
      int iteration = 0;

      while (iteration < maxIterations) {
        print('Reading blank record at position: $addr');

        if (addr + 16 >= await file!.length()) {
          print('Reached end of file');
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
          print('Insufficient data read, breaking');
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

        print(
          'Blank record ${iteration}: addr=${addr}, nextAddr=${correctedBlankRec.nextAddr}, nextRecLen=${correctedBlankRec.nextRecLen}, prevAddr=${correctedBlankRec.prevAddr}',
        );

        if (correctedBlankRec.nextAddr < 0 ||
            correctedBlankRec.nextAddr >= await file!.length()) {
          print('Invalid nextAddr (${correctedBlankRec.nextAddr}), breaking');
          break;
        }

        // Update addr to nextAddr (as per C++ logic: lAddr=lNextAddr)
        addr = correctedBlankRec.nextAddr;

        // Move to next record: seek to nextRecLen - 4 (as per C++ logic)
        await file!.setPosition(correctedBlankRec.nextRecLen - 4);

        // Check if we reached near end of file (as per C++)
        if (await file!.position() >= await file!.length() - 16) {
          print('Near end of file, breaking');
          break;
        }

        iteration++;
      }

      // File type detection based on blank record address consistency
      // Default to LIS (Russian format) first - matching C++ logic
      fileType = LisConstants.fileTypeLis;
      print(
        'Read ${tempBlankRecords.length} blank records for file type detection',
      );

      // Match C++ logic exactly: need > 5 blank records for reliable LIS detection
      if (tempBlankRecords.length > 5) {
        bool isConsistent = true;
        for (int i = 1; i < tempBlankRecords.length - 1; i++) {
          // Check address consistency between consecutive blank records
          // In Russian LIS: blankArr[i]->lAddr == blankArr[i+1]->lPrevAddr
          // and blankArr[i]->lNextAddr == blankArr[i+1]->lAddr
          if (tempBlankRecords[i].addr != tempBlankRecords[i + 1].prevAddr) {
            print(
              'Address inconsistency at record $i: ${tempBlankRecords[i].addr} != ${tempBlankRecords[i + 1].prevAddr}',
            );
            isConsistent = false;
            break;
          }
          if (tempBlankRecords[i].nextAddr != tempBlankRecords[i + 1].addr) {
            print(
              'NextAddr inconsistency at record $i: ${tempBlankRecords[i].nextAddr} != ${tempBlankRecords[i + 1].addr}',
            );
            isConsistent = false;
            break;
          }
        }

        if (!isConsistent) {
          fileType = LisConstants.fileTypeNti; // Halliburton format
          print('File type detected as NTI due to blank record inconsistency');
        } else {
          print(
            'File type detected as LIS (Russian) - blank records are consistent',
          );
        }
      } else {
        fileType = LisConstants.fileTypeNti; // Less than 5 records = NTI
        print(
          'File type detected as NTI - insufficient blank records (${tempBlankRecords.length} <= 5)',
        );
      }

      print(
        'File type detection completed: ${fileType == LisConstants.fileTypeNti ? "NTI" : "LIS (Russian)"}',
      );
    } catch (e) {
      print('Error in file type detection: $e');
      fileType = LisConstants.fileTypeNti; // Default to NTI on error
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
      lisRecords.clear();

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

      print('Read ${blankRecords.length} blank records');

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
        // Match C++ logic: Seek(lAddr+6), then Seek(-6) = effectively Seek(lAddr)
        print('NTI format: moving to position ${lisRecord.addr}');
        await file!.setPosition(lisRecord.addr);

        // Read size
        final sizeBytes = await file!.read(4);
        print(
          'Size bytes: ${sizeBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
        );

        // For NTI format, read length as big-endian 16-bit value (matching C++ code)
        int recordLen =
            sizeBytes[1] + sizeBytes[0] * 256; // Big-endian as in C++
        int continueFlag = sizeBytes[3]; // Continue flag is in byte 3
        print('Record length: $recordLen, continue flag: $continueFlag');

        // Skip type
        await file!.setPosition(await file!.position() + 2);
        print('Skipped type, now at position ${await file!.position()}');

        List<int> allData = [];
        recordLen = recordLen - 6; // 4 for len, 2 for type
        print('Adjusted record length: $recordLen');

        if (continueFlag == 1) {
          print('Multi-block record detected');
          while (true) {
            print('Reading $recordLen bytes');
            final data = await file!.read(recordLen);
            allData.addAll(data);
            print('Read ${data.length} bytes, total: ${allData.length}');

            // Read next block header to get the new continue flag
            final nextSizeBytes = await file!.read(4);
            recordLen = nextSizeBytes[1] + nextSizeBytes[0] * 256; // Big-endian
            recordLen = recordLen - 4;
            continueFlag = nextSizeBytes[3]; // Update continue flag
            print('Next block: length=$recordLen, continue=$continueFlag');

            // Check if this is the last block (continueFlag == 2 means last block)
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

        recordData = Uint8List.fromList(allData);
        print('Total record data: ${recordData.length} bytes');
      }

      // Parse the data format specification
      await _parseDataFormatSpec(recordData);
    } catch (e) {
      print('Error reading Data Format Specification: $e');
    }
  }

  // Parse Data Format Specification data (converted from C++ logic)
  Future<void> _parseDataFormatSpec(Uint8List data) async {
    try {
      print('_parseDataFormatSpec called with ${data.length} bytes');
      int index = 0;

      // Skip initial bytes for Russian format
      if (fileType == LisConstants.fileTypeLis) {
        index = 2;
        print('Russian format: skipping 2 initial bytes');
      }

      datumBlocks.clear();
      print('Cleared datumBlocks, starting to parse entry blocks');

      // Read entry blocks
      while (index < data.length - 1) {
        if (index >= data.length) break;

        final entryType = data[index++];
        print('Entry type: $entryType at index ${index - 1}');

        if (entryType == 0) {
          print('Found end of entry blocks');
          break; // End of entry blocks
        }

        if (index + 1 >= data.length) {
          print('Not enough data for entry size and repr code');
          break;
        }

        final size = data[index++];
        final reprCode = data[index++];

        if (index + size > data.length) {
          print('Not enough data for entry data of size $size');
          break;
        }

        final entryData = data.sublist(index, index + size);
        index += size;

        final value = CodeReader.readCode(entryData, reprCode, size);
        print('Entry $entryType: value=$value');

        switch (entryType) {
          case 1:
            dataFormatSpec.dataRecordType = value.toInt();
            break;
          case 2:
            dataFormatSpec.datumSpecBlockType = value.toInt();
            break;
          case 3:
            dataFormatSpec.dataFrameSize = value.toInt();
            print('Set dataFrameSize to ${dataFormatSpec.dataFrameSize}');
            break;
          case 4:
            dataFormatSpec.direction = value.toInt();
            break;
          case 8:
            dataFormatSpec.frameSpacing = value;
            break;
          case 9:
            dataFormatSpec.frameSpacingUnit = value.toInt();
            break;
          case 12:
            dataFormatSpec.absentValue = value;
            break;
          case 13:
            dataFormatSpec.depthRecordingMode = value.toInt();
            break;
          case 14:
            dataFormatSpec.depthUnit = value.toInt();
            break;
          case 15:
            dataFormatSpec.depthRepr = value.toInt();
            break;
        }
      }

      print(
        'Finished parsing entry blocks at index $index, data.length=${data.length}',
      );

      // Skip to datum spec blocks
      if (index < data.length) {
        if (index + 1 < data.length) {
          final size = data[index++];
          final reprCode = data[index++];
          print('Skipping entry: size=$size, reprCode=$reprCode');
          index += size; // Skip this entry
        }

        // Calculate number of datum spec blocks
        int remaining = data.length - index;
        print('Remaining bytes for datum blocks: $remaining');

        if (fileType == LisConstants.fileTypeNti) {
          remaining -= 6; // Account for NTI header
          print('NTI format: adjusted remaining to $remaining');
        }

        int numBlocks = remaining ~/ 40; // Each block is 40 bytes
        print('Calculated $numBlocks datum spec blocks');

        // Parse datum spec blocks
        for (int i = 0; i < numBlocks && index + 40 <= data.length; i++) {
          final blockData = data.sublist(index, index + 40);
          final datumBlock = _parseDatumSpecBlock(blockData, i);
          if (datumBlock != null) {
            datumBlocks.add(datumBlock);
            print('Added datum block: ${datumBlock.mnemonic}');
          }
          index += 40;
        }
      }

      // Calculate data record range if not already set
      if (startDataRec < 0) {
        await _findDataRecordRange();
      }

      print('Parsed ${datumBlocks.length} datum spec blocks');
      for (var block in datumBlocks) {
        print(
          '  ${block.mnemonic}: ${block.units}, size=${block.size}, reprCode=${block.reprCode}',
        );
      }
    } catch (e) {
      print('Error parsing data format spec: $e');
    }
  }

  // Parse individual Datum Spec Block (converted from C++ logic)
  DatumSpecBlock? _parseDatumSpecBlock(Uint8List data, int offset) {
    try {
      int index = 0;

      // Read mnemonic (4 bytes)
      final mnemonicBytes = data.sublist(index, index + 4);
      index += 4;
      String mnemonic = String.fromCharCodes(
        mnemonicBytes,
      ).trim().replaceAll('\x00', '');

      // Handle duplicate DEPT
      if (offset > 0 && mnemonic == 'DEPT') {
        mnemonic = 'DEP1';
      }

      // Read service ID (6 bytes)
      final serviceIdBytes = data.sublist(index, index + 6);
      index += 6;
      String serviceId = String.fromCharCodes(
        serviceIdBytes,
      ).trim().replaceAll('\x00', '');

      // Read service order number (8 bytes)
      final serviceOrderBytes = data.sublist(index, index + 8);
      index += 8;
      String serviceOrderNb = String.fromCharCodes(
        serviceOrderBytes,
      ).trim().replaceAll('\x00', '');

      // Read units (4 bytes)
      final unitsBytes = data.sublist(index, index + 4);
      index += 4;
      String units = String.fromCharCodes(
        unitsBytes,
      ).trim().replaceAll('\x00', '');

      // Skip API codes (4 bytes)
      index += 4;

      // Read file number (2 bytes) - Big-endian format
      final fileNb = data[index] * 256 + data[index + 1];
      index += 2;

      // Read size (2 bytes) - Big-endian format
      final size = data[index] * 256 + data[index + 1];
      index += 2;

      // Debug logging for WF datums
      if (mnemonic.startsWith('WF') ||
          mnemonic == 'TIME' ||
          mnemonic == 'SPEE') {
        print('=== Datum $mnemonic Debug ===');
        print('  Raw size bytes: [${data[index - 2]}, ${data[index - 1]}]');
        print('  Calculated size: $size');
      }

      // Skip 3 bytes
      index += 3;

      // Read number of samples (1 byte)
      final nbSample = data[index];
      index += 1;

      // Read representation code (1 byte)
      final reprCode = data[index];
      index += 1;

      // Calculate derived values
      final codeSize = CodeReader.getCodeSize(reprCode);
      final dataItemNum = size ~/ codeSize;
      final realSize = dataItemNum ~/ (nbSample > 0 ? nbSample : 1);

      // Debug logging continued
      if (mnemonic.startsWith('WF') ||
          mnemonic == 'TIME' ||
          mnemonic == 'SPEE') {
        print('  nbSample: $nbSample');
        print('  reprCode: $reprCode');
        print('  codeSize: $codeSize');
        print('  dataItemNum: $dataItemNum (size=$size / codeSize=$codeSize)');
        print('  realSize: $realSize');
        print('=== End $mnemonic Debug ===');
      }

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

  // ==================== DATA READING METHODS ====================

  // Get all data for a specific data record (converted from C++ GetAllData)
  Future<List<double>> getAllData(int currentDataRec) async {
    print('getAllData called with currentDataRec=$currentDataRec');
    print('datumBlocks.length = ${datumBlocks.length}');
    print('dataFSRIdx = $dataFSRIdx');

    if (file == null ||
        currentDataRec < 0 ||
        currentDataRec >= lisRecords.length) {
      print('Returning empty list - invalid conditions');
      return [];
    }

    final lisRecord = lisRecords[currentDataRec];
    if (lisRecord.type != 0) {
      print('Returning empty list - not a data record');
      return []; // Not a data record
    }

    try {
      final oldPosition = await file!.position();

      // Calculate curve number (following C++ logic)
      int curveNum = 0;
      for (var datum in datumBlocks) {
        if (datum.size <= 4) {
          curveNum += 1; // Single value datum contributes 1
        } else {
          curveNum += datum.dataItemNum; // Array datum contributes all elements
        }
      }

      if (dataFormatSpec.depthRecordingMode == 0) {
        curveNum -= 1; // Depth per frame, subtract 1
      }

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

        print(
          'Russian LIS: fileSize=$fileSize, currentPos=$currentPos, recordLen=$recordLen',
        );
        print('Available bytes: ${fileSize - currentPos}');

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

        print(
          'Russian LIS: frameNum=$frameNum, actualDataSize=$actualDataSize, byteDataIdx=$byteDataIdx',
        );
        print('dataFormatSpec.dataFrameSize=${dataFormatSpec.dataFrameSize}');

        // Debug datum block sizes
        int totalExpectedSize = 0;
        for (int i = 0; i < datumBlocks.length; i++) {
          final datum = datumBlocks[i];
          print(
            'Datum $i: ${datum.mnemonic}, size=${datum.size}, reprCode=${datum.reprCode}, dataItemNum=${datum.dataItemNum}',
          );
          totalExpectedSize += datum.size;
        }
        print('Total expected size from datum blocks: $totalExpectedSize');
        print(
          'Expected per frame: ${totalExpectedSize}/${frameNum} = ${totalExpectedSize / frameNum}',
        );

        for (int frame = 0; frame < frameNum; frame++) {
          print('=== Starting frame $frame, byteDataIdx=$byteDataIdx ===');

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
              print(
                'Bounds check failed at datum $i (${datum.mnemonic}): byteDataIdx=$byteDataIdx, actualBytesNeeded=$actualBytesNeeded, actualDataSize=$actualDataSize',
              );

              // Let's see exactly where we are
              print(
                'Position breakdown: frame=$frame, datum=$i, expected_end=${byteDataIdx + actualBytesNeeded}',
              );
              print(
                'Previous positions: frame=0 should use ${frame * dataFormatSpec.dataFrameSize} + depth_offset',
              );

              print('Breaking out of frame $frame at datum $i');
              break; // Exit if we don't have enough data
            }

            if (datum.size <= 4) {
              // Single value datum - read the entire size (following C++ logic)
              final oldByteDataIdx = byteDataIdx;
              final entryBytes = byteData.sublist(
                byteDataIdx,
                byteDataIdx + datum.size,
              );
              byteDataIdx += datum.size;

              // Debug byteDataIdx increment for single value datums
              if (frame == 0 && i <= 10) {
                print(
                  'Single datum ${datum.mnemonic}: byteDataIdx was $oldByteDataIdx, now $byteDataIdx (added ${datum.size})',
                );
              }

              final value = CodeReader.readCode(
                entryBytes,
                datum.reprCode,
                datum.size,
              );
              final finalValue =
                  (value - dataFormatSpec.absentValue).abs() < 0.00001
                  ? double.nan
                  : value;

              // Debug ACHV values specifically
              if (datum.mnemonic == 'ACHV' && frame == 0) {
                print(
                  'DEBUG READ: ACHV frame 0 raw value: $value, final: $finalValue at position $oldByteDataIdx',
                );
                print('DEBUG READ: entryBytes = $entryBytes');
              }

              if (fileDataIdx < fileData.length) {
                fileData[fileDataIdx++] = finalValue;
              }
            } else {
              // Handle multi-value arrays - following C++ logic, read ALL elements in one frame
              final codeSize = CodeReader.getCodeSize(datum.reprCode);
              final numElements =
                  datum.size ~/ codeSize; // Calculate number of elements
              final oldByteDataIdx = byteDataIdx;

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

              // Debug array datum processing
              if (frame == 0 && i <= 10) {
                print(
                  'Array datum ${datum.mnemonic}: byteDataIdx was $oldByteDataIdx, now $byteDataIdx (added ${datum.size} for $numElements elements)',
                );
              }
            }
          }

          // Skip depth in depth-per-frame mode
          if (dataFormatSpec.depthRecordingMode == 0) {
            final depthSize = CodeReader.getCodeSize(dataFormatSpec.depthRepr);
            print(
              '=== End of frame $frame: byteDataIdx before depth skip=$byteDataIdx, depthSize=$depthSize ===',
            );
            if (byteDataIdx + depthSize > actualDataSize) {
              print(
                'Depth skip bounds check failed: byteDataIdx=$byteDataIdx, depthSize=$depthSize, actualDataSize=$actualDataSize',
              );
              break; // Exit frame loop if no more data
            }
            byteDataIdx += depthSize;
            print('=== After depth skip: byteDataIdx=$byteDataIdx ===');
          }

          print(
            '=== Completed frame $frame, final byteDataIdx=$byteDataIdx ===',
          );
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
        print('File not open for updating');
        return false;
      }

      // Find the datum for this column
      final datum = datumBlocks.firstWhere(
        (d) => d.mnemonic == columnName,
        orElse: () => throw Exception('Column $columnName not found'),
      );

      // Skip DEPTH column and array data for safety
      if (columnName == 'DEPTH' || datum.size > 4) {
        print('Cannot update DEPTH column or array data');
        return false;
      }

      // Get the actual record index in the data records range
      final actualRecordIndex = startDataRec + recordIndex;
      if (actualRecordIndex < startDataRec || actualRecordIndex > endDataRec) {
        print('Record index out of range: $actualRecordIndex');
        return false;
      }

      // Calculate the position in the raw data
      final allData = await getAllData(actualRecordIndex);
      if (allData.isEmpty) {
        print('No data found for record $actualRecordIndex');
        return false;
      }

      final frameNum = getFrameNum(actualRecordIndex);
      if (frameIndex >= frameNum) {
        print('Frame index out of range: $frameIndex >= $frameNum');
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
        print('Data index out of bounds: $currentIndex >= ${allData.length}');
        return false;
      }

      // Store the change for later file writing
      final changeKey = '${actualRecordIndex}_${frameIndex}_${columnName}';
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
          'Stored pending change: $changeKey = $newValue (was ${allData[currentIndex]})',
        );
        return true;
      } else {
        // Update existing pending change
        _pendingChanges[changeKey]!['newValue'] = newValue;
        print('Updated pending change: $changeKey = $newValue');
        return true;
      }
    } catch (e) {
      print('Error updating data value: $e');
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

      // Create a backup copy first
      final backupPath = '$fileName.backup';
      await File(fileName).copy(backupPath);
      print('Created backup file: $backupPath');

      // Read entire file into memory
      final originalBytes = await File(fileName).readAsBytes();
      final modifiedBytes = Uint8List.fromList(originalBytes);

      // Process each pending change
      for (final entry in _pendingChanges.entries) {
        final change = entry.value;
        final actualRecordIndex = change['recordIndex'] as int;
        final frameIndex = change['frameIndex'] as int;
        final newValue = change['newValue'] as double;
        final datum = change['datum'] as DatumSpecBlock;

        // Calculate the byte position in the file and update in memory
        final success = _updateBytesInMemory(
          modifiedBytes,
          actualRecordIndex,
          frameIndex,
          datum,
          newValue,
        );

        if (!success) {
          print('Failed to update change for ${entry.key}');
          // Continue with other changes rather than failing completely
        }
      }

      // Write the modified bytes back to file
      final originalFileSize = await File(fileName).length();
      print('Original file size: $originalFileSize bytes');
      print('Modified bytes length: ${modifiedBytes.length} bytes');

      // CRITICAL FIX: Close the file handle before writing to avoid conflicts
      if (file != null) {
        await file!.close();
        print('DEBUG: Closed file handle before writing');
      }

      await File(fileName).writeAsBytes(modifiedBytes);
      print('DEBUG: Written modified bytes to file');

      // Re-open the file handle
      file = await File(fileName).open(mode: FileMode.read);
      print('DEBUG: Re-opened file handle after writing');

      final newFileSize = await File(fileName).length();
      print('New file size after write: $newFileSize bytes');

      print('Successfully saved ${_pendingChanges.length} changes to file');
      print('========================================');
      print('SAVE COMPLETED SUCCESSFULLY!');
      print('========================================');
      print('');
      _pendingChanges.clear();
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
        'DEBUG: Found ${dataRecords.length} data records, startDataRec=$startDataRec',
      );

      // Calculate which data record this change belongs to
      final dataRecordIndex = actualRecordIndex - startDataRec;
      if (dataRecordIndex < 0 || dataRecordIndex >= dataRecords.length) {
        print(
          'Data record index out of bounds: $dataRecordIndex (range: 0-${dataRecords.length - 1})',
        );
        return false;
      }

      final lisRecord = dataRecords[dataRecordIndex];
      print(
        'DEBUG: Using data record at index $dataRecordIndex, addr=${lisRecord.addr}',
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
    try {
      print('DEBUG ENCODE: input value=$value');

      if (value == 0.0) {
        final result = Uint8List.fromList([0, 0, 0, 0]);
        print('DEBUG ENCODE: zero -> bytes=[${result.join(', ')}]');
        return result;
      }

      bool isNegative = value < 0;
      double absValue = value.abs();

      // Find exponent and fraction to recreate the C++ ReadCode logic
      // C++ positive: lExponent = pow(2, ntemp-128), fResult = fFraction * lExponent
      // C++ negative: lExponent = pow(2, 127-ntemp), fResult = (-1) * fFraction * lExponent

      double targetFraction;
      int exponentBits;

      if (isNegative) {
        // For negative: find ntemp such that absValue = fFraction * pow(2, 127-ntemp)
        // Rearrange: ntemp = 127 - log2(absValue/fFraction)
        // Assume fFraction around 0.5-1.0 range
        targetFraction = absValue;
        exponentBits = 127;

        // Normalize fraction to [0.5, 1.0) range
        while (targetFraction >= 1.0) {
          targetFraction /= 2.0;
          exponentBits--;
        }
        while (targetFraction < 0.5) {
          targetFraction *= 2.0;
          exponentBits++;
        }
      } else {
        // For positive: find ntemp such that absValue = fFraction * pow(2, ntemp-128)
        // Rearrange: ntemp = 128 + log2(absValue/fFraction)
        targetFraction = absValue;
        exponentBits = 128;

        // Normalize fraction to [0.5, 1.0) range
        while (targetFraction >= 1.0) {
          targetFraction /= 2.0;
          exponentBits++;
        }
        while (targetFraction < 0.5) {
          targetFraction *= 2.0;
          exponentBits--;
        }
      }

      // Clamp exponent to valid range
      exponentBits = exponentBits.clamp(0, 255);

      // Convert fraction to 23-bit mantissa using C++ algorithm
      // C++ uses: fFactor=0.5, checks if(ntemp>=0x80000000), fFraction+=fFactor, fFactor/=2
      int mantissaBits = 0;
      double remainingFraction = targetFraction;
      double bitValue = 0.5;

      for (int i = 22; i >= 0; i--) {
        // MSB first
        if (remainingFraction >= bitValue) {
          mantissaBits |= (1 << i);
          remainingFraction -= bitValue;
        }
        bitValue /= 2.0;
      }

      // Handle negative numbers - C++ does complement operation
      if (isNegative) {
        // C++ negative: ntemp=~ntemp; ntemp=ntemp+1;
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
    } catch (e) {
      print('Error encoding Russian LIS float: $e');
      return Uint8List.fromList([0, 0, 0, 0]);
    }
  }
}
