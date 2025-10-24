import 'package:flutter/material.dart';
import '../services/lis_file_parser.dart';

class FileInfoCard extends StatelessWidget {
  final LisFileParser parser;

  const FileInfoCard({super.key, required this.parser});

  @override
  Widget build(BuildContext context) {
  final fileInfo = parser.fileInfo;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'File Information',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('File Name', fileInfo['fileName'].toString()),
            _buildInfoRow('File Type', fileInfo['fileType'].toString()),
            _buildInfoRow('Record Count', fileInfo['recordCount'].toString()),
            const Divider(height: 32),
            Text(
              'Depth Information',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Start Depth',
              '${fileInfo['startDepth'].toString()} ${fileInfo['depthUnit'].toString()}',
            ),
            _buildInfoRow(
              'End Depth',
              '${fileInfo['endDepth'].toString()} ${fileInfo['depthUnit'].toString()}',
            ),
            _buildInfoRow('Direction', fileInfo['direction'].toString()),
            _buildInfoRow(
              'Frame Spacing',
              '${fileInfo['frameSpacing'].toString()} ${fileInfo['depthUnit'].toString()}',
            ),
            const Divider(height: 32),
            Text(
              'Data Format Specification',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Depth Unit', fileInfo['depthUnit'].toString()),
            _buildInfoRow(
              'Data Frame Size',
              parser.entryBlock.nDataFrameSize.toString(),
            ),
            _buildInfoRow(
              'Depth Recording Mode',
              parser.entryBlock.nDepthRecordingMode.toString(),
            ),
            _buildInfoRow(
              'Absent Value',
              parser.entryBlock.fAbsentValue.toString(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
