import 'package:flutter/material.dart';
import '../services/lis_file_parser.dart';

class AllDataViewerScreen extends StatefulWidget {
  final LisFileParser parser;
  final int currentDataRec;

  const AllDataViewerScreen({
    super.key,
    required this.parser,
    required this.currentDataRec,
  });

  @override
  State<AllDataViewerScreen> createState() => _AllDataViewerScreenState();
}

class _AllDataViewerScreenState extends State<AllDataViewerScreen> {
  List<double> allData = [];
  bool isLoading = true;
  String errorMessage = '';
  late int currentRec;
  double currentDepth = 0.0;
  final TextEditingController _recController = TextEditingController();

  @override
  void initState() {
  super.initState();
  currentRec = widget.currentDataRec;
  _recController.text = currentRec.toString();
  _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    try {
      // Lấy dữ liệu và currentDepth
      final data = await widget.parser.getAllData(currentRec);
      setState(() {
        allData = data;
        currentDepth = widget.parser.currentDepth;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading data: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('All Data Viewer'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(child: Text(errorMessage))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _recController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Record index',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              final idx = int.tryParse(_recController.text);
                              if (idx != null && idx >= 0 && idx < widget.parser.recordCount) {
                                setState(() {
                                  currentRec = idx;
                                });
                                _loadAllData();
                              } else {
                                setState(() {
                                  errorMessage = 'Record index không hợp lệ!';
                                });
                              }
                            },
                            child: const Text('Tải lại'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'currentDataRec: $currentRec',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'currentDepth: $currentDepth',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          itemCount: allData.length,
                          itemBuilder: (context, index) {
                            final value = allData[index];
                            return ListTile(
                              leading: Text('#${index + 1}'),
                              title: Text(value.isNaN ? 'NULL' : value.toStringAsFixed(6)),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  @override
  void dispose() {
    _recController.dispose();
    super.dispose();
  }
  }
}
