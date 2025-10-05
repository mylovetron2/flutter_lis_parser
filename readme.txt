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

## Tài liệu tham khảo
- LIS Specification Documentation
- API RP66 (Digital Log Interchange Standard)
- Schlumberger/Halliburton logging tool specifications
- IEEE 754 Floating Point Standard

---
Generated by Flutter LIS Parser
Date: October 5, 2025