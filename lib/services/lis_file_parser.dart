import 'dart:io';
// Removed unused import 'dart:math'
import 'dart:typed_data';

import '../constants/lis_constants.dart';
import '../models/blank_record.dart';
import '../models/datum_spec_block.dart';
import '../models/entry_block.dart';
import '../models/file_header_record.dart';
import '../models/lis_record.dart';
import '../models/well_info_block.dart';
import 'code_reader.dart';

class LisFileParser {
  double parseTimeToSeconds(String timeStr) {
    final parts = timeStr.split(':').map((e) => e.trim()).toList();
    double seconds = 0;
    if (parts.length == 5) {
      seconds += (double.tryParse(parts[0]) ?? 0) * 86400;
      seconds += (double.tryParse(parts[1]) ?? 0) * 3600;
      seconds += (double.tryParse(parts[2]) ?? 0) * 60;
      seconds += double.tryParse(parts[3]) ?? 0;
      seconds += (double.tryParse(parts[4]) ?? 0) / 1000.0;
    } else if (parts.length == 4) {
      seconds += (double.tryParse(parts[0]) ?? 0) * 86400;
      seconds += (double.tryParse(parts[1]) ?? 0) * 3600;
      seconds += (double.tryParse(parts[2]) ?? 0) * 60;
      seconds += double.tryParse(parts[3]) ?? 0;
    } else if (parts.length == 3) {
      seconds += (double.tryParse(parts[0]) ?? 0) * 3600;
      seconds += (double.tryParse(parts[1]) ?? 0) * 60;
      seconds += double.tryParse(parts[2]) ?? 0;
    } else if (parts.length == 2) {
      seconds += (double.tryParse(parts[0]) ?? 0) * 60;
      seconds += double.tryParse(parts[1]) ?? 0;
    } else if (parts.length == 1) {
      seconds += double.tryParse(parts[0]) ?? 0;
    }
    return seconds;
  }

  Future<(int, String?)> mergeDepthFromTxt({
    required String txtContent,
    required List<Map<String, dynamic>> tableData,
    required List<String> columnNames,
  }) async {
    try {
      final lines = txtContent
          .split(RegExp(r'\r?\n'))
          .where((l) => l.trim().isNotEmpty)
          .toList();
      if (lines.length < 2) {
        return (0, 'File TXT không hợp lệ!');
      }
      int headerIdx = -1;
      List<String> txtHeader = [];
      for (int i = 0; i < lines.length; ++i) {
        final cols = lines[i]
            .split(RegExp(r'\s+|,|;|\t'))
            .map((e) => e.trim().toUpperCase())
            .toList();
        if (cols.contains('TIME') &&
            (cols.contains('DEPTH') || cols.contains('DEPT'))) {
          headerIdx = i;
          txtHeader = lines[i]
              .split(RegExp(r'\s+|,|;|\t'))
              .map((e) => e.trim())
              .toList();
          break;
        }
      }
      if (headerIdx == -1) {
        return (0, 'Không tìm thấy dòng header chứa TIME và DEPTH!');
      }
      final timeIdx = txtHeader.indexWhere((c) => c.toUpperCase() == 'TIME');
      int depthIdx = txtHeader.indexWhere((c) => c.toUpperCase() == 'DEPTH');
      if (depthIdx == -1) {
        depthIdx = txtHeader.indexWhere((c) => c.toUpperCase() == 'DEPT');
      }
      if (timeIdx == -1 || depthIdx == -1) {
        return (0, 'File TXT thiếu cột TIME hoặc DEPTH!');
      }

      final Map<String, String> timeToDepth = {};
      for (var i = headerIdx + 1; i < lines.length; ++i) {
        final row = lines[i].split(RegExp(r'\s+|,|;|\t'));
        if (row.length > depthIdx && row.length > timeIdx) {
          final timeSec = parseTimeToSeconds(row[timeIdx]);
          timeToDepth[timeSec.toString()] = row[depthIdx];
        }
      }
      int matchCount = 0;
      final targetCol = columnNames.length > 1 ? columnNames[1] : 'DEPT';
      int framesPerRecord = 1;
      if (startDataRec >= 0 && endDataRec >= startDataRec) {
        framesPerRecord = getFrameNum(startDataRec);
        if (framesPerRecord <= 0) framesPerRecord = 1;
      }

      // Chuẩn hóa dữ liệu sau khi merge DEPTH
      //normalizeTableData(tableData, columnNames);

      for (int i = tableData.length - 1; i >= 0; --i) {
        final row = tableData[i];
        final rawTime = row['TIME'];
        if (rawTime == null) {
          continue;
        }
        double? timeNum;
        if (rawTime is num) {
          timeNum = rawTime.toDouble();
        } else {
          timeNum = double.tryParse(rawTime.toString());
        }
        if (timeNum == null) {
          continue;
        }
        final timeVal = (timeNum / 1000).toString();
        if (timeToDepth.containsKey(timeVal)) {
          final newDepth = timeToDepth[timeVal];
          if (newDepth != null && newDepth != row[targetCol]?.toString()) {
            tableData[i][targetCol] = newDepth;
            final recordIndex = i ~/ framesPerRecord;
            final frameIndex = i % framesPerRecord;
            await updateDataValue(
              recordIndex: recordIndex,
              frameIndex: frameIndex,
              columnName: targetCol,
              newValue: double.tryParse(newDepth) ?? 0.0,
            );
            matchCount++;
          }
        } else {
          tableData.removeAt(i);
          markRowDeleted(i);
        }
      }

      return (matchCount, null);
    } catch (e) {
      return (0, 'Lỗi merge: $e');
    }
  }

