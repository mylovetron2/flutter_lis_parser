import 'package:flutter/material.dart';
import '../models/entry_block.dart';

class DataFormatSpecEntryBlockScreen extends StatelessWidget {
  final EntryBlock entryBlock;
  const DataFormatSpecEntryBlockScreen({super.key, required this.entryBlock});

  @override
  Widget build(BuildContext context) {
    final fields = <Map<String, Object>>[
      {'label': 'Data Record Type', 'value': entryBlock.nDataRecordType},
      {'label': 'Datum Spec Block Type', 'value': entryBlock.nDatumSpecBlockType},
      {'label': 'Data Frame Size', 'value': entryBlock.nDataFrameSize},
      {'label': 'Direction', 'value': entryBlock.nDirection},
      {'label': 'Optical Depth Unit', 'value': entryBlock.nOpticalDepthUnit},
      {'label': 'Data Ref Point', 'value': entryBlock.fDataRefPoint},
      {'label': 'Data Ref Point Unit', 'value': entryBlock.strDataRefPointUnit},
      {'label': 'Frame Spacing', 'value': entryBlock.fFrameSpacing},
      {'label': 'Frame Spacing Unit', 'value': entryBlock.strFrameSpacingUnit},
      {'label': 'Max Frames Per Record', 'value': entryBlock.nMaxFramesPerRecord},
      {'label': 'Absent Value', 'value': entryBlock.fAbsentValue},
      {'label': 'Depth Recording Mode', 'value': entryBlock.nDepthRecordingMode},
      {'label': 'Depth Unit', 'value': entryBlock.strDepthUnit},
      {'label': 'Depth Repr', 'value': entryBlock.nDepthRepr},
      {'label': 'Datum Spec Block SubType', 'value': entryBlock.nDatumSpecBlockSubType},
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('EntryBlock Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
            columns: const [
              DataColumn(label: Text('Trường', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Giá trị', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: fields
                .map(
                  (field) => DataRow(
                    cells: [
                      DataCell(Text(field['label'].toString())),
                      DataCell(Text(field['value'].toString())),
                    ],
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
