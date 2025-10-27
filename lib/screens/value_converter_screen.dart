import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/code_reader.dart';

class ValueConverterScreen extends StatefulWidget {
  const ValueConverterScreen({super.key});

  @override
  State<ValueConverterScreen> createState() => _ValueConverterScreenState();
}

class _ValueConverterScreenState extends State<ValueConverterScreen> {
  final TextEditingController decimalController = TextEditingController();
  final TextEditingController bytesController = TextEditingController();
  int selectedReprCode = 68;
  final List<int> reprCodes = [68, 73, 79, 65];

  String resultBytes = '';
  String resultDecimal = '';

  void convertDecimalToBytes() {
    double value = double.tryParse(decimalController.text) ?? 0.0;
    Uint8List bytes;
    switch (selectedReprCode) {
      case 68:
        //bytes = CodeReader.encode32BitFloat(value);
        bytes = CodeReader.encode(value, 68, -1);
        break;
      case 73:
        //final bd = ByteData(4)..setInt32(0, value.round(), Endian.big);
        //bytes = bd.buffer.asUint8List();
        bytes = CodeReader.encode(value, 73, -1);
        break;
      case 79:
        // final bd = ByteData(2)..setInt16(0, value.round(), Endian.big);
        // bytes = bd.buffer.asUint8List();
        bytes = CodeReader.encode(value, 79, -1);
        break;
      case 65:
        String s = value.toString();
        bytes = Uint8List.fromList(s.padRight(4).codeUnits.take(4).toList());
        break;
      default:
        //bytes = CodeReader.encode32BitFloat(value);
        bytes = CodeReader.encode(value, 68, -1);
    }
    setState(() {
      resultBytes = bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');
    });
  }

  void convertBytesToDecimal() {
    List<int> bytes = bytesController.text
        .split(RegExp(r'\s+|,|;'))
        .where((s) => s.isNotEmpty)
        .map((s) => int.tryParse(s, radix: 16) ?? 0)
        .toList();
    double value;
    switch (selectedReprCode) {
      case 68:
        value = CodeReader.readCode(
          Uint8List.fromList(bytes),
          68,
          bytes.length,
        );
        break;
      case 73:
        value = CodeReader.readCode(
          Uint8List.fromList(bytes),
          73,
          bytes.length,
        );
        break;
      case 79:
        value = CodeReader.readCode(
          Uint8List.fromList(bytes),
          79,
          bytes.length,
        );
        break;
      case 65:
        value = double.tryParse(String.fromCharCodes(bytes)) ?? 0.0;
        break;
      default:
        value = CodeReader.readCode(
          Uint8List.fromList(bytes),
          68,
          bytes.length,
        );
    }
    setState(() {
      resultDecimal = value.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Value Converter')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('ReprCode: '),
                  DropdownButton<int>(
                    value: selectedReprCode,
                    items: reprCodes
                        .map(
                          (code) => DropdownMenuItem(
                            value: code,
                            child: Text('$code'),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedReprCode = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: decimalController,
                decoration: const InputDecoration(
                  labelText: 'Decimal Value',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: convertDecimalToBytes,
                child: const Text('Convert to Bytes'),
              ),
              Text('Bytes: $resultBytes'),
              const Divider(height: 32),
              TextField(
                controller: bytesController,
                decoration: const InputDecoration(
                  labelText: 'Bytes (hex, space/comma separated)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: convertBytesToDecimal,
                child: const Text('Convert to Decimal'),
              ),
              Text('Decimal: $resultDecimal'),
            ],
          ),
        ),
      ),
    );
  }
}
