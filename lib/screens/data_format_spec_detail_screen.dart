import 'package:flutter/material.dart';
import '../models/data_format_spec.dart';

class DataFormatSpecDetailScreen extends StatelessWidget {
  final DataFormatSpec dataFormatSpec;

  const DataFormatSpecDetailScreen({Key? key, required this.dataFormatSpec})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Format Specification Detail')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              'Data Format Specification',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildRow(
              'Data Record Type',
              dataFormatSpec.dataRecordType.toString(),
            ),
            _buildRow(
              'Datum Spec Block Type',
              dataFormatSpec.datumSpecBlockType.toString(),
            ),
            _buildRow(
              'Data Frame Size',
              dataFormatSpec.dataFrameSize.toString(),
            ),
            _buildRow('Direction', dataFormatSpec.directionName),
            _buildRow(
              'Optical Depth Unit',
              dataFormatSpec.opticalDepthUnit.toString(),
            ),
            _buildRow('Data Ref Point', dataFormatSpec.dataRefPoint.toString()),
            _buildRow(
              'Data Ref Point Unit',
              dataFormatSpec.dataRefPointUnit.toString(),
            ),
            _buildRow('Frame Spacing', dataFormatSpec.frameSpacing.toString()),
            _buildRow(
              'Frame Spacing Unit',
              dataFormatSpec.frameSpacingUnit.toString(),
            ),
            _buildRow(
              'Max Frames Per Record',
              dataFormatSpec.maxFramesPerRecord.toString(),
            ),
            _buildRow('Absent Value', dataFormatSpec.absentValue.toString()),
            _buildRow(
              'Depth Recording Mode',
              dataFormatSpec.depthRecordingMode.toString(),
            ),
            _buildRow('Depth Unit', dataFormatSpec.depthUnitName),
            _buildRow('Depth Repr', dataFormatSpec.depthRepr.toString()),
            _buildRow(
              'Datum Spec Block SubType',
              dataFormatSpec.datumSpecBlockSubType.toString(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(flex: 3, child: Text(value)),
        ],
      ),
    );
  }
}
