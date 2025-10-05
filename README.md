# Flutter LIS Parser

A Flutter application for parsing and viewing Log Information Standard (LIS) files. This project converts the functionality of a C++ LIS file reader into a modern, cross-platform Flutter application.

## Features

- **Multi-format Support**: Supports both Russian LIS and Halliburton NTI formats
- **File Browser**: Easy file selection with built-in file picker
- **Comprehensive Parsing**: Reads file headers, well information, and curve data
- **Interactive UI**: Tabbed interface for viewing different aspects of LIS files
- **Data Visualization**: Shows file information, record lists, and curve details

## Supported LIS File Types

### Russian LIS Format
- Standard LIS format with blank record tables
- Supports all standard LIS record types

### Halliburton NTI Format  
- NTI (Non-standard) format files
- Multi-block record support
- Enhanced data format specifications

## Project Structure

```
lib/
├── constants/
│   └── lis_constants.dart      # LIS format constants
├── models/
│   ├── blank_record.dart       # Blank record model
│   ├── data_format_spec.dart   # Data format specification
│   ├── datum_spec_block.dart   # Datum specification block
│   ├── lis_record.dart         # LIS record model
│   └── well_info_block.dart    # Well information block
├── services/
│   ├── code_reader.dart        # Data decoding utilities
│   └── lis_file_parser.dart    # Main parsing engine
├── screens/
│   ├── home_screen.dart        # File selection screen
│   └── lis_viewer_screen.dart  # File viewing screen
├── widgets/
│   ├── curves_viewer.dart      # Curves data viewer
│   ├── file_info_card.dart     # File information display
│   └── records_list.dart       # Records list viewer
└── main.dart                   # Application entry point
```

## Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- Dart SDK (included with Flutter)

### Installation

1. Install dependencies:
```bash
flutter pub get
```

2. Run the application:
```bash
flutter run
```

## Usage

1. **Open LIS File**: Click "Open LIS File" on the home screen
2. **Select File**: Choose a LIS file from your device
3. **View Data**: Navigate through the tabs to see:
   - **File Info**: Basic file information and specifications
   - **Records**: List of all records in the file
   - **Curves**: Curve data and specifications

## Technical Notes

### File Format Detection
The application automatically detects whether a file is in Russian LIS or Halliburton NTI format by analyzing the blank record table structure.

### Supported Data Types
The parser supports all standard LIS representation codes:
- **Code 56**: Signed 8-bit integer
- **Code 65**: ASCII character string
- **Code 66**: Unsigned 8-bit integer  
- **Code 68**: 32-bit IEEE floating point
- **Code 73**: 32-bit signed integer
- **Code 79**: 16-bit signed integer

### Depth Units
Supported depth measurement units: Feet, CM, M, MM, HMM, 0.1 Inches

## License

This project is based on the original C++ LIS file parser implementation, converted to Flutter for modern cross-platform support.
