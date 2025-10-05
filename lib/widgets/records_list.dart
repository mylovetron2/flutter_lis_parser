import 'package:flutter/material.dart';
import '../services/lis_file_parser.dart';
import '../models/lis_record.dart';

class RecordsList extends StatelessWidget {
  final LisFileParser parser;

  const RecordsList({super.key, required this.parser});

  @override
  Widget build(BuildContext context) {
    final records = parser.records;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              Text(
                'Total Records: ${records.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Text(
                'Data Records: ${records.where((r) => r.isDataRecord).length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              return _buildRecordTile(context, record, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecordTile(BuildContext context, LisRecord record, int index) {
    IconData icon;
    Color color;

    if (record.isDataRecord) {
      icon = Icons.data_array;
      color = Colors.blue;
    } else if (record.isWellInfoRecord) {
      icon = Icons.info;
      color = Colors.green;
    } else if (record.isDataFormatSpecRecord) {
      icon = Icons.settings;
      color = Colors.orange;
    } else {
      icon = Icons.description;
      color = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(
          record.name.isEmpty ? record.typeName : record.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Type: ${record.type} | Address: ${record.addr} | Length: ${record.length}',
            ),
            if (record.depth != -999.25)
              Text('Depth: ${record.depth.toStringAsFixed(2)}m'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '#$index',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            if (record.blockNum > 1)
              Text(
                '${record.blockNum} blocks',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        isThreeLine: record.depth != -999.25,
      ),
    );
  }
}