  /// Chuẩn hóa, sắp xếp, tìm step, hồi quy tuyến tính cho DEPT
  void normalizeTableData(
    List<Map<String, dynamic>> data,
    List<String> columnNames,
  ) {
    if (data.isEmpty || data.length < 2) return;

    // 1. Xác định xu hướng chính (tăng hoặc giảm)
    final deptCol = columnNames.length > 1 ? columnNames[1] : 'DEPT';
    final deptValues = data
        .map((row) => double.tryParse(row[deptCol]?.toString() ?? '') ?? 0.0)
        .toList();
    int increaseCount = 0, decreaseCount = 0;
    for (int i = 1; i < deptValues.length; i++) {
      if (deptValues[i] > deptValues[i - 1]) increaseCount++;
      if (deptValues[i] < deptValues[i - 1]) decreaseCount++;
    }
    final isIncreasing = increaseCount >= decreaseCount;
    print(
      '[DEBUG][normalizeTableData] Xu hướng chính: ${isIncreasing ? 'Tăng' : 'Giảm'} (increaseCount=$increaseCount, decreaseCount=$decreaseCount)',
    );

    // 2. Sắp xếp dữ liệu DEPT theo xu hướng chính (in-place)
    data.sort((a, b) {
      final da = double.tryParse(a[deptCol]?.toString() ?? '') ?? 0.0;
      final db = double.tryParse(b[deptCol]?.toString() ?? '') ?? 0.0;
      return isIncreasing ? da.compareTo(db) : db.compareTo(da);
    });
    print(
      '[DEBUG][normalizeTableData] Dữ liệu đã sắp xếp theo xu hướng $deptCol. Giá trị đầu: ${data.first[deptCol]}, cuối: ${data.last[deptCol]}',
    );

    // 3. Tìm xu hướng step chính
    final steps = <double>[];
    for (int i = 1; i < data.length; i++) {
      final prev =
          double.tryParse(data[i - 1][deptCol]?.toString() ?? '') ?? 0.0;
      final curr = double.tryParse(data[i][deptCol]?.toString() ?? '') ?? 0.0;
      steps.add((curr - prev).abs());
    }
    print(
      '[DEBUG][normalizeTableData] Các step giữa các giá trị DEPT: ${steps.take(10).toList()}...',
    );
    double mainStep = 0.0;
    if (steps.isNotEmpty) {
      final stepCounts = <double, int>{};
      for (final s in steps) {
        final rounded = double.parse(s.toStringAsFixed(2));
        stepCounts[rounded] = (stepCounts[rounded] ?? 0) + 1;
      }
      mainStep = stepCounts.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      print(
        '[DEBUG][normalizeTableData] Step chính (mode): $mainStep, counts: $stepCounts',
      );
    }

    // 4. Ép về step chuẩn (0.1, 0.5, 1, 10, 20 ...)
    final allowedSteps = [0.1, 0.5, 1, 2, 5, 10, 20, 50, 100];
    double chosenStep = allowedSteps
        .reduce((a, b) => (mainStep - a).abs() < (mainStep - b).abs() ? a : b)
        .toDouble();
    print('[DEBUG][normalizeTableData] Step chuẩn được chọn: $chosenStep');

    // 5. Làm tròn Depth đầu tiên
    double firstDepth =
        double.tryParse(data.first[deptCol]?.toString() ?? '') ?? 0.0;
    firstDepth = double.parse(firstDepth.toStringAsFixed(2));
    print(
      '[DEBUG][normalizeTableData] Depth đầu tiên sau làm tròn: $firstDepth',
    );

    // 6. Hồi quy tuyến tính để xử lý DEPT theo step chính (in-place)
    for (int i = 0; i < data.length; i++) {
      final newDepth = isIncreasing
          ? firstDepth + i * chosenStep
          : firstDepth - i * chosenStep;
      data[i][deptCol] = newDepth.toStringAsFixed(3);
    }
    print(
      '[DEBUG][normalizeTableData] Đã hồi quy tuyến tính DEPT, ví dụ 10 dòng đầu:',
    );
    for (int i = 0; i < data.length && i < 10; i++) {
      print('Row $i: ${data[i][deptCol]}');
    }
    // Ghi chú: Các bước xử lý gồm xác định xu hướng, sắp xếp, tìm step, ép về step, làm tròn depth đầu, hồi quy tuyến tính
  }

  /// Ghi giá trị Depth vào tất cả các data record (type 0), mỗi record giảm dần 0.5
  Future<void> setDepthForAllRecords(File fileLIS, double startDepth) async {
    if (lisRecords.isEmpty) return;
    final dataRecords = lisRecords.where((r) => r.type == 0).toList();
    if (dataRecords.isEmpty) return;

    // Đọc toàn bộ file vào bộ nhớ
    final fileBytes = await fileLIS.readAsBytes();
    double depth = startDepth;
    for (final record in dataRecords) {
      // Bỏ qua 2 byte header, ghi depth vào 4 byte tiếp theo
      final offset = record.addr + 2;
      if (offset + 4 > fileBytes.length) continue;
      // Mã hóa depth theo DepthRepr
      final depthBytes = CodeReader.encode(depth, entryBlock.nDepthRepr, 4);
      for (int i = 0; i < 4; i++) {
        fileBytes[offset + i] = depthBytes[i];
      }
      depth -= 5;
    }
    // Ghi lại file mới
    final filePath = fileLIS.path;
    final extIndex = filePath.lastIndexOf('.');
    final now = DateTime.now();
    final timeStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final newFileName = extIndex > 0
        ? '${filePath.substring(0, extIndex)}_depth_$timeStr${filePath.substring(extIndex)}'
        : '${filePath}_depth_$timeStr';
    await File(newFileName).writeAsBytes(fileBytes);
    print(
      'Đã ghi giá trị Depth vào tất cả data record, file mới: $newFileName',
    );
  }

