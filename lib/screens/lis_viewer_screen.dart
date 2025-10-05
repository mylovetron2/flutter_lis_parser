import 'package:flutter/material.dart';
import '../services/lis_file_parser.dart';
import '../widgets/file_info_card.dart';
import '../widgets/records_list.dart';
import '../widgets/curves_viewer.dart';
import '../widgets/data_table_widget.dart';

class LisViewerScreen extends StatefulWidget {
  final LisFileParser parser;

  const LisViewerScreen({super.key, required this.parser});

  @override
  State<LisViewerScreen> createState() => _LisViewerScreenState();
}

class _LisViewerScreenState extends State<LisViewerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('LIS File - ${widget.parser.fileInfo['fileName']}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.info), text: 'File Info'),
            Tab(icon: Icon(Icons.list), text: 'Records'),
            Tab(icon: Icon(Icons.show_chart), text: 'Curves'),
            Tab(icon: Icon(Icons.table_chart), text: 'Data Table'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // File Info Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: FileInfoCard(parser: widget.parser),
          ),
          // Records Tab
          RecordsList(parser: widget.parser),
          // Curves Tab
          CurvesViewer(parser: widget.parser),
          // Data Table Tab
          Padding(
            padding: const EdgeInsets.all(16),
            child: DataTableWidget(parser: widget.parser),
          ),
        ],
      ),
    );
  }
}
