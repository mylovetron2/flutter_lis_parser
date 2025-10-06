# Flutter LIS Parser - Detailed Documentation

## Tổng quan về định dạng LIS (Log Information Standard)

LIS (Log Information Standard) là một định dạng file binary được sử dụng rộng rãi trong ngành dầu khí để lưu trữ dữ liệu logging từ các giếng khoan. File LIS chứa các thông tin như độ sâu, thời gian, và các đo lường từ các công cụ logging khác nhau.

## Cấu trúc tổng quát của file LIS

### 1. Header Records (Các bản ghi đầu)
- **File Header Record (Type 128/0x80)**: Thông tin về file
- **Tape Header Record (Type 130)**: Thông tin về băng từ
- **Real Header Record (Type 132)**: Thông tin về reel

### 2. Data Format Specification Record (Type 64/0x40)
Bản ghi quan trọng nhất, định nghĩa cấu trúc dữ liệu:
- **Datum Specification Blocks**: Mô tả từng loại dữ liệu (datum)
- **Frame Format**: Cách tổ chức dữ liệu trong mỗi frame
- **Depth Recording Mode**: Chế độ ghi độ sâu

### 3. Data Records (Type 0)
Chứa dữ liệu thực tế được tổ chức theo frames

### 4. Trailer Records
- **File Trailer Record (Type 129)**
- **Tape Trailer Record (Type 131)**
- **Real Trailer Record (Type 133)**

## Cấu trúc chi tiết của Data Format Specification Record

### Header của DFS Record (34 bytes)
```
Offset  Size  Type     Description
0-1     2     uint16   Record Length (big-endian)
2       1     byte     Attributes  
3       1     byte     Record Type (64)
4-19    16    char     Service Company Name
20-23   4     char     Service Company Number  
24-27   4     char     Date (YYDDD format)
28-29   2     char     Origin of Recording
30      1     byte     Copy Number
32      1     byte     Destination
33      1     byte     Reserved
```

### Format Specification Index (FSI) - 12 bytes
```
Offset  Size  Type     Description
0       1     byte     Structure Identifier
1       1     byte     Format Organization
2       1     byte     Record Mode
3       1     byte     Depth Recording Mode (0=depth-per-frame, 1=depth-per-sample)
4-5     2     uint16   Data Frame Size (big-endian)
6       1     byte     Depth Representation Code
7-10    4     float    Depth Reprogression Constant
11      1     byte     Depth Absence Value
```

### Datum Specification Blocks
Mỗi datum được mô tả bởi một block 32 bytes:

```
Offset  Size  Type     Description
0-7     8     char     Mnemonic (tên datum, vd: "DEPT", "WF1")
8-11    4     char     Service ID
12-15   4     char     Service Order Number  
16-19   4     char     Units (đơn vị đo)
20-23   4     char     API Codes
24-25   2     uint16   File Number (big-endian)
26-27   2     uint16   Size in bytes (big-endian) ⭐ QUAN TRỌNG
28-30   3     -        Reserved
31      1     byte     Number of Samples
32      1     byte     Representation Code ⭐ QUAN TRỌNG
```

#### Representation Codes quan trọng:
- **68**: 4-byte IEEE Float (little-endian)
- **73**: 4-byte Signed Integer (little-endian) 
- **79**: 1-byte Unsigned Integer
- **Other codes**: Xem LIS spec để biết chi tiết

## Cách đọc Data Records

### 1. Định vị Data Record
```
Data Record Structure:
- 2 bytes: Record Length (big-endian)
- 1 byte:  Attributes
- 1 byte:  Record Type (0 for data)
- N bytes: Frame Data
```

### 2. Đọc Frame Data

#### Depth-per-Frame Mode (depthRecordingMode = 0)
Mỗi frame có cấu trúc:
```
Frame = [DEPT] + [Datum1] + [Datum2] + ... + [DatumN]
```

#### Depth-per-Sample Mode (depthRecordingMode = 1)
Depth được lặp lại cho mỗi sample trong frame.

### 3. Đọc từng Datum

#### Single Value Datums (size ≤ 4 bytes)
```cpp
// Ví dụ: DEPT (4 bytes, RepCode 68 - IEEE Float)
float depth;
memcpy(&depth, frameData + offset, 4);
offset += 4;
```

#### Array Datums (size > 4 bytes)
```cpp
// Ví dụ: WF1 (512 bytes = 256 samples * 2 bytes, RepCode 79)
uint8_t waveform[256];
for(int i = 0; i < 256; i++) {
    waveform[i] = frameData[offset + i];
}
offset += 512; // Đọc toàn bộ 512 bytes cho frame hiện tại
```

## Ví dụ cụ thể: Russian LIS Format

