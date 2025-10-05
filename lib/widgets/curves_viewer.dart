import 'package:flutter/material.dart';
import '../services/lis_file_parser.dart';
import '../models/datum_spec_block.dart';

class CurvesViewer extends StatelessWidget {
  final LisFileParser parser;

  const CurvesViewer({super.key, required this.parser});

  @override
  Widget build(BuildContext context) {
    final curves = parser.curves;

    if (curves.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No curves data available',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Curves will appear here after parsing data records',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              Text(
                'Curves: ${curves.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => _showCurvesInfo(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: curves.length,
            itemBuilder: (context, index) {
              final curve = curves[index];
              return _buildCurveTile(context, curve, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCurveTile(
    BuildContext context,
    DatumSpecBlock curve,
    int index,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).primaryColor.withValues(alpha: 0.1),
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          curve.mnemonic,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Units: ${curve.units}'),
            Text('Service ID: ${curve.serviceId}'),
            Text('Size: ${curve.size} bytes | Samples: ${curve.nbSample}'),
            Text('Repr Code: ${curve.reprCode} | File #: ${curve.fileNb}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, color: Theme.of(context).primaryColor),
            const SizedBox(height: 4),
            Text(
              '${curve.realSize}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        onTap: () => _showCurveDetails(context, curve),
        isThreeLine: true,
      ),
    );
  }

  void _showCurveDetails(BuildContext context, DatumSpecBlock curve) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Curve: ${curve.mnemonic}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Mnemonic', curve.mnemonic),
            _buildDetailRow('Units', curve.units),
            _buildDetailRow('Service ID', curve.serviceId),
            _buildDetailRow('Service Order', curve.serviceOrderNb),
            _buildDetailRow('File Number', curve.fileNb.toString()),
            _buildDetailRow('Size', '${curve.size} bytes'),
            _buildDetailRow('Samples', curve.nbSample.toString()),
            _buildDetailRow('Representation Code', curve.reprCode.toString()),
            _buildDetailRow('Offset', curve.offset.toString()),
            _buildDetailRow('Data Items', curve.dataItemNum.toString()),
            _buildDetailRow('Real Size', curve.realSize.toString()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _showCurvesInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Curves Information'),
        content: const Text(
          'Curves represent the different measurements recorded in the LIS file. '
          'Each curve has a mnemonic (name), units, and various technical parameters '
          'that define how the data is stored and interpreted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
