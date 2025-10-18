import 'package:flutter/material.dart';
import '../models/lis_record.dart';

class ScreenSimple extends StatelessWidget {
  final LisRecord record;
  const ScreenSimple({Key? key, required this.record}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Record Detail')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text('Type: ${record.type}'),
            Text('Name: ${record.name}'),
            Text('Address: ${record.addr}'),
            Text('Length: ${record.length}'),
            Text('BlockNum: ${record.blockNum}'),
            if (record.depth != -999.25)
              Text('Depth: ${record.depth.toStringAsFixed(2)}m'),
            // Thêm các trường khác nếu cần
          ],
        ),
      ),
    );
  }
}
