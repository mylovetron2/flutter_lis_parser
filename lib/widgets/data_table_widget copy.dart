// Data Table Widget for displaying LIS file data

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../services/lis_file_parser.dart';
import 'waveform_viewer_dialog.dart';

class DataTableWidget extends StatefulWidget {
  final LisFileParser parser;

  const DataTableWidget({super.key, required this.parser});

  @override
  State<DataTableWidget> createState() => _DataTableWidgetState();
}

class _DataTableWidgetState extends State<DataTableWidget> {
  List<Map<String, dynamic>> tableData = [];
  List<String> columnNames = [];
  bool isLoading = false;
  String errorMessage = '';
  int maxRows = 500; // Limit rows for performance
  int currentPage = 0;
  final int rowsPerPage = 50;

  // Editing state
  String? editingCellKey; // Format: "rowIndex_columnName"
  Map<String, TextEditingController> editControllers = {};
  Map<String, String> modifiedValues = {}; // Track modified values
  bool isEditMode = false;

  @override
  void initState() {
    super.initState();
    _loadTableData();
  }

  // Merge theo TIME: thay DEPTH trong LIS bằng DEPTH trong TXT
  Future<void> _mergeByTimeFromTxt() async {
    try {
      // Chọn file TXT bằng file picker
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );
      if (result == null || result.files.isEmpty) return;
      final txtPath = result.files.single.path;
      if (txtPath == null) return;
      final txtFile = await File(txtPath).readAsString();

      // Parse TXT, tự động tìm dòng header chứa TIME và DEPTH
      final lines = txtFile
          .split(RegExp(r'\r?\n'))
          .where((l) => l.trim().isNotEmpty)
          .toList();
      if (lines.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File TXT không hợp lệ!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      int headerIdx = -1;
      List<String> txtHeader = [];
      for (int i = 0; i < lines.length; ++i) {
        final cols = lines[i]
            .split(RegExp(r'\s+|,|;|\t'))
            .map((e) => e.trim().toUpperCase())
            .toList();
        if (cols.contains('TIME') &&
            (cols.contains('DEPTH') || cols.contains('DEPT'))) {
          headerIdx = i;
          txtHeader = lines[i]
              .split(RegExp(r'\s+|,|;|\t'))
              .map((e) => e.trim())
              .toList();
          // debug: TXT header found at line $headerIdx
          break;
        }
      }
      if (headerIdx == -1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy dòng header chứa TIME và DEPTH!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final timeIdx = txtHeader.indexWhere((c) => c.toUpperCase() == 'TIME');
      int depthIdx = txtHeader.indexWhere((c) => c.toUpperCase() == 'DEPTH');
      if (depthIdx == -1)
        depthIdx = txtHeader.indexWhere((c) => c.toUpperCase() == 'DEPT');
      if (timeIdx == -1 || depthIdx == -1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File TXT thiếu cột TIME hoặc DEPTH!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      // Map TIME->DEPTH từ TXT (chuyển TIME sang giây)
      double _parseTimeToSeconds(String timeStr) {
        // Hỗ trợ các định dạng: d:hh:mm:ss:ms, d:hh:mm:ss, hh:mm:ss, mm:ss, ss
        final parts = timeStr.split(':').map((e) => e.trim()).toList();
        double seconds = 0;
        if (parts.length == 5) {
          // d:hh:mm:ss:ms
          seconds += (double.tryParse(parts[0]) ?? 0) * 86400;
          seconds += (double.tryParse(parts[1]) ?? 0) * 3600;
          seconds += (double.tryParse(parts[2]) ?? 0) * 60;
          seconds += double.tryParse(parts[3]) ?? 0;
          seconds += (double.tryParse(parts[4]) ?? 0) / 1000.0;
        } else if (parts.length == 4) {
          // d:hh:mm:ss
          seconds += (double.tryParse(parts[0]) ?? 0) * 86400;
          seconds += (double.tryParse(parts[1]) ?? 0) * 3600;
          seconds += (double.tryParse(parts[2]) ?? 0) * 60;
          seconds += double.tryParse(parts[3]) ?? 0;
        } else if (parts.length == 3) {
          // hh:mm:ss
          seconds += (double.tryParse(parts[0]) ?? 0) * 3600;
          seconds += (double.tryParse(parts[1]) ?? 0) * 60;
          seconds += double.tryParse(parts[2]) ?? 0;
        } else if (parts.length == 2) {
          // mm:ss
          seconds += (double.tryParse(parts[0]) ?? 0) * 60;
          seconds += double.tryParse(parts[1]) ?? 0;
        } else if (parts.length == 1) {
          seconds += double.tryParse(parts[0]) ?? 0;
        }
        return seconds;
      }

      final Map<String, String> timeToDepth = {};
      for (var i = headerIdx + 1; i < lines.length; ++i) {
        final row = lines[i].split(RegExp(r'\s+|,|;|\t'));
        if (row.length > depthIdx && row.length > timeIdx) {
          final timeSec = _parseTimeToSeconds(row[timeIdx]);
          timeToDepth[timeSec.toString()] = row[depthIdx];
        }
      }
      // debug: TXT timeToDepth mapping computed
      // Merge vào tableData
      int matchCount = 0;
      final targetCol = columnNames.length > 1 ? columnNames[1] : 'DEPTH';
      // Lấy số frame/record động từ parser
      int framesPerRecord = 1;
      if (widget.parser.startDataRec >= 0 &&
          widget.parser.endDataRec >= widget.parser.startDataRec) {
        framesPerRecord = widget.parser.getFrameNum(widget.parser.startDataRec);
        if (framesPerRecord <= 0) framesPerRecord = 1;
      }
      for (int i = tableData.length - 1; i >= 0; --i) {
        final row = tableData[i];
        final rawTime = row['TIME'];
        if (rawTime == null) {
          continue;
        }
        double? timeNum;
        if (rawTime is num) {
          timeNum = rawTime.toDouble();
        } else {
          timeNum = double.tryParse(rawTime.toString());
        }
        if (timeNum == null) {
          continue;
        }
        final timeVal = (timeNum / 1000).toString();
        if (timeToDepth.containsKey(timeVal)) {
          final newDepth = timeToDepth[timeVal];
          if (newDepth != null && newDepth != row[targetCol]?.toString()) {
            setState(() {
              tableData[i][targetCol] = newDepth;
              modifiedValues['${i}_$targetCol'] = newDepth;
            });
            // Tính lại recordIndex và frameIndex đúng như _updateParserData
            final recordIndex = i ~/ framesPerRecord;
            final frameIndex = i % framesPerRecord;
            await widget.parser.updateDataValue(
              recordIndex: recordIndex,
              frameIndex: frameIndex,
              columnName: targetCol,
              newValue: double.tryParse(newDepth) ?? 0.0,
            );
            matchCount++;
          }
        } else {
          setState(() {
            tableData.removeAt(i);
          });
          widget.parser.markRowDeleted(i);
        }
      }
      // Debug: print first 10 values and tableData length after merge
      print('tableData length after merge: ${tableData.length}');
      for (int i = 0; i < tableData.length && i < 10; i++) {
        print('Row $i: ${tableData[i]}');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã merge DEPTH từ TXT cho $matchCount dòng TIME khớp!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi merge: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    // Clean up text controllers
    for (var controller in editControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTableData() async {
    // Có thể sử dụng entryBlock ở đây nếu cần cho logic bảng
    if (!widget.parser.isFileOpen) {
      setState(() {
        errorMessage = 'No file is currently open';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // Loading table data (silent)

  columnNames = widget.parser.getColumnNames();
  // Ví dụ: debug in ra một số thông tin từ EntryBlock
  print('EntryBlock DataFrameSize: ${widget.parser.entryBlock.nDataFrameSize}');
  print('EntryBlock Direction: ${widget.parser.entryBlock.nDirection}');
      // Column names loaded

      if (columnNames.isEmpty) {
        setState(() {
          errorMessage =
              'No column data available. Parser has ${widget.parser.curves.length} curves, startDataRec=${widget.parser.startDataRec}';
          isLoading = false;
        });
        return;
      }

  final data = await widget.parser.getTableData(maxRows: maxRows);
  // Nếu muốn dùng entryBlock để custom hiển thị, có thể chỉnh sửa logic ở đây
      // Retrieved ${data.length} rows of data

      setState(() {
        tableData = data;
        isLoading = false;
      });

      if (tableData.isEmpty) {
        setState(() {
          errorMessage =
              'No data found in the file. startDataRec=${widget.parser.startDataRec}, endDataRec=${widget.parser.endDataRec}';
        });
      }
    } catch (e) {
      // Error loading table data: $e
      setState(() {
        errorMessage = 'Error loading data: $e';
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get currentPageData {
    final startIndex = currentPage * rowsPerPage;
    final endIndex = (startIndex + rowsPerPage).clamp(0, tableData.length);
    return tableData.sublist(startIndex, endIndex);
  }

  int get totalPages => (tableData.length / rowsPerPage).ceil();

  void _startEditing(int rowIndex, String columnName, String currentValue) {
    final cellKey = '${rowIndex}_$columnName';

    // Don't edit array values or DEPTH column
    if (columnName == 'DEPTH') return;

    setState(() {
      editingCellKey = cellKey;
      isEditMode = true;
    });

    // Create or get controller for this cell
    if (!editControllers.containsKey(cellKey)) {
      editControllers[cellKey] = TextEditingController(text: currentValue);
    } else {
      editControllers[cellKey]!.text = currentValue;
    }
  }

  void _saveEdit(int rowIndex, String columnName) {
    final cellKey = '${rowIndex}_$columnName';
    final controller = editControllers[cellKey];

    if (controller != null) {
      final newValue = controller.text.trim();

      // Validate numeric value
      if (_isValidNumericValue(newValue)) {
        // Update the table data locally
        final actualRowIndex = currentPage * rowsPerPage + rowIndex;
        if (actualRowIndex < tableData.length) {
          final numericValue = double.parse(newValue);

          setState(() {
            tableData[actualRowIndex][columnName] = newValue;
            modifiedValues[cellKey] = newValue;
            editingCellKey = null;
          });

          // Update the parser's pending changes
          _updateParserData(actualRowIndex, columnName, numericValue);

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Updated $columnName value to $newValue'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Invalid numeric value. Please enter a valid number.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _updateParserData(
    int rowIndex,
    String columnName,
    double newValue,
  ) async {
    try {
      // Lấy số frame/record động từ parser
      int framesPerRecord = 1;
      if (widget.parser.startDataRec >= 0 &&
          widget.parser.endDataRec >= widget.parser.startDataRec) {
        // Lấy frameNum của record đầu tiên (giả định các record có cùng số frame)
        framesPerRecord = widget.parser.getFrameNum(widget.parser.startDataRec);
        if (framesPerRecord <= 0) framesPerRecord = 1;
      }
      final recordIndex = rowIndex ~/ framesPerRecord;
      final frameIndex = rowIndex % framesPerRecord;

      final success = await widget.parser.updateDataValue(
        recordIndex: recordIndex,
        frameIndex: frameIndex,
        columnName: columnName,
        newValue: newValue,
      );

      if (!success) {
        // Failed to update parser data for $columnName
      }
    } catch (e) {
      // Error updating parser data: $e
    }
  }

  Future<void> _saveAllChangesToFile() async {
    if (widget.parser.pendingChangesCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No changes to save'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Changes to File'),
        content: Text(
          'This will permanently save ${widget.parser.pendingChangesCount} changes to the LIS file.\n\n'
          'A backup copy will be created automatically.\n\n'
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Save to File'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Saving changes to file...'),
          ],
        ),
      ),
    );

    try {
      // Save initiated

      final success = await widget.parser.savePendingChanges();
      // Save result: $success

      Navigator.of(context).pop(); // Close loading dialog

      if (success) {
        setState(() {
          modifiedValues.clear(); // Clear UI modified state
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully saved all changes to file!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save changes to file'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving to file: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _cancelEdit() {
    setState(() {
      editingCellKey = null;
      isEditMode = false;
    });
  }

  bool _isValidNumericValue(String value) {
    if (value.isEmpty) return false;
    return double.tryParse(value) != null;
  }

  bool _isCellModified(int rowIndex, String columnName) {
    final cellKey = '${rowIndex}_$columnName';
    return modifiedValues.containsKey(cellKey);
  }

  void _resetAllChanges() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Changes'),
        content: Text(
          'Are you sure you want to reset all ${modifiedValues.length} changes?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                modifiedValues.clear();
                editingCellKey = null;
                isEditMode = false;
              });
              Navigator.of(context).pop();
              _loadTableData(); // Reload original data
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading data...'),
          ],
        ),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadTableData, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (tableData.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return Column(
      children: [
        // Header with file info and controls
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.table_chart,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Data Table',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    // Edit mode controls
                    if (modifiedValues.isNotEmpty) ...[
                      Chip(
                        label: Text('${modifiedValues.length} modified'),
                        backgroundColor: Colors.orange.withOpacity(0.2),
                        side: BorderSide(color: Colors.orange),
                      ),
                      const SizedBox(width: 8),
                      // Save to file button
                      IconButton(
                        onPressed: _saveAllChangesToFile,
                        icon: const Icon(Icons.save),
                        tooltip: 'Save changes to LIS file',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.green.withOpacity(0.1),
                          foregroundColor: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _resetAllChanges,
                        icon: const Icon(Icons.undo),
                        tooltip: 'Reset all changes',
                      ),
                      const SizedBox(width: 8),
                    ],
                    // Nút merge DEPTH theo TIME (luôn hiển thị)
                    IconButton(
                      onPressed: _mergeByTimeFromTxt,
                      icon: const Icon(Icons.merge_type),
                      tooltip: 'Merge DEPTH từ TXT theo TIME',
                    ),
                    const SizedBox(width: 8),
                    // Edit mode toggle
                    IconButton(
                      onPressed: () {
                        setState(() {
                          isEditMode = !isEditMode;
                          if (!isEditMode) {
                            editingCellKey = null;
                          }
                        });
                      },
                      icon: Icon(isEditMode ? Icons.edit_off : Icons.edit),
                      tooltip: isEditMode
                          ? 'Exit edit mode'
                          : 'Enable edit mode',
                      style: IconButton.styleFrom(
                        backgroundColor: isEditMode
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text('${tableData.length} rows'),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _buildInfoChip('Columns', '${columnNames.length}'),
                    _buildInfoChip('Format', widget.parser.fileTypeString),
                    _buildInfoChip(
                      'Start Depth',
                      '${widget.parser.startDepth.toStringAsFixed(2)}m',
                    ),
                    _buildInfoChip(
                      'End Depth',
                      '${widget.parser.endDepth.toStringAsFixed(2)}m',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Pagination controls
        if (totalPages > 1) _buildPaginationControls(),

        // Data table
        Expanded(
          child: Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  columns: [
                    // Đưa cột nút xóa lên đầu
                    const DataColumn(
                      label: Icon(Icons.delete, color: Colors.red, size: 18),
                    ),
                    ...columnNames.map(
                      (name) => DataColumn(
                        label: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                  rows: currentPageData.asMap().entries.map((entry) {
                    final rowIndex = entry.key;
                    final row = entry.value;

                    // Tạo danh sách cell dữ liệu cho từng dòng, bắt đầu với nút xóa
                    final cells = <DataCell>[
                      DataCell(
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red, size: 18),
                          tooltip: 'Xóa dòng',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Xác nhận xóa dòng'),
                                content: const Text(
                                  'Bạn có chắc chắn muốn xóa dòng này?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('Hủy'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: const Text(
                                      'Xóa',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              setState(() {
                                tableData.removeAt(rowIndex);
                              });
                              widget.parser.markRowDeleted(rowIndex);
                            }
                          },
                        ),
                      ),
                    ];
                    for (final columnName in columnNames) {
                      final value = row[columnName] ?? 'N/A';
                      final cellKey = '${rowIndex}_$columnName';
                      final isEditing = editingCellKey == cellKey;
                      final isModified = _isCellModified(rowIndex, columnName);
                      final canEdit =
                          isEditMode &&
                          columnName != 'DEPTH' &&
                          value != 'NULL' &&
                          value != 'N/A';

                      if (value is Map && value['isArray'] == true) {
                        cells.add(
                          DataCell(
                            InkWell(
                              onTap: () => _showWaveformDialog(
                                context,
                                value['datumName'],
                                value['recordIdx'],
                                value['frameIdx'],
                                double.tryParse(
                                      row['DEPTH']?.toString() ?? '0',
                                    ) ??
                                    0.0,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '...',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.show_chart,
                                      size: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      } else if (isEditing) {
                        cells.add(
                          DataCell(
                            Container(
                              width: 120,
                              child: TextField(
                                controller: editControllers[cellKey],
                                autofocus: true,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.all(8),
                                  border: OutlineInputBorder(),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: () =>
                                            _saveEdit(rowIndex, columnName),
                                        icon: Icon(
                                          Icons.check,
                                          size: 16,
                                          color: Colors.green,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: BoxConstraints(
                                          minWidth: 24,
                                          minHeight: 24,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: _cancelEdit,
                                        icon: Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.red,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: BoxConstraints(
                                          minWidth: 24,
                                          minHeight: 24,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                onSubmitted: (_) =>
                                    _saveEdit(rowIndex, columnName),
                              ),
                            ),
                          ),
                        );
                      } else {
                        cells.add(
                          DataCell(
                            InkWell(
                              onTap: canEdit
                                  ? () => _startEditing(
                                      rowIndex,
                                      columnName,
                                      value.toString(),
                                    )
                                  : null,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isModified
                                      ? Colors.orange.withOpacity(0.1)
                                      : canEdit
                                      ? Theme.of(context)
                                            .colorScheme
                                            .surfaceContainer
                                            .withOpacity(0.5)
                                      : null,
                                  borderRadius: BorderRadius.circular(4),
                                  border: canEdit
                                      ? Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline
                                              .withOpacity(0.3),
                                          width: 1,
                                        )
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        value.toString(),
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          color:
                                              value == 'NULL' || value == 'N/A'
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.outline
                                              : isModified
                                              ? Colors.orange.shade800
                                              : null,
                                          fontWeight: isModified
                                              ? FontWeight.bold
                                              : null,
                                        ),
                                      ),
                                    ),
                                    if (canEdit)
                                      Icon(
                                        Icons.edit,
                                        size: 12,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outline,
                                      ),
                                    if (isModified)
                                      Icon(
                                        Icons.circle,
                                        size: 8,
                                        color: Colors.orange,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                    }

                    return DataRow(cells: cells);
                  }).toList(),
                ),
              ),
            ),
          ),
        ),

        // Bottom pagination
        if (totalPages > 1) _buildPaginationControls(),

        // Help text for editing
        if (isEditMode)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Edit mode: Click numeric cells to edit • DEPTH is read-only • Click Save 💾 to write changes to LIS file',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Chip(
      label: Text('$label: $value'),
      labelStyle: const TextStyle(fontSize: 12),
      visualDensity: VisualDensity.compact,
    );
  }

  void _showWaveformDialog(
    BuildContext context,
    String datumName,
    int recordIdx,
    int frameIdx,
    double depth,
  ) {
    showDialog(
      context: context,
      builder: (context) => WaveformViewerDialog(
        parser: widget.parser,
        datumName: datumName,
        recordIdx: recordIdx,
        frameIdx: frameIdx,
        depth: depth,
      ),
    );
  }

  Widget _buildPaginationControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Page ${currentPage + 1} of $totalPages',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Row(
              children: [
                IconButton(
                  onPressed: currentPage > 0
                      ? () => setState(() => currentPage = 0)
                      : null,
                  icon: const Icon(Icons.first_page),
                  tooltip: 'First page',
                ),
                IconButton(
                  onPressed: currentPage > 0
                      ? () => setState(() => currentPage--)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Previous page',
                ),
                IconButton(
                  onPressed: currentPage < totalPages - 1
                      ? () => setState(() => currentPage++)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next page',
                ),
                IconButton(
                  onPressed: currentPage < totalPages - 1
                      ? () => setState(() => currentPage = totalPages - 1)
                      : null,
                  icon: const Icon(Icons.last_page),
                  tooltip: 'Last page',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