### Datum Specifications trong file Russian LIS:
```
Datum 0: DEPT, size=4, reprCode=68, dataItemNum=1    (Depth - Float)
Datum 1: TIME, size=4, reprCode=73, dataItemNum=1    (Time - Integer)  
Datum 2: SPEE, size=4, reprCode=68, dataItemNum=1    (Speed - Float)
Datum 3: WF1,  size=512, reprCode=79, dataItemNum=256 (Waveform 1 - 256 bytes)
Datum 4: WF2,  size=512, reprCode=79, dataItemNum=256 (Waveform 2 - 256 bytes)
Datum 5: WF3,  size=512, reprCode=79, dataItemNum=256 (Waveform 3 - 256 bytes)  
Datum 6: WF4,  size=512, reprCode=79, dataItemNum=256 (Waveform 4 - 256 bytes)
Datum 7: VACC, size=4, reprCode=68, dataItemNum=1    (Voltage - Float)
... (other single-value datums)
```

### Frame Structure:
```
Frame Size: 2146 bytes
Frame Layout: [DEPT:4] + [TIME:4] + [SPEE:4] + [WF1:512] + [WF2:512] + [WF3:512] + [WF4:512] + [VACC:4] + ...
```

### Reading Logic:
```
for each frame in record:
    byteOffset = frameIndex * 2146
    
    // Read single values  
    DEPT = readFloat(data[byteOffset:byteOffset+4])
    byteOffset += 4
    
    TIME = readInt32(data[byteOffset:byteOffset+4]) 
    byteOffset += 4
    
    SPEE = readFloat(data[byteOffset:byteOffset+4])
    byteOffset += 4
    
    // Read array values (ALL elements in current frame)
    WF1_array = readBytes(data[byteOffset:byteOffset+512])  // 256 elements
    byteOffset += 512
    
    WF2_array = readBytes(data[byteOffset:byteOffset+512])  // 256 elements  
    byteOffset += 512
    
    // ... continue for WF3, WF4, and other datums
```

## Lỗi thường gặp và cách khắc phục

### 1. Byte Order Issues
**Vấn đề**: Size field đọc sai do little-endian vs big-endian
**Giải pháp**: 
```dart
// ĐÚNG: Big-endian for LIS format
final size = data[index] * 256 + data[index + 1];

// SAI: Little-endian  
final size = data[index + 1] * 256 + data[index];
```

### 2. Array Reading Logic
**Vấn đề**: Đọc 1 element per frame thay vì toàn bộ array
**Giải pháp**:
```dart
// ĐÚNG: Đọc ALL elements của array trong frame hiện tại
if (datum.size > 4) {
    // Array datum - read all elements for current frame
    byteDataIdx += datum.size;  // Skip entire array (512 bytes for WF1-WF4)
} else {
    // Single datum - read one value  
    byteDataIdx += datum.size;  // 4 bytes for DEPT, TIME, etc.
}
```

### 3. Frame Size Calculation
**Vấn đề**: Tính sai frame size dẫn đến đọc sai data
**Giải pháp**: 
```dart
// Frame size = tổng size của tất cả datums
int frameSize = 0;
for (var datum in datumBlocks) {
    frameSize += datum.size;
}
// Hoặc sử dụng dataFormatSpec.dataFrameSize từ FSI
```

## Công cụ Debug

### 1. Log Datum Information
```dart
print('Datum ${i}: ${datum.mnemonic}, size=${datum.size}, reprCode=${datum.reprCode}, dataItemNum=${datum.dataItemNum}');
```

### 2. Track Byte Position
```dart
print('=== Starting frame $frameIdx, byteDataIdx=$byteDataIdx ===');
// ... read data ...
print('=== Completed frame $frameIdx, final byteDataIdx=$byteDataIdx ===');
```

### 3. Verify Data Ranges
```dart
// Check if array data looks reasonable
if (arrayData.isNotEmpty) {
    final min = arrayData.reduce(math.min);
    final max = arrayData.reduce(math.max);
    print('Array ${datum.mnemonic}: ${arrayData.length} values, range [$min, $max]');
}
```

## Implementation trong Flutter App

### Core Classes:
- **LisFileParser**: Main parser class
- **DatumSpecBlock**: Represents each datum specification  
- **DataFormatSpec**: Frame format information
- **WaveformViewerDialog**: UI cho việc hiển thị waveform charts

### Key Methods:
- **parseDataFormatSpecRecord()**: Parse DFS record
- **getAllData()**: Read và parse tất cả data frames
- **getArrayData()**: Extract specific array data cho visualization
- **getTableData()**: Generate data cho DataTable UI

### UI Features:
- **Data Table**: Hiển thị "..." cho array columns
- **Clickable Arrays**: Click "..." để mở waveform viewer
- **Interactive Charts**: fl_chart library với tooltips và statistics
- **Material Design 3**: Modern UI/UX

