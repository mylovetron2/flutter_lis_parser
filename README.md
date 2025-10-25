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

## Phân tích hàm getColumnNames trong parser

Hàm `getColumnNames` trong parser luôn thêm `'DEPTH'` vào đầu danh sách cột, sau đó mới thêm các mnemonic từ `datumBlocks` (ví dụ: DEPT, TIME, SPEE, ...).

**Phân tích chi tiết:**
- Đầu tiên, hàm này tạo một danh sách rỗng `columns`.
- Sau đó, luôn thêm `'DEPTH'` vào đầu tiên:
  ```dart
  columns.add('DEPTH');
  ```
- Tiếp theo, lặp qua từng `datum` trong `datumBlocks` và thêm `datum.mnemonic` vào danh sách:
  ```dart
  for (var datum in datumBlocks) {
    columns.add(datum.mnemonic);
  }
  ```
- Kết quả: danh sách cột luôn bắt đầu bằng `'DEPTH'`, tiếp theo là các mnemonic thực tế của file LIS (DEPT, TIME, ...).

**Ý nghĩa:**
- `'DEPTH'` là cột hiển thị độ sâu đã được chuẩn hóa/met, dùng cho UI và merge.
- Các mnemonic (DEPT, TIME, ...) là các cột dữ liệu gốc của file LIS.

Nếu muốn thay đổi thứ tự hoặc loại bỏ `'DEPTH'`, chỉ cần chỉnh lại hàm này trong parser.

## Phân tích cách lấy giá trị cột đầu tiên (không phải mnemonic)

Trong parser, cột đầu tiên luôn là `'DEPTH'` (do hàm `getColumnNames` thêm vào đầu danh sách).
- `'DEPTH'` không phải là mnemonic thực tế trong file LIS, mà là giá trị độ sâu đã được chuẩn hóa/met, dùng cho UI và các thao tác merge.

**Cách lấy giá trị cột đầu tiên:**
1. Khi lấy danh sách cột từ `getColumnNames()`, phần tử đầu tiên luôn là `'DEPTH'`.
2. Khi truy cập dữ liệu từng dòng, giá trị của cột `'DEPTH'` thường được tính toán từ thông tin độ sâu của record, không lấy trực tiếp từ `datumBlocks`.
3. Các cột tiếp theo (DEPT, TIME, ...) mới là các mnemonic thực tế của file LIS.

**Ví dụ truy cập:**
```dart
final columns = parser.getColumnNames();
final firstCol = columns[0]; // luôn là 'DEPTH'
final value = row[firstCol]; // giá trị độ sâu đã chuẩn hóa/met
```

### Chi tiết về cách lấy giá trị cột 'DEPTH'

- Khi truy cập dữ liệu từng dòng (record), giá trị của cột `'DEPTH'` không lấy trực tiếp từ `datumBlocks` hay từ mnemonic gốc (ví dụ: DEPT), mà được tính toán lại dựa trên thông tin độ sâu của record và các thông số như hướng đo (direction), bước sâu (frameSpacing), đơn vị (depthUnit), v.v.
- Cụ thể, parser sẽ lấy địa chỉ, độ dài, số frame, và giá trị độ sâu gốc của record, sau đó tính toán lại độ sâu cho từng frame theo công thức chuẩn hóa/met.
- Điều này giúp đảm bảo giá trị `'DEPTH'` luôn nhất quán, đúng đơn vị, và phù hợp cho việc hiển thị, so sánh, hoặc merge với dữ liệu TXT.
- Các cột mnemonic như DEPT, TIME, SPEE... mới lấy giá trị trực tiếp từ dữ liệu gốc của file LIS thông qua `datumBlocks`.

**Ví dụ (giả lập):**
```dart
for (int frame = 0; frame < frameNum; frame++) {
  double frameDepth = startingDepth;
  if (direction == LisConstants.dirDown) {
    frameDepth += frame * (step / 1000.0);
  } else {
    frameDepth -= frame * (step / 1000.0);
  }
  row['DEPTH'] = frameDepth.toStringAsFixed(3);
  // ... lấy các giá trị mnemonic khác từ datumBlocks
}
```

#### Ví dụ chi tiết về cách tính giá trị cột 'DEPTH'

Giả sử một record có độ sâu bắt đầu là 700.0m, hướng đo là xuống (direction = down), bước sâu mỗi frame là 0.5m, và có 3 frame:

```dart
final startingDepth = 700.0;
final frameSpacing = 0.5; // mét
final direction = LisConstants.dirDown;
final frameNum = 3;

for (int frame = 0; frame < frameNum; frame++) {
  double frameDepth;
  if (direction == LisConstants.dirDown) {
    frameDepth = startingDepth + frame * frameSpacing;
  } else {
    frameDepth = startingDepth - frame * frameSpacing;
  }
  print('Frame $frame: DEPTH = ${frameDepth.toStringAsFixed(3)} m');
}
```

**Kết quả in ra:**
```
Frame 0: DEPTH = 700.000 m
Frame 1: DEPTH = 700.500 m
Frame 2: DEPTH = 701.000 m
```

Như vậy, giá trị `'DEPTH'` cho từng dòng sẽ được tính toán lại dựa trên thông tin record và các thông số đo, không lấy trực tiếp từ dữ liệu gốc (mnemonic DEPT).

**Kết luận:**
- `'DEPTH'` là giá trị đã được tính toán lại, không lấy trực tiếp từ dữ liệu gốc, giúp chuẩn hóa và đồng bộ dữ liệu cho các thao tác xử lý và hiển thị.

### tableData Definition

`tableData` is the main variable used to store parsed LIS data for display in the DataTable UI. It is typically structured as:

```dart
List<List<dynamic>> tableData;
```

- Each element of `tableData` is a row, containing values for each column (datum/curve) in the LIS file.
- The number of columns matches the number of datum blocks (curves) defined in the file.
- Values are parsed and converted to their correct types (float, int, string, ...), ready for display.
- For array-type data (e.g., WF1, WF2), the cell may contain a summary, a clickable indicator, or a reference to the full array data (not all array values are shown directly in the table).

**Example:**
```dart
tableData = [
  [1000.0, 12.5, 8.2, '...', ...], // row 1: depth, value1, value2, array summary, ...
  [1001.0, 13.0, 8.5, '...', ...], // row 2
  ...
];
```

- `tableData` is populated by calling a parser method (e.g. `getTableData()`), which processes raw LIS records and datum blocks into a display-ready format.
- The UI uses `tableData` to render the DataTable, allowing for sorting, editing, and viewing details.

See `lib/widgets/data_table_widget.dart` and `lib/services/lis_file_parser.dart` for implementation details.
