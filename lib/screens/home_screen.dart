import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/lis_file_parser.dart';
import 'lis_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LisFileParser _parser = LisFileParser();
  bool _isLoading = false;
  double _progress = 0.0;
  String? _errorMessage;

  Future<void> _pickAndOpenLisFile() async {
    try {
      setState(() {
        _isLoading = true;
        _progress = 0.0;
        _errorMessage = null;
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: 'Select LIS File',
      );

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;

        await _parser.openLisFile(
          filePath,
          onProgress: (progress) {
            setState(() {
              _progress = progress;
            });
          },
        );

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LisViewerScreen(parser: _parser),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error opening LIS file: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
        _progress = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LIS File Parser'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.description,
                size: 100,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 32),
              const Text(
                'LIS File Parser',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Parse and view Log Information Standard (LIS) files\nSupports both Russian LIS and Halliburton NTI formats',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 48),
              if (_isLoading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Loading... ${_progress.toStringAsFixed(1)}%'),
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _progress / 100),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: _pickAndOpenLisFile,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Open LIS File'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _parser.closeLisFile();
    super.dispose();
  }
}