## CHỨC NĂNG LƯU FILE - HƯỚNG DẪN CHI TIẾT

### Tổng quan chức năng Save/Edit
Ứng dụng hỗ trợ chỉnh sửa trực tiếp dữ liệu LIS và lưu ngay vào file gốc với đầy đủ tính năng backup và validation.

### Cách sử dụng chức năng lưu file:

#### 1. Bật chế độ chỉnh sửa:
```
- Click nút "Edit" ở góc trên bên phải của bảng dữ liệu  
- Icon: ✏️ (Edit Mode OFF) → 🔓 (Edit Mode ON)
- Các ô có thể chỉnh sửa sẽ có viền xanh khi hover
- Help text hiển thị hướng dẫn sử dụng
```

#### 2. Chỉnh sửa dữ liệu:
```
- Click vào ô cần chỉnh sửa (trừ cột DEPT - chỉ đọc)
- TextField xuất hiện với giá trị hiện tại
- Nhập giá trị mới (chỉ chấp nhận số)
- Nhấn Enter hoặc click nút ✓ để xác nhận
- Nhấn Esc hoặc click nút ✗ để hủy
- Ô được highlight màu cam sau khi chỉnh sửa
- Counter hiển thị số lượng thay đổi chưa lưu
```

#### 3. Lưu thay đổi:
```
- Khi có thay đổi, nút "Save" (💾) xuất hiện trong header
- Click nút Save để mở dialog xác nhận
- Dialog hiển thị số lượng thay đổi và đường dẫn file
- Click "Save" để thực hiện lưu file
- Loading indicator hiển thị trong quá trình lưu
- Success/Error message hiển thị kết quả
```

### Đặc điểm kỹ thuật của chức năng Save:

#### A. Thuật toán định vị dữ liệu trong file:
```dart
// Tính toán vị trí byte chính xác trong file LIS
File Position = Record Address + Byte Offset

Byte Offset = Header Size + (Frame Index × Frame Size) + Datum Offset + 4-byte Correction

Trong đó:
- Header Size: 4 bytes (Russian LIS) hoặc 6 bytes (NTI)  
- Frame Size: dataFormatSpec.dataFrameSize (ví dụ: 2146 bytes)
- Datum Offset: Tổng kích thước các datum trước datum target
- 4-byte Correction: CRITICAL FIX để match với parsing logic

Ví dụ cụ thể cho ACHV:
- Record Address: 30397 (từ LIS record)
- Frame Index: 0 (frame đầu tiên)
- Frame Size: 2146 bytes  
- Datum Offset: 2064 bytes (DEPT+TIME+SPEE+WF1+WF2+WF3+WF4+VACC)
- 4-byte Correction: +4 bytes
- Final Position: 30397 + 0 + 2068 = 32465
```

#### B. Encoding dữ liệu theo Representation Code:

##### RepCode 68 - Russian LIS Float (4 bytes):
```dart
// Custom encoding algorithm matching C++ ReadCode logic
Uint8List _encodeRussianLisFloat(double value) {
  // Handle sign bit
  bool isNegative = value < 0;
  double absValue = value.abs();
  
  // Normalize fraction to [0.5, 1.0) range
  double targetFraction = absValue;
  int exponentBits = isNegative ? 127 : 128;
  
  while (targetFraction >= 1.0) {
    targetFraction /= 2.0;
    exponentBits += isNegative ? -1 : 1;
  }
  while (targetFraction < 0.5) {
    targetFraction *= 2.0;
    exponentBits += isNegative ? 1 : -1;
  }
  
  // Convert to 23-bit mantissa
  int mantissaBits = 0;
  // ... (algorithm implementation)
  
  // Assemble 32-bit result: [Sign:1][Exponent:8][Mantissa:23]
  // Return as big-endian bytes [ch0, ch1, ch2, ch3]
}

Ví dụ:
80.0 → bytes [67, 160, 0, 0] (hex: 43 A0 00 00)
4.72 → bytes [65, 203, 140, 191] (hex: 41 CB 8C BF)
```

##### Các RepCode khác:
```dart
RepCode 73: 4-byte Integer (little-endian)
RepCode 70: 4-byte IBM Float  
RepCode 49: 2-byte Float
RepCode 79: 2-byte Integer (big-endian)
```

#### C. An toàn dữ liệu:
```
1. Backup tự động:
   - Tạo file [filename].backup trước mỗi lần lưu
   - Preserve file permissions và timestamps
   
2. Memory-based modification:
   - Đọc toàn bộ file vào memory
   - Thực hiện các thay đổi trong memory
   - Ghi một lần duy nhất vào file
   
3. File handle management:
   - Close file handle trước khi write
   - Re-open file handle sau khi write
   - Tránh conflicts với other processes
   
4. Validation:
   - Round-trip verification: value → bytes → value
   - Position bounds checking
   - Data type validation
```

