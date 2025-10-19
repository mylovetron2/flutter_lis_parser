import 'package:flutter/material.dart';
import '../models/data_format_spec.dart';
import '../services/lis_file_parser.dart';

class DataFormatSpecDetailScreen extends StatefulWidget {
  final DataFormatSpec dataFormatSpec;
  final LisFileParser? parser;

  const DataFormatSpecDetailScreen({
    Key? key,
    required this.dataFormatSpec,
    this.parser,
  }) : super(key: key);

  @override
  State<DataFormatSpecDetailScreen> createState() =>
      _DataFormatSpecDetailScreenState();
}

class _DataFormatSpecDetailScreenState
    extends State<DataFormatSpecDetailScreen> {
  late DataFormatSpec _spec;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _spec = DataFormatSpec(
      dataRecordType: widget.dataFormatSpec.dataRecordType,
      datumSpecBlockType: widget.dataFormatSpec.datumSpecBlockType,
      dataFrameSize: widget.dataFormatSpec.dataFrameSize,
      direction: widget.dataFormatSpec.direction,
      opticalDepthUnit: widget.dataFormatSpec.opticalDepthUnit,
      dataRefPoint: widget.dataFormatSpec.dataRefPoint,
      dataRefPointUnit: widget.dataFormatSpec.dataRefPointUnit,
      frameSpacing: widget.dataFormatSpec.frameSpacing,
      frameSpacingUnit: widget.dataFormatSpec.frameSpacingUnit,
      maxFramesPerRecord: widget.dataFormatSpec.maxFramesPerRecord,
      absentValue: widget.dataFormatSpec.absentValue,
      depthRecordingMode: widget.dataFormatSpec.depthRecordingMode,
      depthUnit: widget.dataFormatSpec.depthUnit,
      depthRepr: widget.dataFormatSpec.depthRepr,
      datumSpecBlockSubType: widget.dataFormatSpec.datumSpecBlockSubType,
    );
  }

  void _saveSpec() async {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();
      // Cập nhật vào parser
      if (widget.parser != null) {
        widget.parser!.dataFormatSpec = _spec;
        // Gọi hàm lưu ra file LIS
        await widget.parser!.saveDataFormatSpecToLIS();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu Data Format Spec vào file LIS!'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Data Format Specification')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                'Data Format Specification',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _buildIntField(
                'Data Record Type',
                _spec.dataRecordType,
                (v) => _spec.dataRecordType = v,
              ),
              _buildIntField(
                'Datum Spec Block Type',
                _spec.datumSpecBlockType,
                (v) => _spec.datumSpecBlockType = v,
              ),
              _buildIntField(
                'Data Frame Size',
                _spec.dataFrameSize,
                (v) => _spec.dataFrameSize = v,
              ),
              _buildIntField(
                'Direction',
                _spec.direction,
                (v) => _spec.direction = v,
              ),
              _buildIntField(
                'Optical Depth Unit',
                _spec.opticalDepthUnit,
                (v) => _spec.opticalDepthUnit = v,
              ),
              _buildDoubleField(
                'Data Ref Point',
                _spec.dataRefPoint,
                (v) => _spec.dataRefPoint = v,
              ),
              _buildIntField(
                'Data Ref Point Unit',
                _spec.dataRefPointUnit,
                (v) => _spec.dataRefPointUnit = v,
              ),
              _buildDoubleField(
                'Frame Spacing',
                _spec.frameSpacing,
                (v) => _spec.frameSpacing = v,
              ),
              _buildIntField(
                'Frame Spacing Unit',
                _spec.frameSpacingUnit,
                (v) => _spec.frameSpacingUnit = v,
              ),
              _buildIntField(
                'Max Frames Per Record',
                _spec.maxFramesPerRecord,
                (v) => _spec.maxFramesPerRecord = v,
              ),
              _buildDoubleField(
                'Absent Value',
                _spec.absentValue,
                (v) => _spec.absentValue = v,
              ),
              _buildIntField(
                'Depth Recording Mode',
                _spec.depthRecordingMode,
                (v) => _spec.depthRecordingMode = v,
              ),
              _buildIntField(
                'Depth Unit',
                _spec.depthUnit,
                (v) => _spec.depthUnit = v,
              ),
              _buildIntField(
                'Depth Repr',
                _spec.depthRepr,
                (v) => _spec.depthRepr = v,
              ),
              _buildIntField(
                'Datum Spec Block SubType',
                _spec.datumSpecBlockSubType,
                (v) => _spec.datumSpecBlockSubType = v,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveSpec,
                child: const Text('Lưu vào file LIS'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntField(String label, int value, Function(int) onSaved) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: TextFormField(
        initialValue: value.toString(),
        decoration: InputDecoration(labelText: label),
        keyboardType: TextInputType.number,
        validator: (v) => v == null || v.isEmpty ? 'Không được để trống' : null,
        onSaved: (v) {
          if (v != null && v.isNotEmpty) onSaved(int.tryParse(v) ?? 0);
        },
      ),
    );
  }

  Widget _buildDoubleField(
    String label,
    double value,
    Function(double) onSaved,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: TextFormField(
        initialValue: value.toString(),
        decoration: InputDecoration(labelText: label),
        keyboardType: TextInputType.number,
        validator: (v) => v == null || v.isEmpty ? 'Không được để trống' : null,
        onSaved: (v) {
          if (v != null && v.isNotEmpty) onSaved(double.tryParse(v) ?? 0.0);
        },
      ),
    );
  }
}
