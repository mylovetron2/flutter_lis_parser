import 'package:flutter/material.dart';
import '../models/entry_block.dart';
import '../services/lis_file_parser.dart';

class EntryBlockScreen extends StatefulWidget {
  final EntryBlock entryBlock;
  final LisFileParser parser;
  const EntryBlockScreen({Key? key, required this.entryBlock, required this.parser}) : super(key: key);

  @override
  State<EntryBlockScreen> createState() => _EntryBlockScreenState();
}
  


class _EntryBlockScreenState extends State<EntryBlockScreen> {
  final TextEditingController _filePathController = TextEditingController();

  @override
  void dispose() {
    _filePathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entryBlock = widget.entryBlock;
    final parser = widget.parser;
    bool isEmpty =
        entryBlock.nDataRecordType == 0 &&
        entryBlock.nDatumSpecBlockType == 0 &&
        entryBlock.nDataFrameSize == 0 &&
        entryBlock.nDirection == 0 &&
        entryBlock.nOpticalDepthUnit == 0 &&
        entryBlock.fDataRefPoint == 0 &&
        entryBlock.strDataRefPointUnit == '' &&
        entryBlock.fFrameSpacing == 0 &&
        entryBlock.strFrameSpacingUnit == '' &&
        entryBlock.nMaxFramesPerRecord == 0 &&
        entryBlock.fAbsentValue == -999.255 &&
        entryBlock.nDepthRecordingMode == 0 &&
        entryBlock.strDepthUnit == '' &&
        entryBlock.nDepthRepr == 68 &&
        entryBlock.nDatumSpecBlockSubType == 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Entry Block Details')),
      body: isEmpty
          ? Center(
              child: Text(
                'Không có dữ liệu EntryBlock',
                style: TextStyle(fontSize: 18, color: Colors.red),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildTable(entryBlock),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    // Tạo đường dẫn file mới tự động
                    final originalPath = parser.fileName;
                    final extIndex = originalPath.lastIndexOf('.');
                    final newFilePath = extIndex > 0
                        ? originalPath.substring(0, extIndex) + '_edited' + originalPath.substring(extIndex)
                        : originalPath + '_edited';
                    final success = await parser.saveEntryBlockToNewFile(newFilePath);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success
                            ? 'Đã lưu EntryBlock vào file mới: $newFilePath'
                            : 'Lưu EntryBlock vào file mới thất bại!'),
                      ),
                    );
                  },
                  child: const Text('Lưu EntryBlock ra file mới (tự động)'),
                ),
              ],
            ),
    );
  }

  // Trạng thái chỉnh sửa cho từng trường
  int? _editingIndex;
  TextEditingController? _editingController;

  // Danh sách các trường có thể chỉnh sửa
  final List<String> _editableFields = [
    'Data Record Type',
    'Datum Spec Block Type',
    'Data Frame Size',
    'Direction',
    'Optical Depth Unit',
    'Data Ref Point',
    'Data Ref Point Unit',
    'Frame Spacing',
    'Frame Spacing Unit',
    'Max Frames Per Record',
    'Absent Value',
    'Depth Recording Mode',
    'Depth Unit',
    'Depth Repr',
    'Datum Spec Block SubType',
  ];

  Widget _buildTable(EntryBlock entryBlock) {
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
    return DataTable(
      headingRowColor: MaterialStateProperty.all(Colors.grey[200]),
      columns: const [
        DataColumn(label: Text('Trường', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Giá trị', style: TextStyle(fontWeight: FontWeight.bold))),
      ],
      rows: List.generate(fields.length, (index) {
        final field = fields[index];
        final label = field['label'].toString();
        final value = field['value'];
        final isEditable = _editableFields.contains(label);
        return DataRow(
          cells: [
            DataCell(Text(label)),
            DataCell(
              _editingIndex == index
                  ? TextField(
                      controller: _editingController,
                      autofocus: true,
                      onSubmitted: (newValue) {
                        _updateEntryBlockField(label, newValue);
                        setState(() {
                          _editingIndex = null;
                          _editingController?.dispose();
                          _editingController = null;
                        });
                      },
                      onEditingComplete: () {
                        setState(() {
                          _editingIndex = null;
                          _editingController?.dispose();
                          _editingController = null;
                        });
                      },
                    )
                  : GestureDetector(
                      onDoubleTap: isEditable
                          ? () {
                              setState(() {
                                _editingIndex = index;
                                _editingController?.dispose();
                                _editingController = TextEditingController(text: value.toString());
                              });
                            }
                          : null,
                      child: Text(value.toString(), style: isEditable ? const TextStyle(color: Colors.blue) : null),
                    ),
            ),
          ],
        );
      }),
    );
  }

  // Hàm cập nhật giá trị cho EntryBlock
  void _updateEntryBlockField(String label, String newValue) {
    final entryBlock = widget.entryBlock;
    switch (label) {
      case 'Data Record Type':
        entryBlock.nDataRecordType = int.tryParse(newValue) ?? entryBlock.nDataRecordType;
        break;
      case 'Datum Spec Block Type':
        entryBlock.nDatumSpecBlockType = int.tryParse(newValue) ?? entryBlock.nDatumSpecBlockType;
        break;
      case 'Data Frame Size':
        entryBlock.nDataFrameSize = int.tryParse(newValue) ?? entryBlock.nDataFrameSize;
        break;
      case 'Direction':
        entryBlock.nDirection = int.tryParse(newValue) ?? entryBlock.nDirection;
        break;
      case 'Optical Depth Unit':
        entryBlock.nOpticalDepthUnit = int.tryParse(newValue) ?? entryBlock.nOpticalDepthUnit;
        break;
      case 'Data Ref Point':
        entryBlock.fDataRefPoint = double.tryParse(newValue) ?? entryBlock.fDataRefPoint;
        break;
      case 'Data Ref Point Unit':
        entryBlock.strDataRefPointUnit = newValue;
        break;
      case 'Frame Spacing':
        entryBlock.fFrameSpacing = double.tryParse(newValue) ?? entryBlock.fFrameSpacing;
        break;
      case 'Frame Spacing Unit':
        entryBlock.strFrameSpacingUnit = newValue;
        break;
      case 'Max Frames Per Record':
        entryBlock.nMaxFramesPerRecord = int.tryParse(newValue) ?? entryBlock.nMaxFramesPerRecord;
        break;
      case 'Absent Value':
        entryBlock.fAbsentValue = double.tryParse(newValue) ?? entryBlock.fAbsentValue;
        break;
      case 'Depth Recording Mode':
        entryBlock.nDepthRecordingMode = int.tryParse(newValue) ?? entryBlock.nDepthRecordingMode;
        break;
      case 'Depth Unit':
        entryBlock.strDepthUnit = newValue;
        break;
      case 'Depth Repr':
        entryBlock.nDepthRepr = int.tryParse(newValue) ?? entryBlock.nDepthRepr;
        break;
      case 'Datum Spec Block SubType':
        entryBlock.nDatumSpecBlockSubType = int.tryParse(newValue) ?? entryBlock.nDatumSpecBlockSubType;
        break;
    }
  }
}