  /// Ghi tableData ra file LIS mới, tự động tạo tên file mới dựa trên file gốc và thời gian
  Future<bool> saveTableDataToNewFileAuto(
    List<Map<String, dynamic>> tableData,
  ) async {
    if (file == null || tableData.isEmpty) {
      print('[DEBUG][SAVE] file is null hoặc tableData rỗng');
      return false;
    }

    normalizeTableData(tableData, getColumnNames());

    // Đọc toàn bộ file gốc vào buffer
    final originalFile = File(fileName);
    final originalBytes = await originalFile.readAsBytes();
    // Tạo tên file mới
    final now = DateTime.now();
    final baseName = fileName.split(Platform.pathSeparator).last;
    final dirName = fileName.substring(
      0,
      fileName.lastIndexOf(Platform.pathSeparator),
    );
    final extIdx = baseName.lastIndexOf('.');
    final namePart = extIdx > 0 ? baseName.substring(0, extIdx) : baseName;
    final extPart = extIdx > 0 ? baseName.substring(extIdx) : '.LIS';
    final timeStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final newFileName =
        '$dirName${Platform.pathSeparator}${namePart}_saved_$timeStr$extPart';
    // Lấy danh sách các record type 0
    final dataRecords = lisRecords.where((r) => r.type == 0).toList();
    if (dataRecords.isEmpty) {
      print('[DEBUG][SAVE] Không tìm thấy dataRecords type 0');
      return false;
    }
    // Tính số frame cho mỗi record
    int totalFrames = 0;
    final framesPerRecord = <int>[];
    for (int i = 0; i < dataRecords.length; i++) {
      final frameNum = getFrameNum(startDataRec + i);
      if (i == 0) {
        print('[DEBUG][SAVE] Frame num record 0: $frameNum');
      }
      framesPerRecord.add(frameNum);
      totalFrames += frameNum;
    }
    print(
      '[DEBUG][SAVE] Tổng số frame: $totalFrames, tableData.length=${tableData.length}, dataRecords.length=${dataRecords.length}',
    );
    if (tableData.length != totalFrames) {
      print(
        '[DEBUG][SAVE][CẢNH BÁO] tableData.length (${tableData.length}) != tổng số frame ($totalFrames)',
      );
    }
    int rowIdx = 0;
    for (int recIdx = 0; recIdx < dataRecords.length; recIdx++) {
      final record = dataRecords[recIdx];
      final frameNum = framesPerRecord[recIdx];
      final recordBytes = <int>[];
      //Xử lý Ghi 4 byte Depth đầu tiên (dùng entryBlock.nDepthRepr)
      // 1. Ghi 4 byte Depth đầu tiên (dùng entryBlock.nDepthRepr)
      /*
        final depthValue = row['DEPTH'];
        final depthRepr = entryBlock.nDepthRepr;
        final depthSize = CodeReader.getCodeSize(depthRepr);
        try {
          if (depthValue == null ||
              (depthValue is String && depthValue == 'NULL')) {
            recordBytes.addAll(
              CodeReader.encode32BitFloat(entryBlock.fAbsentValue),
            );
          } else if (depthValue is num) {
            recordBytes.addAll(
              CodeReader.encode32BitFloat(depthValue.toDouble()),
            );
          } else if (depthValue is String) {
            final parsed = double.tryParse(depthValue);
            if (parsed != null) {
              recordBytes.addAll(CodeReader.encode32BitFloat(parsed));
            } else {
              recordBytes.addAll(
                CodeReader.encode32BitFloat(entryBlock.fAbsentValue),
              );
            }
          } else {
            recordBytes.addAll(
              CodeReader.encode32BitFloat(entryBlock.fAbsentValue),
            );
          }
        } catch (e) {
          recordBytes.addAll(
            CodeReader.encode32BitFloat(entryBlock.fAbsentValue),
          );
        }*/
      // 2. Ghi các frameData
      for (int frame = 0; frame < frameNum; frame++) {
        if (rowIdx >= tableData.length) {
          print('[DEBUG][SAVE][CẢNH BÁO] rowIdx vượt quá tableData.length');
          break;
        }
        final row = tableData[rowIdx];
        // Ghi các trường dữ liệu cho từng frame
        for (final col in getColumnNames()) {
          if (col == 'DEPTH') continue; // DEPTH đã được ghi riêng
          final value = row[col];
          final datum = datumBlocks.firstWhere(
            (d) => d.mnemonic == col,
            orElse: () => DatumSpecBlock.empty(col),
          );
          final reprCode = datum.reprCode;
          final size = datum.size;

          try {
            // Xử lý trường kiểu mảng (array)
            if (value is Map &&
                value['isArray'] == true &&
                value['data'] is List) {
              final codeSize = CodeReader.getCodeSize(reprCode);
              final arr = value['data'] as List;
              final numElements = size ~/ codeSize;
              print(
                '[DEBUG][SAVE][ARRAY] col=$col reprCode=$reprCode size=$size codeSize=$codeSize numElements=$numElements',
              );
              for (int i = 0; i < numElements; i++) {
                final element = (i < arr.length && arr[i] != null)
                    ? arr[i]
                    : entryBlock.fAbsentValue;
                final encoded = CodeReader.encode(
                  element is num ? element : entryBlock.fAbsentValue,
                  reprCode,
                  codeSize,
                );
                recordBytes.addAll(encoded);
              }
              continue;
            }

            // Xử lý giá trị null hoặc 'NULL'
            if (value == null || (value is String && value == 'NULL')) {
              final encoded = CodeReader.encode(
                entryBlock.fAbsentValue,
                reprCode,
                CodeReader.getCodeSize(reprCode),
              );
              recordBytes.addAll(encoded);
              continue;
            }

            // Xử lý giá trị kiểu số
            if (value is num) {
              final encoded = CodeReader.encode(
                value,
                reprCode,
                CodeReader.getCodeSize(reprCode),
              );
              recordBytes.addAll(encoded);
              continue;
            }

            // Xử lý giá trị kiểu chuỗi
            if (value is String) {
              final parsed = double.tryParse(value);
              if (parsed != null) {
                // Chuỗi là số, encode như số
                final encoded = CodeReader.encode(
                  parsed,
                  reprCode,
                  CodeReader.getCodeSize(reprCode),
                );
                recordBytes.addAll(encoded);
                continue;
              } else if (reprCode == 65) {
                // Chuỗi không phải số, encode dạng ASCII nếu reprCode là 65
                final encoded = CodeReader.encode(value, reprCode, size);
                recordBytes.addAll(encoded);
                continue;
              }
            }

            // Nếu không khớp bất kỳ trường hợp nào, ghi absent value
            final encoded = CodeReader.encode(
              entryBlock.fAbsentValue,
              reprCode,
              CodeReader.getCodeSize(reprCode),
            );
            recordBytes.addAll(encoded);
          } catch (e) {
            // Nếu có lỗi khi encode, ghi absent value
            recordBytes.addAll(
              CodeReader.encode(
                entryBlock.fAbsentValue,
                reprCode,
                CodeReader.getCodeSize(reprCode),
              ),
            );
          }
        }
        rowIdx++;
      }

      // Ghi recordBytes vào buffer gốc
      final start = record.addr + 2 + 4;
      final end = start + recordBytes.length;
      if (recIdx == 1) {
        print('RecordLength=${recordBytes.length}, start=$start, end=$end');
        print(
          'FirstRecordBytes=${recordBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).take(50).join(' ')}',
        );
      }
      if (end <= originalBytes.length) {
        for (int i = 0; i < recordBytes.length; i++) {
          originalBytes[start + i] = recordBytes[i];
        }
      } else {
        print(
          '[DEBUG][SAVE][CẢNH BÁO] Không đủ dung lượng để ghi recordBytes vào file gốc',
        );
      }
    }
    // Ghi ra file mới
    await File(newFileName).writeAsBytes(originalBytes);
    print(
      '[DEBUG][SAVE] Đã ghi xong tất cả dataRecords và frame vào file mới: $newFileName',
    );
    return true;
  }
  // LIS File Parser - converted from CLisFile C++ class

