import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter_lis_parser/services/lis_file_parser.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart tool/validate_lis.dart <input_lis_file>');
    exit(1);
  }
  final inputFile = args[0];
  final parser = LisFileParser();

  developer.log('Opening LIS file: $inputFile', name: 'ValidateLIS');
  await parser.openLisFile(inputFile);

  // Xóa record đầu, cuối, và một record giữa (nếu có đủ record)
  final totalRecords = parser.lisRecords.length;
  if (totalRecords < 3) {
    print('File quá ít record để kiểm thử xóa.');
    exit(1);
  }
  parser.markRowDeleted(parser.startDataRec); // xóa record đầu
  parser.markRowDeleted(parser.endDataRec); // xóa record cuối
  final midIdx =
      parser.startDataRec + ((parser.endDataRec - parser.startDataRec) ~/ 2);
  parser.markRowDeleted(midIdx); // xóa record giữa

  final newFileName = inputFile.replaceAll('.lis', '_deleted.lis');
  developer.log(
    'Saving LIS file with deleted records: $newFileName',
    name: 'ValidateLIS',
  );
  final ok = await parser.saveLISWithDeletedRecords(newFileName);
  if (!ok) {
    print('Lỗi khi ghi file LIS mới!');
    exit(1);
  }
  developer.log('Validating new LIS file: $newFileName', name: 'ValidateLIS');
  await parser.validateNewLISFile(newFileName);
  print('Kiểm thử hoàn tất. Xem log để kiểm tra liên kết.');
}
