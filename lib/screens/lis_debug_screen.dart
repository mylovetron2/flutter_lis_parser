import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/lis_file_class.dart';

class LisViewerScreen extends StatefulWidget {
  const LisViewerScreen({super.key});

  @override
  State<LisViewerScreen> createState() => _LisViewerScreenState();
}

class _LisViewerScreenState extends State<LisViewerScreen> {
  String? _filePath;
  LISFileClass? _lisFile;
  String _status = '';
  bool _loading = false;

  Future<void> _pickFile() async {
    setState(() {
      _loading = true;
      _status = 'Đang tải file...';
    });
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        _filePath = filePath;
        _lisFile = LISFileClass(strFileName: filePath);
        await _lisFile!.parse();
        setState(() {
          _status =
              'Đã load xong file: $filePath\nSố LogicalRecord: ${_lisFile!.nLogicalRecordNum}';
          _loading = false;
        });
      } else {
        setState(() {
          _status = 'Không chọn file.';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Lỗi: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('LIS Viewer'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'LogicalRecord'),
              Tab(text: 'Record 128'),
              Tab(text: 'DataFormatSpec'),
            ],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton(
                onPressed: _loading ? null : _pickFile,
                child: const Text('Load file LIS'),
              ),
              const SizedBox(height: 16),
              Text(_status, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              if (_lisFile != null)
                Expanded(
                  child: TabBarView(
                    children: [
                      // Tab 1: LogicalRecord list
                      ListView.builder(
                        itemCount: _lisFile!.lrArr.length,
                        itemBuilder: (context, idx) {
                          final lr = _lisFile!.lrArr[idx];
                          return ListTile(
                            title: Text('LogicalRecord #$idx'),
                            subtitle: Text(
                              'Type: ${lr.type}, Addr: ${lr.address}, Len: ${lr.length}, PRs: ${lr.physicalRecordNum}',
                            ),
                          );
                        },
                      ),
                      // Tab 2: Record 128 detail
                      ListView(
                        children: [
                          for (int idx = 0; idx < _lisFile!.lrArr.length; idx++)
                            if (_lisFile!.lrArr[idx].type == 128)
                              Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: ListTile(
                                  title: Text('File Header Record #$idx'),
                                  subtitle: Text(
                                    'Addr: ${_lisFile!.lrArr[idx].address}, Len: ${_lisFile!.lrArr[idx].length}, PRs: ${_lisFile!.lrArr[idx].physicalRecordNum}',
                                  ),
                                ),
                              ),
                          if (!_lisFile!.lrArr.any((lr) => lr.type == 128))
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Không có record type 128 (File Header) trong file này.',
                              ),
                            ),
                        ],
                      ),
                      // Tab 3: DataFormatSpecRecord detail
                      ListView(
                        children: [
                          for (int idx = 0; idx < _lisFile!.lrArr.length; idx++)
                            if (_lisFile!.lrArr[idx].type == 64)
                              Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: ExpansionTile(
                                  title: Text('DataFormatSpecRecord #$idx'),
                                  subtitle: Text(
                                    'Addr: ${_lisFile!.lrArr[idx].address}, Len: ${_lisFile!.lrArr[idx].length}, PRs: ${_lisFile!.lrArr[idx].physicalRecordNum}',
                                  ),
                                  children: [
                                    if (_lisFile!.chansArr.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Channels:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            ..._lisFile!.chansArr.map(
                                              (chan) => Card(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 4,
                                                    ),
                                                child: ListTile(
                                                  title: Text(chan.strMnemonic),
                                                  subtitle: Text(
                                                    'Units: ${chan.strUnits}, ReprCode: ${chan.nReprCode}, Samples: ${chan.nNbSamples}, Size: ${chan.nSize}, Offset: ${chan.nOffsetInBytes}',
                                                  ),
                                                  trailing: Text(
                                                    chan.strServiceID,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (_lisFile!.chansArr.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Text(
                                          'Không có channel (DatumSpecBlock) nào được phân tích.',
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          if (!_lisFile!.lrArr.any((lr) => lr.type == 64))
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Không có record type 64 (DataFormatSpecRecord) trong file này.',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
