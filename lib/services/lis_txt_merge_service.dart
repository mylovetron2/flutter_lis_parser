import 'package:flutter/foundation.dart';
import '../services/lis_file_parser.dart';
import '../models/lis_record.dart';

class LisTxtMergeService {
  /// Merge dữ liệu LIS với TXT (dataRows: [[TIME, DEPTH, ...], ...])
  /// Trả về: {
  ///   'blockList': List<LisRecord>,
  ///   'curveInfoList': List<DatumSpecBlock>,
  ///   'wellInfoList': List<WellInfoBlock>,
  ///   'success': bool,
  ///   'message': String
  /// }
  static Future<Map<String, dynamic>> mergeLisWithTxt(
    String lisPath,
    List<List<String>> dataRows,
  ) async {
    try {
      debugPrint(
        '[mergeLisWithTxt] Bắt đầu merge LIS: $lisPath với TXT dataRows (${dataRows.length} dòng)',
      );
      final parser = LisFileParser();
      await parser.openLisFile(lisPath);
      debugPrint(
        '[mergeLisWithTxt] Đã mở LIS file, tổng số record: \\${parser.lisRecords.length}',
      );
      // Tạo map TIME->DEPTH từ TXT
      final Map<int, double> timeToDepth = {};
      int txtRowCount = 0;
      for (final row in dataRows) {
        if (row.length >= 2) {
          final t = int.tryParse(row[0]);
          final d = double.tryParse(row[1]);
          if (t != null && d != null) {
            timeToDepth[t] = d;
            txtRowCount++;
            if (txtRowCount <= 5) {
              debugPrint('[mergeLisWithTxt] TXT mapping: TIME=$t -> DEPTH=$d');
            }
          }
        }
      }
      debugPrint('[mergeLisWithTxt] Tổng số TIME->DEPTH mapping: $txtRowCount');
      // Duyệt block LIS, nếu TIME khớp thì thay DEPTH
      int matchCount = 0;
      final mergedRecords = <dynamic>[];
      int lisIdx = 0;
      // Xác định vị trí cột TIME trong datumBlocks
      int timeColIdx = -1;
      final colNames = parser.getColumnNames();
      for (int i = 0; i < colNames.length; i++) {
        if (colNames[i].toUpperCase() == 'TIME') {
          timeColIdx = i;
          break;
        }
      }
      if (timeColIdx == -1) {
        debugPrint('[mergeLisWithTxt] Không tìm thấy cột TIME trong LIS');
      }
      for (int recIdx = 0; recIdx < parser.lisRecords.length; recIdx++) {
        final rec = parser.lisRecords[recIdx];
        int? time;
        if (timeColIdx != -1 && rec.type == 0) {
          try {
            final data = await parser.getAllData(recIdx);
            if (data.length > timeColIdx) {
              time = data[timeColIdx].round();
            }
          } catch (e) {
            debugPrint('[mergeLisWithTxt] Lỗi đọc TIME ở record $recIdx: $e');
          }
        }
        if (time != null && timeToDepth.containsKey(time)) {
          mergedRecords.add(
            LisRecord(
              type: rec.type,
              addr: rec.addr,
              length: rec.length,
              name: rec.name,
              blockNum: rec.blockNum,
              frameNum: rec.frameNum,
              depth: timeToDepth[time]!,
            ),
          );
          matchCount++;
          if (matchCount <= 5) {
            debugPrint(
              '[mergeLisWithTxt] LIS record $lisIdx: TIME=$time khớp, DEPTH mới=${timeToDepth[time]}',
            );
          }
        } else {
          mergedRecords.add(rec);
          if (lisIdx < 5) {
            debugPrint(
              '[mergeLisWithTxt] LIS record $lisIdx: TIME=$time không khớp, giữ nguyên',
            );
          }
        }
        lisIdx++;
      }
      debugPrint(
        '[mergeLisWithTxt] Merge xong. Số record khớp: $matchCount / ${parser.lisRecords.length}',
      );
      return {
        'blockList': mergedRecords,
        'curveInfoList': parser.datumBlocks,
        'wellInfoList': parser.consBlocks,
        'success': true,
        'message': 'Merge LIS với TXT thành công ($matchCount dòng khớp)',
      };
    } catch (e, st) {
      debugPrint('[mergeLisWithTxt] Lỗi: $e\n$st');
      return {
        'blockList': [],
        'curveInfoList': [],
        'wellInfoList': [],
        'success': false,
        'message': 'Lỗi khi merge LIS với TXT: $e',
      };
    }
  }
}