#### D. Debug và troubleshooting:
```
Debug Output Examples:

=== SAVE BUTTON CLICKED ===
Number of pending changes: 1
========================================
SAVE PENDING CHANGES CALLED!
File being saved: D:\data\sample.lis
========================================

DEBUG: Updating bytes for record 40, frame 0, datum ACHV
DEBUG: Found target datum ACHV at index 8, datumOffset=2064
DEBUG: Added 4 bytes correction, final datumOffset=2068
DEBUG: After datum offset: byteOffset=10654 (datumOffset=2068)
DEBUG: Final file position=41051 (record.addr=30397 + byteOffset=10654)

DEBUG: Encoded value 80.0 (reprCode=68) to 4 bytes: 43 a0 00 00
DEBUG: Current bytes at position 41051: 41 cb 8c bf
DEBUG: Current value decoded at position 41051: 4.721861839294434
DEBUG: Written bytes at position 41051: 43 a0 00 00  
DEBUG: New value decoded after write: 80.0

Original file size: 1112769 bytes
Modified bytes length: 1112769 bytes
New file size after write: 1112769 bytes

Successfully saved 1 changes to file
========================================
SAVE COMPLETED SUCCESSFULLY!  
========================================
```

### Workflow cụ thể cho các trường hợp:

#### Trường hợp 1: Chỉnh sửa giá trị ACHV
```
1. Edit Mode ON
2. Click vào ô ACHV (frame 0) = 4.72
3. Input: 80.0 → Enter
4. Cell highlight orange, counter: "1 change"
5. Click Save button
6. Confirmation: "Save 1 changes to file?"
7. System creates backup: sample.lis.backup
8. Memory update at position 41051: [41 cb 8c bf] → [43 a0 00 00]
9. File write successful
10. Success message: "Changes saved successfully!"
11. Orange highlight cleared, counter reset
```

#### Trường hợp 2: Multiple changes
```
1. Edit ACHV: 4.72 → 80.0
2. Edit VACC: 2.15 → 5.5  
3. Edit SPEE: 1.2 → 2.4
4. Counter: "3 changes"
5. Save all at once with batch processing
6. Each change gets individual debug output
7. Single file write operation
```

#### Trường hợp 3: Reset changes
```
1. Make several edits (orange highlights)
2. Click "Reset" button (🔄)
3. Confirmation dialog: "Discard all unsaved changes?"
4. All orange highlights cleared
5. Values reverted to original
6. Counter reset to 0
```

### Error handling và troubleshooting:

#### Lỗi thường gặp:
```
1. "Position out of bounds":
   - File bị corrupt
   - Sai calculation offset
   - Check: file size vs calculated position

2. "Failed to update change":  
   - File being used by another process
   - Insufficient permissions
   - Disk full

3. "Encoding error":
   - Invalid representation code
   - Value out of range for data type
   - Check: value fits in target format

4. "File handle conflict":
   - Multiple instances accessing same file
   - Solution: Close other applications
```

#### Debug checklist:
```
☐ File path accessible and writable
☐ Backup file created successfully  
☐ Datum offset calculation matches parsing
☐ Representation code encoding correct
☐ Round-trip verification passes
☐ File size unchanged after write
☐ No error messages in debug output
```

### Performance và limitations:

#### Performance characteristics:
```
- Small files (<10MB): Instant save
- Large files (>100MB): 1-3 seconds save time
- Memory usage: ~2x file size during save
- Backup creation: Additional disk space = file size
```

#### Current limitations:
```
- Array datums (WF1-WF4): View only, cannot edit
- DEPT column: Read-only to maintain data integrity
- Single file editing: No batch file processing
- Text datums: Limited support, focus on numeric data
```

### Best practices:

#### Trước khi chỉnh sửa:
```
✅ Backup file quan trọng manually
✅ Understand ý nghĩa của từng datum
✅ Test với file nhỏ trước
✅ Check available disk space
✅ Close other LIS applications
```

#### Trong quá trình chỉnh sửa:
```
✅ Save frequently với small batches
✅ Verify values make sense (không âm cho depth, etc.)
✅ Monitor debug output for errors
✅ Check counter matches số thay đổi thực tế
```

#### Sau khi lưu:
```
✅ Reload file để verify changes
✅ Compare với backup file nếu cần
✅ Check file integrity với other LIS tools
✅ Keep backup files cho rollback
```

## Tài liệu tham khảo
- LIS Specification Documentation
- API RP66 (Digital Log Interchange Standard)
- Schlumberger/Halliburton logging tool specifications
- IEEE 754 Floating Point Standard
- Flutter File I/O Best Practices
- Russian LIS Format Implementation Notes

---
Generated by Flutter LIS Parser with Save Functionality
Date: October 6, 2025
Version: 1.0 - Complete LIS editing and save capabilities