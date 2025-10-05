// Data Table Widget for displaying LIS file data

import 'package:flutter/material.dart';
import '../services/lis_file_parser.dart';

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

  @override
  void initState() {
    super.initState();
    _loadTableData();
  }

  Future<void> _loadTableData() async {
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
      print('Loading table data...');
      print('Parser curves count: ${widget.parser.curves.length}');
      print(
        'Parser start/end data records: ${widget.parser.startDataRec}/${widget.parser.endDataRec}',
      );
      print(
        'Parser data format spec frame size: ${widget.parser.dataFormatSpec.dataFrameSize}',
      );

      columnNames = widget.parser.getColumnNames();
      print('Column names: $columnNames');

      if (columnNames.isEmpty) {
        setState(() {
          errorMessage =
              'No column data available. Parser has ${widget.parser.curves.length} curves, startDataRec=${widget.parser.startDataRec}';
          isLoading = false;
        });
        return;
      }

      final data = await widget.parser.getTableData(maxRows: maxRows);
      print('Retrieved ${data.length} rows of data');

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
      print('Error loading table data: $e');
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
                  columns: columnNames.map((name) {
                    return DataColumn(
                      label: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                  rows: currentPageData.map((row) {
                    return DataRow(
                      cells: columnNames.map((columnName) {
                        final value = row[columnName] ?? 'N/A';
                        return DataCell(
                          Text(
                            value.toString(),
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: value == 'NULL' || value == 'N/A'
                                  ? Theme.of(context).colorScheme.outline
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),

        // Bottom pagination
        if (totalPages > 1) _buildPaginationControls(),
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
