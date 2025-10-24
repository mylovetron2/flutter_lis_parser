// ...existing code...
 
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';


 bool _showOnlyDiff = false;
class ByteViewerScreen extends StatefulWidget {
  const ByteViewerScreen({Key? key}) : super(key: key);

  @override
  State<ByteViewerScreen> createState() => _ByteViewerScreenState();
}

class _ByteViewerScreenState extends State<ByteViewerScreen> {
  // Trái
  final TextEditingController _filePathController1 = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController(text: '120');
  List<List<int>>? _byteRows1;
  String? _error1;
  // Phải
  final TextEditingController _filePathController2 = TextEditingController();
  final TextEditingController _addressController2 = TextEditingController();
  List<List<int>>? _byteRows2;
  String? _error2;

  Future<void> _readBytes() async {
  final addressStr = _addressController.text.trim();
  final lengthStr = _lengthController.text.trim();
  int? address = int.tryParse(addressStr);
  int? length = int.tryParse(lengthStr);
    // Panel trái
    setState(() {
      _error1 = null;
      _byteRows1 = null;
    });
    final filePath1 = _filePathController1.text.trim();
    if (filePath1.isEmpty || address == null || length == null || length <= 0) {
      setState(() {
        _error1 = 'Vui lòng nhập đúng đường dẫn, địa chỉ và số byte.';
      });
    } else {
      try {
        final file = File(filePath1);
        final raf = await file.open();
        await raf.setPosition(address);
        final bytes = await raf.read(length);
        await raf.close();
        List<List<int>> rows = [];
        for (int i = 0; i < bytes.length; i += 8) {
          rows.add(bytes.sublist(i, i + 8 > bytes.length ? bytes.length : i + 8));
        }
        setState(() {
          _byteRows1 = rows;
        });
      } catch (e) {
        setState(() {
          _error1 = 'Lỗi: $e';
        });
      }
    }
    // Panel phải
    setState(() {
      _error2 = null;
      _byteRows2 = null;
    });
    final filePath2 = _filePathController2.text.trim();
    if (filePath2.isEmpty || address == null || length == null || length <= 0) {
      setState(() {
        _error2 = 'Vui lòng nhập đúng đường dẫn, địa chỉ và số byte.';
      });
    } else {
      try {
        final file = File(filePath2);
        final raf = await file.open();
        await raf.setPosition(address);
        final bytes = await raf.read(length);
        await raf.close();
        List<List<int>> rows = [];
        for (int i = 0; i < bytes.length; i += 8) {
          rows.add(bytes.sublist(i, i + 8 > bytes.length ? bytes.length : i + 8));
        }
        setState(() {
          _byteRows2 = rows;
        });
      } catch (e) {
        setState(() {
          _error2 = 'Lỗi: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('So sánh byte giữa 2 file LIS', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
      ),
      body: Container(
        color: Colors.grey[100],
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('So sánh dữ liệu nhị phân giữa 2 file LIS', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Chọn 2 file, nhập địa chỉ vật lý (offset), nhấn "Đọc 120 byte" để xem và so sánh dữ liệu. Các dòng khác biệt sẽ được tô màu vàng.', style: TextStyle(fontSize: 15)),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _filePathController1,
                                decoration: const InputDecoration(
                                  labelText: 'File trái',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.folder_open),
                              label: const Text('Chọn file'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                              onPressed: () async {
                                String? pickedPath;
                                try {
                                  final result = await FilePicker.platform.pickFiles(type: FileType.any);
                                  pickedPath = result?.files.single.path;
                                } catch (e) {
                                  pickedPath = null;
                                }
                                if (pickedPath != null && pickedPath.isNotEmpty) {
                                  setState(() {
                                    _filePathController1.text = pickedPath!;
                                  });
                                }
                              },
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: TextField(
                                controller: _filePathController2,
                                decoration: const InputDecoration(
                                  labelText: 'File phải',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.folder_open),
                              label: const Text('Chọn file'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                              onPressed: () async {
                                String? pickedPath;
                                try {
                                  final result = await FilePicker.platform.pickFiles(type: FileType.any);
                                  pickedPath = result?.files.single.path;
                                } catch (e) {
                                  pickedPath = null;
                                }
                                if (pickedPath != null && pickedPath.isNotEmpty) {
                                  setState(() {
                                    _filePathController2.text = pickedPath!;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _addressController,
                                decoration: const InputDecoration(
                                  labelText: 'Địa chỉ vật lý (offset)',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 18),
                            SizedBox(
                              width: 120,
                              child: TextField(
                                controller: _lengthController,
                                decoration: const InputDecoration(
                                  labelText: 'Số byte',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 18),
                            ElevatedButton(
                              onPressed: _readBytes,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                child: Text('Đọc dữ liệu (cả 2 file)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                        if (_error1 != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(_error1!, style: const TextStyle(color: Colors.red)),
                          ),
                        if (_error2 != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(_error2!, style: const TextStyle(color: Colors.red)),
                          ),
                        if (_byteRows1 != null && _byteRows2 != null) ...[
                          Row(
                            children: [
                              Checkbox(
                                value: _showOnlyDiff,
                                onChanged: (val) {
                                  setState(() {
                                    _showOnlyDiff = val ?? false;
                                  });
                                },
                              ),
                              const Text('Chỉ hiển thị dòng khác nhau', style: TextStyle(fontSize: 15)),
                              const Spacer(),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.copy),
                                label: const Text('Copy trái'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                                onPressed: () {
                                  if (_byteRows1 == null) return;
                                  final lines = _byteRows1!.map((row) => row.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')).join('\n');
                                  Clipboard.setData(ClipboardData(text: lines));
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã copy dữ liệu bên trái!')));
                                },
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.copy),
                                label: const Text('Copy phải'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                                onPressed: () {
                                  if (_byteRows2 == null) return;
                                  final lines = _byteRows2!.map((row) => row.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')).join('\n');
                                  Clipboard.setData(ClipboardData(text: lines));
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã copy dữ liệu bên phải!')));
                                },
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: (_byteRows1 != null && _byteRows2 != null)
                          ? Scrollbar(
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: 900,
                                  child: Scrollbar(
                                    thumbVisibility: true,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.vertical,
                                      child: DataTable(
                                        columnSpacing: 24,
                                        headingRowColor: MaterialStateProperty.all(Colors.indigo[50]),
                                        columns: const [
                                          DataColumn(label: Text('Địa chỉ', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('File trái', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('File phải', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold))),
                                        ],
                                        rows: List.generate(_byteRows1!.length, (idx) {
                                          final addr = int.tryParse(_addressController.text.trim()) ?? 0;
                                          final offset = addr + idx * 8;
                                          final left = _byteRows1![idx].map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
                                          final right = idx < _byteRows2!.length ? _byteRows2![idx].map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ') : '';
                                          final isDiff = left != right;
                                          if (_showOnlyDiff && !isDiff) return null;
                                          return DataRow(
                                            color: MaterialStateProperty.resolveWith<Color?>((states) => isDiff ? Colors.yellow[100] : null),
                                            cells: [
                                              DataCell(Text(offset.toString().padLeft(8, '0'), style: const TextStyle(fontFamily: 'monospace'))),
                                              DataCell(Text(left, style: const TextStyle(fontFamily: 'monospace'))),
                                              DataCell(Text(right, style: const TextStyle(fontFamily: 'monospace'))),
                                            ],
                                          );
                                        }).whereType<DataRow>().toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : const Center(child: Text('Vui lòng chọn đủ 2 file và nhập địa chỉ để xem dữ liệu so sánh.', style: TextStyle(fontSize: 16))),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