  /// Lưu tableData vào các data record (type 0), tự động xử lý nhiều frame/record
  Future<bool> saveTableDataToRecords(
    List<Map<String, dynamic>> tableData,
  ) async {
    if (file == null || tableData.isEmpty) {
      print('[DEBUG][SAVE] file is null hoặc tableData rỗng');
      return false;
    }
    // Lấy danh sách các record type 0
    final dataRecords = lisRecords.where((r) => r.type == 0).toList();
    if (dataRecords.isEmpty) {
      print('[DEBUG][SAVE] Không tìm thấy dataRecords type 0');
      return false;
    }

    // Tính số frame cho mỗi record
    int totalFrames = 0;
    final framesPerRecord = <int>[];
    for (int i = 0; i < dataRecords.length; i++) {
      final frameNum = getFrameNum(startDataRec + i);
      framesPerRecord.add(frameNum);
      totalFrames += frameNum;
    }
    print(
      '[DEBUG][SAVE] Tổng số frame: $totalFrames, tableData.length=${tableData.length}, dataRecords.length=${dataRecords.length}',
    );

    if (tableData.length != totalFrames) {
      print(
        '[DEBUG][SAVE][CẢNH BÁO] tableData.length (${tableData.length}) != tổng số frame ($totalFrames)',
      );
      // Có thể cảnh báo nhưng vẫn tiếp tục nếu tableData đủ hoặc dư
    }

    int rowIdx = 0;
    for (int recIdx = 0; recIdx < dataRecords.length; recIdx++) {
      final record = dataRecords[recIdx];
      final frameNum = framesPerRecord[recIdx];
      final recordBytes = <int>[];
      for (int frame = 0; frame < frameNum; frame++) {
        if (rowIdx >= tableData.length) {
          print('[DEBUG][SAVE][CẢNH BÁO] rowIdx vượt quá tableData.length');
          break;
        }
        final row = tableData[rowIdx];
        for (final col in getColumnNames()) {
          final value = row[col];
          final datum = datumBlocks.firstWhere(
            (d) => d.mnemonic == col,
            orElse: () => DatumSpecBlock.empty(col),
          );
          final reprCode = datum.reprCode;
          final size = datum.size;
          try {
            print(
              '[DEBUG][SAVE] recIdx=$recIdx frame=$frame col=$col value=$value reprCode=$reprCode size=$size',
            );
            // Nếu là array (kiểu Map), ghi absent value cho toàn bộ phần tử
            if (value is Map && value['isArray'] == true) {
              // Số phần tử array
              final codeSize = CodeReader.getCodeSize(reprCode);
              final numElements = size ~/ codeSize;
              final absentVal = entryBlock.fAbsentValue;
              for (int i = 0; i < numElements; i++) {
                final encoded = CodeReader.encode32BitFloat(absentVal);
                recordBytes.addAll(encoded);
              }
              continue;
            }
            // Nếu là NULL, ghi absent value
            if (value == null || (value is String && value == 'NULL')) {
              final encoded = CodeReader.encode32BitFloat(
                entryBlock.fAbsentValue,
              );
              recordBytes.addAll(encoded);
              continue;
            }
            // Nếu là số, ghi bình thường
            if (value is num) {
              final encoded = CodeReader.encode32BitFloat(value.toDouble());
              recordBytes.addAll(encoded);
              continue;
            }
            // Nếu là String số, chuyển sang double
            if (value is String) {
              final parsed = double.tryParse(value);
              if (parsed != null) {
                final encoded = CodeReader.encode32BitFloat(parsed);
                recordBytes.addAll(encoded);
                continue;
              }
            }
            // Trường hợp khác, ghi absent value
            final encoded = CodeReader.encode32BitFloat(
              entryBlock.fAbsentValue,
            );
            recordBytes.addAll(encoded);
          } catch (e) {
            print(
              '[DEBUG][SAVE][ERROR] recIdx=$recIdx frame=$frame col=$col value=$value error=$e',
            );
            recordBytes.addAll(
              CodeReader.encode32BitFloat(entryBlock.fAbsentValue),
            );
          }
        }
        rowIdx++;
      }
      print(
        '[DEBUG][SAVE][BYTES] recIdx=$recIdx bytes=${recordBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );
      await file!.setPosition(record.addr + 2); // +2 để bỏ qua header
      await file!.writeFrom(Uint8List.fromList(recordBytes));
    }
    await file!.flush();
    print('[DEBUG][SAVE] Đã ghi xong tất cả dataRecords và frame');
    return true;
  }

  /// Trả về map tên cột -> reprCode dựa trên datumBlocks
  Map<String, int> getColumnReprCodes(List<String> columnOrder) {
    final Map<String, int> result = {};
    for (final col in columnOrder) {
      if (col == 'DEPTH') {
        result[col] = entryBlock.nDepthRepr;
      } else {
        final datum = datumBlocks.firstWhere(
          (d) => d.mnemonic == col,
          orElse: () => DatumSpecBlock.empty(col),
        );
        result[col] = datum.reprCode;
      }
    }
    return result;
  }

  /// Mã hóa EntryBlock và lưu ra file LIS mới
  Future<bool> saveEntryBlockToNewFile(String newFilePath) async {
    try {
      final entryBlockBytes = encodeEntryBlock(entryBlock);
      // Đọc toàn bộ file gốc vào buffer
      final originalFile = File(fileName);
      final originalBytes = await originalFile.readAsBytes();
      // Tính offset thực tế
      int fileOffset = lisRecords[dataFSRIdx].addr + entryBlockOffset;
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
    bytes.add(entryBlock.nDataFrameSize & 0xFF); // byte thấp

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
    // final refPointBytes = ByteData(4)
    //   ..setFloat32(0, entryBlock.fDataRefPoint, Endian.little);
    // bytes.addAll(refPointBytes.buffer.asUint8List());
    final refPointBytes = CodeReader.encode(entryBlock.fDataRefPoint, 68, -1);
    bytes.addAll(refPointBytes);

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
    //final spacingBytes = _encodeRussianLisFloat(entryBlock.fFrameSpacing);
    final spacingBytes = CodeReader.encode(entryBlock.fFrameSpacing, 68, -1);
    bytes.addAll(spacingBytes);

    // Trường 9: strFrameSpacingUnit (4 byte ASCII, reprCode 65)
    bytes.add(9);
    bytes.add(4);
    bytes.add(65);
    final spacingUnitBytes = entryBlock.strFrameSpacingUnit
        .padRight(4)
        .codeUnits;
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

  // DataFormatSpec dataFormatSpec = DataFormatSpec(); // Đã thay bằng EntryBlock
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
    // entryBlock = EntryBlock(); // EntryBlock đã khởi tạo ở trên
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
        //await _openNTI(onProgress);
        await _openLIS(onProgress);
      } else {
        await _openLIS(onProgress);
      }

      // After parsing records and datum blocks, compute depth-related values
      // Set step based on frame spacing (convert to milliseconds-based integer like original C++ lStep)
      // Keep step as an integer representing frame spacing in milliseconds (consistent with original logic)
      try {
        final spacing = entryBlock.fFrameSpacing; // in original units
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

      // Removed unused local variable 'firstBytes'
      // ...existing code...

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

      // ...existing code...
    } catch (e) {
      // Error in file type detection: $e
      fileType = LisConstants.fileTypeNti; // Default to NTI on error
    }
  }

  Future<void> _openLIS(Function(double)? onProgress) async {
    // Implementation for Russian LIS format (from C++ OpenLIS method)
    if (file == null) return;

    try {
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
      // ...existing code...

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
    // ...existing code...

    if (dataFSRIdx < 0 || dataFSRIdx >= lisRecords.length) {
      // ...existing code...

      // Try to find it manually
      for (int i = 0; i < lisRecords.length; i++) {
        final record = lisRecords[i];
        // ...existing code...
        if (record.type == 64) {
          // ...existing code...
          dataFSRIdx = i;
          break;
        }
      }

      if (dataFSRIdx < 0) {
        // ...existing code...
        return;
      }
    }

    try {
      final lisRecord = lisRecords[dataFSRIdx];
      // ...existing code...

      await file!.setPosition(lisRecord.addr);
      // ...existing code...

      Uint8List recordData;

      if (fileType == LisConstants.fileTypeLis) {
        // Russian format
        final recordLen = lisRecord.length;
        recordData = Uint8List.fromList(await file!.read(recordLen));
      } else {
        // NTI format - handle multi-block
        // ...existing code...
        await file!.setPosition(lisRecord.addr + 2);

        // Read size
        final sizeBytes = await file!.read(4);
        // ...existing code...

        int recordLen = sizeBytes[1] + sizeBytes[0] * 256;
        int continueFlag = sizeBytes[3];
        // ...existing code...

        await file!.setPosition(await file!.position() + 2);
        // ...existing code...

        List<int> allData = [];
        recordLen = recordLen - 2; // DFSR chỉ có 2 byte header
        // ...existing code...

        if (continueFlag == 1) {
          // ...existing code...
          while (true) {
            // ...existing code...
            final data = await file!.read(recordLen);
            allData.addAll(data);
            // ...existing code...

            final nextSizeBytes = await file!.read(4);
            recordLen = nextSizeBytes[1] + nextSizeBytes[0] * 256;
            recordLen = recordLen - 4;
            continueFlag = nextSizeBytes[3];
            // ...existing code...

            if (continueFlag == 2) {
              // ...existing code...
              break;
            }
          }
        } else {
          // ...existing code...
          final data = await file!.read(recordLen);
          allData.addAll(data);
          // ...existing code...
        }

        // Chỉ tạo recordData từ allData.sublist(2) để loại bỏ 2 byte đầu
        recordData = Uint8List.fromList(
          allData.length > 2 ? allData.sublist(2) : [],
        );
        // ...existing code...
      }

      // Parse the data format specification
      // Luôn bỏ qua 2 byte đầu (header/padding) để EntryBlock bắt đầu từ 01 01
      await _parseDataFormatSpec(
        recordData.length > 2 ? recordData.sublist(2) : Uint8List(0),
      );
    } catch (e) {
      print('Error reading Data Format Specification: $e');
    }
  }

  // Parse Data Format Specification data (converted from C++ logic)
  Future<void> _parseDataFormatSpec(Uint8List data) async {
    // ...existing code...
    int rawIdx = 0;
    List<int> entryBlockRaw = [];
    // Lưu lại offset entryBlock (tính từ đầu file DataFormatSpec record)
    entryBlockOffset =
        0; // Nếu cần offset thực tế trong file, cần cộng thêm addr của record
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
    // ...existing code...
    int index = 0;
    entryBlock = EntryBlock();
    int entryFieldCount = 0;
    // Chỉ đọc tối đa 16 trường EntryBlock, dừng khi gặp entryType == 0 hoặc index vượt quá data
    while (index < data.length - 1 && entryFieldCount < 16) {
      if (index >= data.length) break;
      final entryType = data[index++];
      if (entryType == 0) {
        // ...existing code...
        break; // End of entry blocks
      }
      if (index + 1 >= data.length) {
        // ...existing code...
        break;
      }
      final size = data[index++];
      final reprCode = data[index++];
      if (index + size > data.length) {
        // ...existing code...
        break;
      }
      final entryData = data.sublist(index, index + size);
      // ...existing code...
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
          // ...existing code...
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
    // ...existing code...

    int nCurPos = index + 3;
    int nTotalSize = data.length;
    int offset = 0;

    // ...existing code...

    while (nCurPos < nTotalSize) {
      if (nTotalSize - nCurPos < 40) {
        print('Remaining bytes < 40, breaking: ${nTotalSize - nCurPos}');
        break;
      }

      // ...existing code...

      // Read mnemonic (4 bytes, repr code 65 - ASCII)
      if (nCurPos + 4 > nTotalSize) break;
      final mnemonicBytes = data.sublist(nCurPos, nCurPos + 4);
      String mnemonic = String.fromCharCodes(
        mnemonicBytes,
      ).trim().replaceAll('\x00', '');
      nCurPos += 4;
      // ...existing code...

      // Read service ID (6 bytes, repr code 65 - ASCII)
      if (nCurPos + 6 > nTotalSize) break;
      final serviceIdBytes = data.sublist(nCurPos, nCurPos + 6);
      String serviceId = String.fromCharCodes(
        serviceIdBytes,
      ).trim().replaceAll('\x00', '');
      nCurPos += 6;
      // ...existing code...

      // Read service order number (8 bytes, repr code 65 - ASCII)
      if (nCurPos + 8 > nTotalSize) break;
      final serviceOrderBytes = data.sublist(nCurPos, nCurPos + 8);
      String serviceOrderNb = String.fromCharCodes(
        serviceOrderBytes,
      ).trim().replaceAll('\x00', '');
      nCurPos += 8;
      // ...existing code...

      // Read units (4 bytes, repr code 65 - ASCII)
      if (nCurPos + 4 > nTotalSize) break;
      final unitsBytes = data.sublist(nCurPos, nCurPos + 4);
      String units = String.fromCharCodes(
        unitsBytes,
      ).trim().replaceAll('\x00', '');
      nCurPos += 4;
      // ...existing code...

      // Skip API Codes (4 bytes)
      nCurPos += 4;

      // Read file number (2 bytes, repr code 79 - 16-bit integer)
      if (nCurPos + 2 > nTotalSize) break;
      final fileNbBytes = data.sublist(nCurPos, nCurPos + 2);
      int fileNb = fileNbBytes[1] + (fileNbBytes[0] << 8); // Big endian
      nCurPos += 2;
      // ...existing code...

      // Read size (2 bytes, repr code 79 - 16-bit integer)
      if (nCurPos + 2 > nTotalSize) break;
      final sizeBytes = data.sublist(nCurPos, nCurPos + 2);
      int size = sizeBytes[1] + (sizeBytes[0] << 8); // Big endian
      nCurPos += 2;
      // ...existing code...

      // Skip Process Level (3 bytes)
      nCurPos += 3;

      // Read number of samples (1 byte, repr code 66 - 8-bit integer)
      if (nCurPos + 1 > nTotalSize) break;
      int nbSamples = data[nCurPos];
      nCurPos += 1;
      // ...existing code...

      // Read representation code (1 byte, repr code 66 - 8-bit integer)
      if (nCurPos + 1 > nTotalSize) break;
      int reprCode = data[nCurPos];
      nCurPos += 1;
      // ...existing code...

      // Skip Process Indication (5 bytes)
      nCurPos += 5;

      // Calculate derived values
      final codeSize = CodeReader.getCodeSize(reprCode);
      final dataItemNum = nbSamples > 0
          ? (size ~/ codeSize) ~/ nbSamples
          : (size ~/ codeSize);
      final realSize = dataItemNum;

      // ...existing code...

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

      // ...existing code...
    }

    // ...existing code...

    // Update EntryBlock with calculated values
    // Calculate total frame size from datum blocks
    int totalFrameSize = 0;
    for (final datum in datumBlocks) {
      totalFrameSize += datum.size;
    }
    if (entryBlock.nDepthRecordingMode == 0) {
      // Add depth size for depth-per-frame mode
      totalFrameSize += CodeReader.getCodeSize(entryBlock.nDepthRepr);
    }
    entryBlock.nDataFrameSize = totalFrameSize;

    // ...existing code...
  }

  // Removed unused function _parseDatumSpecBlock

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
      if (record.type == 0 && record.length > entryBlock.nDataFrameSize) {
        return i;
      }
    }
    return -1;
  }

  int _getEndDataRecordIdx() {
    for (int i = lisRecords.length - 1; i >= 0; i--) {
      final record = lisRecords[i];
      if (record.type == 0 && record.length > entryBlock.nDataFrameSize) {
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
      CodeReader.getCodeSize(entryBlock.nDepthRepr),
    );
    double depth = CodeReader.readCode(
      Uint8List.fromList(depthBytes),
      entryBlock.nDepthRepr,
      depthBytes.length,
    );

    double convertedDepth = _convertToMeter(
      depth,
      entryBlock.nOpticalDepthUnit,
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
      CodeReader.getCodeSize(entryBlock.nDepthRepr),
    );
    double depth = CodeReader.readCode(
      Uint8List.fromList(depthBytes),
      entryBlock.nDepthRepr,
      depthBytes.length,
    );

    depth = _convertToMeter(depth, entryBlock.nOpticalDepthUnit);

    int frameNum = record.length ~/ entryBlock.nDataFrameSize;

    if (entryBlock.nDirection == LisConstants.dirDown) {
      depth += (frameNum - 1) * (step / 1000.0);
    } else if (entryBlock.nDirection == LisConstants.dirUp) {
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
    lisRecords.clear();
    datumBlocks.clear();
    consBlocks.clear();
    outpBlocks.clear();
    ak73Blocks.clear();
    cb3Blocks.clear();
    toolBlocks.clear();
    chanBlocks.clear();

    // entryBlock = EntryBlock(); // Nếu cần reset entryBlock
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
    'direction': entryBlock.nDirection,
    'frameSpacing': entryBlock.fFrameSpacing.toStringAsFixed(3),
    'depthUnit': entryBlock.nOpticalDepthUnit,
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
        final depthRepr = entryBlock.nDepthRepr;
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

        currentDepth = _convertToMeter(
          currentDepth,
          entryBlock.nOpticalDepthUnit,
        );

        // Parse frames
        final frameNum = getFrameNum(currentDataRec);
        int byteDataIdx = 0;
        int fileDataIdx = 0;

        for (int frame = 0; frame < frameNum; frame++) {
          for (int i = 0; i < datumBlocks.length; i++) {
            if (i == 0 && entryBlock.nDepthRecordingMode == 0) {
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
                  (value - entryBlock.fAbsentValue).abs() < 0.00001
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
                    (value - entryBlock.fAbsentValue).abs() < 0.00001
                    ? double.nan
                    : value;

                if (fileDataIdx < fileData.length) {
                  fileData[fileDataIdx++] = finalValue;
                }
              }
            }
          }

          // Skip depth in depth-per-frame mode
          if (entryBlock.nDepthRecordingMode == 0) {
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

        final depthSize = CodeReader.getCodeSize(entryBlock.nDepthRepr);
        final depthBytes = byteData.sublist(0, depthSize);
        currentDepth = CodeReader.readCode(
          depthBytes,
          entryBlock.nDepthRepr,
          depthSize,
        );
        currentDepth = _convertToMeter(
          currentDepth,
          entryBlock.nOpticalDepthUnit,
        );

        // Parse frames for Russian format
        final frameNum = getFrameNum(currentDataRec);
        int byteDataIdx = depthSize;
        int fileDataIdx = 0;
        final actualDataSize = maxBytes; // Use the actual data we read

        for (int frame = 0; frame < frameNum; frame++) {
          for (int i = 0; i < datumBlocks.length; i++) {
            if (i == 0 && entryBlock.nDepthRecordingMode == 0) {
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
                  (value - entryBlock.fAbsentValue).abs() < 0.00001
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
                    (value - entryBlock.fAbsentValue).abs() < 0.00001
                    ? double.nan
                    : value;

                if (fileDataIdx < fileData.length) {
                  fileData[fileDataIdx++] = finalValue;
                }
              }
            }
          }

          // Skip depth in depth-per-frame mode
          if (entryBlock.nDepthRecordingMode == 0) {
            final depthSize = CodeReader.getCodeSize(entryBlock.nDepthRepr);
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
      if (entryBlock.nDepthRecordingMode == 1) {
        recordLen -= CodeReader.getCodeSize(entryBlock.nDepthRepr);
      }
    } else {
      // NTI format
      recordLen -= 6; // Subtract 6 bytes
      if (entryBlock.nDepthRecordingMode == 1) {
        recordLen -= CodeReader.getCodeSize(entryBlock.nDepthRepr);
      }
    }

    if (entryBlock.nDataFrameSize > 0) {
      return recordLen ~/ entryBlock.nDataFrameSize;
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
      if (entryBlock.nDepthRecordingMode == 0 && datum.mnemonic == 'DEPT') {
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
    // ...existing code...

    if (!isFileOpen) {
      return [];
    }

    List<Map<String, dynamic>> tableData = [];
    final columnNames = getColumnNames();

    // If we have no real data, create sample data for testing
    if (startDataRec < 0 || endDataRec < 0 || datumBlocks.isEmpty) {
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
          if (entryBlock.nDirection == LisConstants.dirDown) {
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
            if (entryBlock.nDepthRecordingMode == 0 &&
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
      // ...existing code...
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
        // ...existing code...
        return false;
      }

      // Find the datum for this column
      final datum = datumBlocks.firstWhere(
        (d) => d.mnemonic == columnName,
        orElse: () => throw Exception('Column $columnName not found'),
      );

      // Skip array data for safety, but ALLOW DEPTH/DEPT update
      if (datum.size > 4) {
        // ...existing code...
        return false;
      }

      // Get the actual record index in the data records range
      final actualRecordIndex = startDataRec + recordIndex;
      if (actualRecordIndex < startDataRec || actualRecordIndex > endDataRec) {
        // ...existing code...
        return false;
      }

      // Calculate the position in the raw data
      final allData = await getAllData(actualRecordIndex);
      if (allData.isEmpty) {
        // ...existing code...
        return false;
      }

      final frameNum = getFrameNum(actualRecordIndex);
      if (frameIndex >= frameNum) {
        // ...existing code...
        return false;
      }

      // Calculate data positioning (same logic as getTableData)
      int singleValuesPerFrame = 0;
      int arrayElementsPerFrame = 0;

      for (var d in datumBlocks) {
        if (entryBlock.nDepthRecordingMode == 0 && d.mnemonic == 'DEPT') {
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
        if (entryBlock.nDepthRecordingMode == 0 &&
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
        // ...existing code...
        return false;
      }

      // Store the change for later file writing
      final changeKey = '${actualRecordIndex}_${frameIndex}_$columnName';
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
        // ...existing code...
      } else {
        // Update existing pending change
        _pendingChanges[changeKey]!['newValue'] = newValue;
        // ...existing code...
      }
      // DEBUG: In ra index, frame, value sau khi push vào pending changes
      // ...existing code...
      return true;
    } catch (e) {
      // ...existing code...
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
      final frameSize = entryBlock.nDataFrameSize;
      byteOffset += frameIndex * frameSize;
      print(
        'DEBUG: After frame offset: byteOffset=$byteOffset (frameIndex=$frameIndex, frameSize=$frameSize)',
      );

      // Add datum offset within frame - match EXACT parsing logic
      print('DEBUG: depthRecordingMode=${entryBlock.nDepthRecordingMode}');
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
      final valueBytes = CodeReader.encode(
        newValue,
        datum.reprCode,
        datum.size,
      );
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
      final verificationValue = CodeReader.readCode(
        currentBytes,
        datum.reprCode,
        datum.size,
      );
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
      final verificationAfterWrite = CodeReader.readCode(
        writtenBytes,
        datum.reprCode,
        datum.size,
      );
      print('DEBUG: New value decoded after write: $verificationAfterWrite');

      print('Updated value $newValue at position $filePosition');
      return true;
    } catch (e) {
      print('Error updating bytes in memory: $e');
      return false;
    }
  }

  Future<bool> savePendingChanges() async {
    print('DEBUG TEST: savePendingChanges called');
    print('');
    print('========================================');
    print('SAVE PENDING CHANGES CALLED!');
    print('File being saved: $fileName');
    print('========================================');
    print('Pending changes count: ${_pendingChanges.length}');

    final tableData = await getTableData();
    normalizeTableData(tableData, getColumnNames());

    if (_pendingChanges.isEmpty) {
      print('No pending changes to save');
      return true;
    }

    try {
      print('Saving ${_pendingChanges.length} pending changes to file...');
      print('File name: $fileName');

      // Tạo đường dẫn file mới để lưu (không ghi đè file gốc)
      final extIndex = fileName.lastIndexOf('.');
      final now = DateTime.now();
      final timeStr =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final newFileName = extIndex > 0
          ? '${fileName.substring(0, extIndex)}_$timeStr${fileName.substring(extIndex)}'
          : '${fileName}_$timeStr';
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

      // Gọi hàm setDepthForAllRecords để cập nhật lại Depth cho tất cả các record
      // Sử dụng file mới vừa ghi
      // Tìm giá trị Depth lớn nhất trong tableData
      final tableDataForDepth = await getTableData();
      double maxDepth = 0.0;
      for (final row in tableDataForDepth) {
        final depthValue = row['DEPT'];
        if (depthValue != null && depthValue != 'NULL') {
          final depth = double.tryParse(depthValue.toString()) ?? 0.0;
          if (depth > maxDepth) {
            maxDepth = depth;
          }
        }
      }
      print('Max depth found in tableData: $maxDepth');
      // Sử dụng maxDepth làm startDepth cho setDepthForAllRecords
      await setDepthForAllRecords(File(newFileName), maxDepth * 100);

      await closeLisFile();
      return true;
    } catch (e) {
      print('Error saving changes to file: $e');
      return false;
    }
  }

  /*
  // Russian LIS Float Encoder (reprCode 68) - Exact reverse of C++ ReadCode
  Uint8List _encodeRussianLisFloat(double value) {
    if (value == 0.0) return Uint8List.fromList([0, 0, 0, 0]);
    bool isNegative = value < 0;
    double absValue = value.abs();
    // Tìm E và M
    int E = 0;
    double M = 0;
    // Chỉ xử lý các giá trị là -32768.0, -16384.0, ...
    // Tìm E sao cho absValue = 0.5 * 2^(127-E)
    for (int e = 127; e >= 0; e--) {
      double v = 0.5 * math.pow(2.0, 127 - e);
      if ((absValue - v).abs() < 0.0001) {
        E = e;
        M = 0.5;
        break;
      }
    }
    if (M == 0) {
      // Không encode được, trả về [0,0,0,0]
      return Uint8List.fromList([0, 0, 0, 0]);
    }
    // Tính byte1, byte2, byte3, byte4
    int byte1 = isNegative ? (E >> 1) | 0x80 : (E >> 1);
    int byte2 = ((E & 1) << 7) | 0x40;
    int byte3 = 0;
    int byte4 = 0;
    return Uint8List.fromList([byte1, byte2, byte3, byte4]);
  }
*/
  /// Lưu dataRecord type 0 vào file LIS, chuyển đổi dữ liệu theo reprCode
  /// Lưu tableData ra file, chuyển từng giá trị thành bytes theo reprCode của từng cột
  Future<void> saveDataRecordsType0ToLIS({
    required List<Map<String, dynamic>> tableData,
    required List<String> columnOrder,
    required Map<String, int> columnReprCodes,
    required File fileLIS,
  }) async {
    final raf = await fileLIS.open(mode: FileMode.write);
    for (int rowIdx = 0; rowIdx < tableData.length; rowIdx++) {
      final row = tableData[rowIdx];
      for (final col in columnOrder) {
        final value = row[col];
        final reprCode = columnReprCodes[col] ?? 68;
        Uint8List bytes;
        switch (reprCode) {
          case 68: // 32-bit float
            bytes = CodeReader.encode32BitFloat(
              value is num
                  ? value.toDouble()
                  : double.tryParse(value.toString()) ?? 0.0,
            );
            break;
          case 73: // 32-bit int
            int v;
            if (value is int) {
              v = value;
            } else if (value is double) {
              v = value.round();
            } else {
              v = int.tryParse(value.toString().split('.').first) ?? 0;
            }
            final bd = ByteData(4)..setInt32(0, v, Endian.big);
            bytes = bd.buffer.asUint8List();
            break;
          case 79: // 16-bit int
            int v;
            if (value is int) {
              v = value;
            } else if (value is double) {
              v = value.round();
            } else {
              v = int.tryParse(value.toString().split('.').first) ?? 0;
            }
            final bd = ByteData(2)..setInt16(0, v, Endian.big);
            bytes = bd.buffer.asUint8List();
            break;
          case 65: // String
            String s = value.toString();
            bytes = Uint8List.fromList(
              s.padRight(4).codeUnits.take(4).toList(),
            );
            break;
          default:
            bytes = CodeReader.encode32BitFloat(
              value is num
                  ? value.toDouble()
                  : double.tryParse(value.toString()) ?? 0.0,
            );
        }
        // Debug: In ra dạng byte
        // Debug: In ra giá trị trước khi mã hóa thành bytes
        print(
          '[DEBUG][SAVE][VALUE] rowIdx=$rowIdx col=$col value=$value reprCode=$reprCode',
        );
        print(
          '[DEBUG][SAVE][BYTES] rowIdx=$rowIdx col=$col bytes=${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
        );
        await raf.writeFrom(bytes);
      }
    }
    await raf.close();
  }
}
