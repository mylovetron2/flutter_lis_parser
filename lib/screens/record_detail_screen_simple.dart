import 'package:flutter/material.dart';
import '../models/lis_record.dart';

class RecordDetailScreenSimple extends StatelessWidget {
  final LisRecord record;

  const RecordDetailScreenSimple({Key? key, required this.record})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chi tiết Record (Simple)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thông tin Record',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text('Loại: ${record.typeName}'),
            Text('Tên: ${record.name}'),
            Text('Địa chỉ: ${record.addr}'),
            Text('Độ dài: ${record.length}'),
            Text('Block #: ${record.blockNum}'),
            Text('Frame #: ${record.frameNum}'),
            Text('Depth: ${record.depth}'),
          ],
        ),
      ),
    );
  }
}
