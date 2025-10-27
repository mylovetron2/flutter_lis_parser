import 'package:flutter/material.dart';

import '../models/file_header_record.dart';

class FileHeaderDetailScreen extends StatelessWidget {
  final FileHeaderRecord fileHeaderRecord;

  const FileHeaderDetailScreen({super.key, required this.fileHeaderRecord});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('File Header Record Detail')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              'Thông tin File Header Record',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text('Type: ${fileHeaderRecord.type}'),
            Text('Logical Index: ${fileHeaderRecord.logicalIndex}'),
            Text('Physical Index: ${fileHeaderRecord.physicalIndex}'),
            Text('Address: ${fileHeaderRecord.address}'),
            Text('Length: ${fileHeaderRecord.length}'),
            const Divider(),
            Text('File Name: ${fileHeaderRecord.fileName}'),
            Text('Service Name: ${fileHeaderRecord.serviceName}'),
            Text('File Number: ${fileHeaderRecord.fileNumber}'),
            Text(
              'Service Sub Level Name: ${fileHeaderRecord.serviceSubLevelName}',
            ),
            Text('Version Number: ${fileHeaderRecord.versionNumber}'),
            Text(
              'Date: ${fileHeaderRecord.year}-${fileHeaderRecord.month}-${fileHeaderRecord.day}',
            ),
            Text(
              'Max Physical Record Length: ${fileHeaderRecord.maxPhysicalRecordLength}',
            ),
            Text('File Type: ${fileHeaderRecord.fileType}'),
            Text('Previous File Name: ${fileHeaderRecord.previousFileName}'),
          ],
        ),
      ),
    );
  }
}
