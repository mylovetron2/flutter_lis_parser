import 'dart:math';
import 'dart:typed_data';
import 'dart:io';

import 'lis_record.dart';

// LIS Logical Record Types
const int LRTYPE_NORMALDATA = 0;
const int LRTYPE_JOBID = 32;
const int LRTYPE_WELLSITEDATA = 34;
const int LRTYPE_TOOLSTRINGINFO = 39;
const int LRTYPE_TABLEDUMP = 47;
const int LRTYPE_DATAFORMATSPEC = 64;
const int LRTYPE_FILEHEADER = 128;
const int LRTYPE_FILETRAILER = 129;
const int LRTYPE_TAPEHEADER = 130;
const int LRTYPE_TAPETRAILER = 131;
const int LRTYPE_REELHEADER = 132;
const int LRTYPE_REELTRAILER = 133;
const int LRTYPE_COMMENT = 232;

// LIS Representation Codes
const int REPRCODE_49 = 49; // 16 bit floating Point (size = 2)
const int REPRCODE_50 = 50; // 32 bit low resolution floating Point (size = 4)
const int REPRCODE_56 = 56; // 8 bit 2's complement integer (size = 1)
const int REPRCODE_65 = 65;
const int REPRCODE_66 = 66; // byte format (size = 1)
const int REPRCODE_68 = 68; // 32 bit floating Point (size = 4)
const int REPRCODE_70 = 70; // 32 bit Fix Point (size = 4)
const int REPRCODE_73 = 73; // 32 bit 2's complement integer (size = 4)
const int REPRCODE_79 = 79; // 16 bit 2's complement integer (size = 2)

// Other constants
const int MAX_LOGICALFILENUM = 10;
const int FILE_TYPE_LIS = 1;
const int FILE_TYPE_NTI = 2;

// Top-level class definitions
class PhysicalRecord {
  int length;
  int address;
  int attr1;
  int attr2;
  PhysicalRecord({
    required this.length,
    required this.address,
    required this.attr1,
    required this.attr2,
  });
}

class LogicalRecord {
  int length;
  int address;
  int type;
  int physicalRecordNum;
  List<PhysicalRecord> prArr;
  LogicalRecord({
    required this.length,
    required this.address,
    required this.type,
    required this.physicalRecordNum,
    required this.prArr,
  });
}

class ReprCodeReturn {
  int type; // 1=Integer; 2=double; 3=string
  double fValue;
  String strValue;
  int nValue;
  ReprCodeReturn({
    this.type = 1,
    this.fValue = 0,
    this.strValue = '',
    this.nValue = 0,
  });
  void init() {
    type = 1;
    fValue = 0;
    nValue = 0;
    strValue = '';
  }

  @override
  String toString() {
    if (type == 1) return nValue.toString();
    if (type == 2) return fValue.toString();
    if (type == 3) return strValue;
    return '';
  }
}

class LogicalFile {
  int nFirstIFLR1;
  int nEndIFLR1;
  List<List<int>> jobIDPos = [];
  List<List<int>> wellsiteDataPos = [];
  List<List<int>> toolStringInfoPos = [];
  List<List<int>> tableDumpPos = [];
  List<List<int>> dataFormatSpecPos = [];
  List<List<int>> fileHeaderPos = [];
  List<List<int>> fileTrailerPos = [];
  List<List<int>> tapeHeaderPos = [];
  List<List<int>> tapeTrailerPos = [];
  List<List<int>> reelHeaderPos = [];
  List<List<int>> reelTrailerPos = [];
  List<List<int>> commentPos = [];
  LogicalFile({this.nFirstIFLR1 = -1, this.nEndIFLR1 = -1});
  void releaseResources() {
    jobIDPos.clear();
    wellsiteDataPos.clear();
    toolStringInfoPos.clear();
    tableDumpPos.clear();
    dataFormatSpecPos.clear();
    fileHeaderPos.clear();
    fileTrailerPos.clear();
    tapeHeaderPos.clear();
    tapeTrailerPos.clear();
    reelHeaderPos.clear();
    reelTrailerPos.clear();
    commentPos.clear();
  }
}

class EntryBlock {
  int nDataRecordType = 0;
  int nDatumSpecBlockType = 0;
  int nDataFrameSize = 0;
  int nDirection = 0;
  int nOpticalDepthUnit = 0;
  double fDataRefPoint = 0;
  String strDataRefPointUnit = '';
  double fFrameSpacing = 0;
  String strFrameSpacingUnit = '';
  int nMaxFramesPerRecord = 0;
  double fAbsentValue = -999.255;
  int nDepthRecordingMode = 0;
  String strDepthUnit = '';
  int nDepthRepr = 68;
  int nDatumSpecBlockSubType = 0;
  EntryBlock();
}

class DatumSpecBlock {
  String strMnemonic = '';
  String strServiceID = '';
  String strServiceOrderNb = '';
  String strUnits = '';
  int nFileNb = 0;
  int nSize = 0;
  int nNbSamples = 0;
  int nReprCode = 0;
  int nDatasetIdx = 0;
  int nIndexInDataset = 0;
  int nPosInDataset = 0;
  List<double>? fData;
  int nDataItemNum = 0;
  int nOffsetInBytes = 0;
  bool bLoad = false;
  String strMnemonicLoad = '';
  String strUnitsLoad = '';
  int nIdxInDatabase = 0;
  bool bFlwChan = false;
  bool bLoadNew = false;
  DatumSpecBlock();
}

class Dataset {
  String strDATFileName = '';
  int nNbSamples = 1;
  double fStep = 0.1;
  int nTotalItemNum = 0;
  RandomAccessFile? hFile;
  bool bLoad = false;
  double fDepth1 = 0;
  List<double>? fData1;
  double fDepth2 = 0;
  List<double>? fData2;
  double fFactor = 1.0;
  int nTimeCount = 0;
  Dataset();
}

class LISMisc {
  static int getReprCodeSize(int nReprCode) {
    switch (nReprCode) {
      case 56:
      case 66:
        return 1;
      case 49:
      case 79:
        return 2;
      case 50:
      case 68:
      case 70:
      case 73:
        return 4;
    }
    return 2;
  }

  static String findLogicalRecordTypeName(int nType) {
    switch (nType) {
      case 0:
        return 'Normal Data';
      case 1:
        return 'Alternate Data';
      case 32:
        return 'Job Identification';
      case 34:
        return 'Wellsite Data';
      case 39:
        return 'Tool String Info';
      case 42:
        return 'Encrypted Table Dump';
      case 47:
        return 'Table Dump';
      case 64:
        return 'Data Format Specification';
      case 65:
        return 'Data Descriptor';
      case 95:
        return 'TU10 Software Boot';
      case 96:
        return 'Bootstrap Loader';
      case 97:
        return 'CP-Kernel Loader Boot';
      case 100:
        return 'Program File Header';
      case 101:
        return 'Program Overlay Header';
      case 102:
        return 'Program Overlay Load';
      case 128:
        return 'File Header';
      case 129:
        return 'File Trailer';
      case 130:
        return 'Tape Header';
      case 131:
        return 'Tape Trailer';
      case 132:
        return 'Real Header';
      case 133:
        return 'Real Trailer';
      case 137:
        return 'Logical EOF';
      case 138:
        return 'Logical BOT';
      case 139:
        return 'Logical EOT';
      case 141:
        return 'Logical EOM';
      case 224:
        return 'Operator Command Inputs';
      case 225:
        return 'Operator Response Inputs';
      case 227:
        return 'System Outputs to Operator';
      case 232:
        return 'FLIC Comment';
      case 234:
        return 'Blank Record/CSU Comment';
      case 85:
        return 'Picture';
      case 86:
        return 'Image';
    }
    return 'Unknown';
  }

  static int convert4Bytes2Long(List<int> group) {
    int l16x2 = 256;
    int l16x4 = 65536;
    int l16x6 = 16777216;
    return group[0] + group[1] * l16x2 + group[2] * l16x4 + group[3] * l16x6;
  }

  static double convertDepthValue(
    double fDepth,
    String strOldDU,
    String strNewDU,
  ) {
    double fDepth1 = fDepth;
    // 1 inch = 2.54 centimeters
    // 1 foot = 30.48 centimeters
    // 1 foot = 12 in
    strOldDU = strOldDU.toLowerCase().trim();
    strNewDU = strNewDU.toLowerCase().trim();
    double fFactor = 1.0;
    // Xử lý trường hợp đơn vị có dạng 0.1 in, 20 cm
    int idx = 0;
    while (idx < strOldDU.length &&
        (strOldDU[idx].contains(RegExp(r'[0-9.]')))) {
      idx++;
    }
    String strFactor = strOldDU.substring(0, idx);
    if (strFactor.isNotEmpty) {
      fFactor = double.tryParse(strFactor) ?? 1.0;
    }
    String strUnit = strOldDU.substring(idx);
    strOldDU = strUnit;
    if (strNewDU == 'm') {
      if (strOldDU == 'cm')
        fDepth1 = fDepth * fFactor / 100.0;
      else if (strOldDU == 'mm')
        fDepth1 = fDepth * fFactor / 1000.0;
      else if (strOldDU == 'dm')
        fDepth1 = fDepth * fFactor / 10.0;
      else if (strOldDU == 'in')
        fDepth1 = fDepth * fFactor * 2.54 / 100.0;
      else if (strOldDU == 'ft')
        fDepth1 = fDepth * fFactor * 30.48 / 100.0;
      else if (strOldDU == 'm')
        fDepth1 = fDepth * fFactor;
    }
    return fDepth1;
  }

  static void readReprCode(
    List<int> byteArr,
    int nCount,
    int nReprCode,
    ReprCodeReturn ret,
    int nCurPos,
  ) {
    ret.init();
    if (nReprCode == 49) {
      int b1 = byteArr[nCurPos];
      int b2 = byteArr[nCurPos + 1];
      int raw = (b2 << 8) | b1;
      int sign = (raw >> 15) & 0x1;
      int exp = (raw >> 10) & 0x1F;
      int frac = raw & 0x3FF;
      double value;
      if (exp == 0) {
        value = frac * pow(2, -24).toDouble();
      } else if (exp == 0x1F) {
        value = double.nan;
      } else {
        value =
            pow(-1, sign).toDouble() *
            pow(2, exp - 15).toDouble() *
            (1 + frac / 1024.0);
      }
      ret.type = 2;
      ret.fValue = value;
      return;
    }
    if (nReprCode == 50 || nReprCode == 68) {
      // 32-bit float
      var bytes = Uint8List.fromList(byteArr.sublist(nCurPos, nCurPos + 4));
      var bd = ByteData.sublistView(bytes);
      double value = bd.getFloat32(0, Endian.little);
      ret.type = 2;
      ret.fValue = value;
      return;
    }
    if (nReprCode == 56 || nReprCode == 66) {
      int b1 = byteArr[nCurPos];
      ret.type = 1;
      ret.nValue = b1;
      return;
    }
    if (nReprCode == 65) {
      List<int> strBytes = byteArr.sublist(nCurPos, nCurPos + nCount);
      ret.type = 3;
      ret.strValue = String.fromCharCodes(strBytes);
      return;
    }
    if (nReprCode == 73) {
      var bytes = Uint8List.fromList(byteArr.sublist(nCurPos, nCurPos + 4));
      var bd = ByteData.sublistView(bytes);
      int value = bd.getInt32(0, Endian.little);
      ret.type = 1;
      ret.nValue = value;
      return;
    }
    if (nReprCode == 79) {
      var bytes = Uint8List.fromList(byteArr.sublist(nCurPos, nCurPos + 2));
      var bd = ByteData.sublistView(bytes);
      int value = bd.getInt16(0, Endian.little);
      ret.type = 1;
      ret.nValue = value;
      return;
    }
    ret.type = 1;
    ret.nValue = -1;
  }
}

class LISFileClass {
  String strFileName = '';
  String strDirName = '';
  RandomAccessFile? hFile;
  int nFileSize = 0;
  int nFileType = 0;
  List<LogicalRecord> lrArr = [];
  int nLogicalRecordNum = 0;
  List<LogicalFile> logicalFileArr = [];
  int nCurLogicalFile = 0;
  int nLogicalFileNum = 0;
  List<Dataset> datasetArr = [];
  EntryBlock entryBlock = EntryBlock();
  List<DatumSpecBlock> chansArr = [];
  // Các mảng vị trí record cho từng loại record trong logical file
  List<List<int>> JobIDPos = [];
  List<List<int>> WellsiteDataPos = [];
  List<List<int>> ToolStringInfoPos = [];
  List<List<int>> TableDumpPos = [];
  List<List<int>> DataFormatSpecPos = [];
  List<List<int>> FileHeaderPos = [];
  List<List<int>> FileTrailerPos = [];
  List<List<int>> CommentPos = [];
  int nFirstIFLR1 = -1;
  int nEndIFLR1 = -1;
  int nLogRecMaxSize = 0;
  int nDepthCurveIdx = -1;
  int nFrameSizeInBytes = 0;
  Uint8List? pBytesBuf;
  double fStep = 0.0;
  double fStartDepth = 0.0;
  double fEndDepth = 0.0;
  int nMaxNbSamples = 1;

  LISFileClass({required this.strFileName});

  void releaseResources() {
    lrArr.clear();
    logicalFileArr.clear();
    datasetArr.clear();
    chansArr.clear();
    pBytesBuf = null;
    nLogicalRecordNum = 0;
    nLogicalFileNum = 0;
    nCurLogicalFile = 0;
    nMaxNbSamples = 1;
    nDepthCurveIdx = -1;
    nFrameSizeInBytes = 0;
    fStep = 0.0;
    fStartDepth = 0.0;
    fEndDepth = 0.0;
  }

  void releaseEFLRArr({bool all = true}) {
    // TODO: Xóa các mảng liên quan đến EFLR nếu có
  }

  int getNextPR(int nLRNum, int nCurIdx1, int nCurIdx2, List<int> outNextIdx) {
    // TODO: Trả về chỉ số PR tiếp theo trong LogicalRecord
    return -1;
  }

  int getPrevPR(int nCurIdx1, int nCurIdx2, List<int> outPrevIdx) {
    // TODO: Trả về chỉ số PR trước đó trong LogicalRecord
    return -1;
  }

  Future<void> parseLogicalFile(int nCurLF) async {
    if (lrArr.isEmpty) return;
    if (nCurLF < 0 || nCurLF >= nLogicalFileNum) return;
    releaseEFLRArr();
    // Copy các vị trí record từ logicalFileArr[nCurLF] sang các mảng của LISFileClass
    JobIDPos = List.from(logicalFileArr[nCurLF].jobIDPos);
    WellsiteDataPos = List.from(logicalFileArr[nCurLF].wellsiteDataPos);
    ToolStringInfoPos = List.from(logicalFileArr[nCurLF].toolStringInfoPos);
    TableDumpPos = List.from(logicalFileArr[nCurLF].tableDumpPos);
    DataFormatSpecPos = List.from(logicalFileArr[nCurLF].dataFormatSpecPos);
    FileHeaderPos = List.from(logicalFileArr[nCurLF].fileHeaderPos);
    FileTrailerPos = List.from(logicalFileArr[nCurLF].fileTrailerPos);
    CommentPos = List.from(logicalFileArr[nCurLF].commentPos);
    nFirstIFLR1 = logicalFileArr[nCurLF].nFirstIFLR1;
    nEndIFLR1 = logicalFileArr[nCurLF].nEndIFLR1;
    await parseDataFormatSpecRecord();
    nDepthCurveIdx = -1;
    if (entryBlock.nDepthRecordingMode == 0) {
      for (int i = 0; i < chansArr.length; i++) {
        String str = chansArr[i].strMnemonic.toUpperCase();
        if (str == "DEPT" || str == "DEP") {
          nDepthCurveIdx = i;
          break;
        }
      }
      if (nDepthCurveIdx == -1) nDepthCurveIdx = 0;
    }
    nLogRecMaxSize = lrArr[nFirstIFLR1].length;
    for (int i = nFirstIFLR1; i <= nEndIFLR1; i++) {
      if (lrArr[i].length > nLogRecMaxSize) nLogRecMaxSize = lrArr[i].length;
    }
    pBytesBuf = Uint8List(nLogRecMaxSize);
    nFrameSizeInBytes = 0;
    for (var chan in chansArr) {
      nFrameSizeInBytes += chan.nSize;
    }
    fStep = LISMisc.convertDepthValue(
      entryBlock.fFrameSpacing,
      entryBlock.strFrameSpacingUnit,
      "m",
    );
    fStartDepth = getStartDepth();
    fEndDepth = getEndDepth(fStep);
    await createDataSet();
  }

  Future<void> parseDataFormatSpecRecord() async {
    // Xóa các channel cũ
    releaseChansArr();
    // Tìm vị trí DataFormatSpec
    if (logicalFileArr.isEmpty || logicalFileArr[0].dataFormatSpecPos.isEmpty)
      return;
    final pt = logicalFileArr[0].dataFormatSpecPos[0];
    final nIdx1 = pt[0];
    // final nIdx2 = pt[1]; // Không sử dụng
    final lr = lrArr[nIdx1];
    // Tính tổng kích thước
    int nTotalSize = lr.prArr[0].length - 6;
    bool bFileNumPresence = (lr.prArr[0].attr1 & 0x4) > 0;
    bool bRecordNumPresence = (lr.prArr[0].attr1 & 0x2) > 0;
    if (bFileNumPresence) nTotalSize -= 2;
    if (bRecordNumPresence) nTotalSize -= 2;
    for (int i = 1; i < lr.physicalRecordNum; i++) {
      nTotalSize += lr.prArr[i].length - 4;
      bFileNumPresence = (lr.prArr[i].attr1 & 0x4) > 0;
      bRecordNumPresence = (lr.prArr[i].attr1 & 0x2) > 0;
      if (bFileNumPresence) nTotalSize -= 2;
      if (bRecordNumPresence) nTotalSize -= 2;
    }
    // Đọc dữ liệu vào byteArr
    Uint8List byteArr = Uint8List(nTotalSize + 100);
    int nCurrentSize = 0;
    await hFile!.setPosition(lr.prArr[0].address + 6);
    var bytes0 = await hFile!.read(lr.prArr[0].length - 6);
    byteArr.setRange(nCurrentSize, nCurrentSize + bytes0.length, bytes0);
    nCurrentSize += bytes0.length;
    bFileNumPresence = (lr.prArr[0].attr1 & 0x4) > 0;
    bRecordNumPresence = (lr.prArr[0].attr1 & 0x2) > 0;
    if (bFileNumPresence) nCurrentSize -= 2;
    if (bRecordNumPresence) nCurrentSize -= 2;
    for (int i = 1; i < lr.physicalRecordNum; i++) {
      await hFile!.setPosition(lr.prArr[i].address + 4);
      var bytesI = await hFile!.read(lr.prArr[i].length - 4);
      byteArr.setRange(nCurrentSize, nCurrentSize + bytesI.length, bytesI);
      nCurrentSize += bytesI.length;
      bFileNumPresence = (lr.prArr[i].attr1 & 0x4) > 0;
      bRecordNumPresence = (lr.prArr[i].attr1 & 0x2) > 0;
      if (bFileNumPresence) nCurrentSize -= 2;
      if (bRecordNumPresence) nCurrentSize -= 2;
    }
    // Đọc EntryBlock
    int nCurPos = 0;
    entryBlock = EntryBlock();
    int nEntryBlockType = byteArr[nCurPos++];
    int nSize = byteArr[nCurPos++];
    int nReprCode = byteArr[nCurPos++];
    Uint8List entry = Uint8List(1000);
    for (int i = 0; i < nSize; i++) entry[i] = byteArr[nCurPos++];
    ReprCodeReturn ret = ReprCodeReturn();
    // int nRealSize = 0; // Không sử dụng
    while (nEntryBlockType != 0) {
      switch (nEntryBlockType) {
        case 1:
          LISMisc.readReprCode(entry, nSize, nReprCode, ret, 0);
          entryBlock.nDataRecordType = ret.nValue;
          break;
        case 2:
          LISMisc.readReprCode(entry, nSize, nReprCode, ret, 0);
          entryBlock.nDatumSpecBlockType = ret.nValue;
          break;
        case 3:
          LISMisc.readReprCode(entry, nSize, nReprCode, ret, 0);
          entryBlock.nDataFrameSize = ret.nValue;
          break;
        case 4:
          LISMisc.readReprCode(entry, nSize, nReprCode, ret, 0);
          entryBlock.nDirection = ret.nValue;
          break;
        case 5:
          LISMisc.readReprCode(entry, nSize, nReprCode, ret, 0);
          entryBlock.nOpticalDepthUnit = ret.nValue;
          break;
        case 6:
          LISMisc.readReprCode(entry, nSize, nReprCode, ret, 0);
          entryBlock.fDataRefPoint = ret.fValue;
          break;
        case 7:
          LISMisc.readReprCode(entry, nSize, nReprCode, ret, 0);
          entryBlock.strDataRefPointUnit = ret.strValue;
          break;
        case 8:
          LISMisc.readReprCode(entry, nSize, nReprCode, ret, 0);
          entryBlock.fFrameSpacing = ret.fValue;
          break;
        case 9:
          LISMisc.readReprCode(entry, nSize, nReprCode, ret, 0);
          entryBlock.strFrameSpacingUnit = ret.strValue;
          break;
        case 11:
          LISMisc.readReprCode(entry, nSize, nReprCode, ret, 0);
          entryBlock.nMaxFramesPerRecord = ret.nValue;
          break;
        case 12:
          LISMisc.readReprCode(entry, nSize, nReprCode, ret, 0);
          entryBlock.fAbsentValue = ret.fValue;
          break;
        case 13:
          LISMisc.readReprCode(entry, nSize, nReprCode, ret, 0);
          entryBlock.nDepthRecordingMode = ret.nValue;
          break;
        case 14:
          LISMisc.readReprCode(entry, nSize, nReprCode, ret, 0);
          entryBlock.strDepthUnit = ret.strValue;
          break;
        case 15:
          LISMisc.readReprCode(entry, nSize, nReprCode, ret, 0);
          entryBlock.nDepthRepr = ret.nValue;
          break;
        case 16:
          LISMisc.readReprCode(entry, nSize, nReprCode, ret, 0);
          entryBlock.nDatumSpecBlockSubType = ret.nValue;
          break;
      }
      nEntryBlockType = byteArr[nCurPos++];
      nSize = byteArr[nCurPos++];
      nReprCode = byteArr[nCurPos++];
      for (int i = 0; i < nSize; i++) entry[i] = byteArr[nCurPos++];
    }
    // Parse DatumSpecBlock
    // int idx = 0; // Không sử dụng
    int offset = 0;
    while (nTotalSize - nCurPos >= 40) {
      DatumSpecBlock datumSpecBlk = DatumSpecBlock();
      LISMisc.readReprCode(byteArr, 4, 65, ret, nCurPos);
      datumSpecBlk.strMnemonic = ret.strValue;
      nCurPos += 4;
      LISMisc.readReprCode(byteArr, 6, 65, ret, nCurPos);
      datumSpecBlk.strServiceID = ret.strValue;
      nCurPos += 6;
      LISMisc.readReprCode(byteArr, 8, 65, ret, nCurPos);
      datumSpecBlk.strServiceOrderNb = ret.strValue;
      nCurPos += 8;
      LISMisc.readReprCode(byteArr, 4, 65, ret, nCurPos);
      datumSpecBlk.strUnits = ret.strValue;
      nCurPos += 4;
      nCurPos += 4; // Skip API Codes
      LISMisc.readReprCode(byteArr, 2, 79, ret, nCurPos);
      datumSpecBlk.nFileNb = ret.nValue;
      nCurPos += 2;
      LISMisc.readReprCode(byteArr, 2, 79, ret, nCurPos);
      datumSpecBlk.nSize = ret.nValue;
      nCurPos += 2;
      nCurPos += 3; // Skip Process Level
      LISMisc.readReprCode(byteArr, 1, 66, ret, nCurPos);
      datumSpecBlk.nNbSamples = ret.nValue;
      nCurPos += 1;
      LISMisc.readReprCode(byteArr, 1, 66, ret, nCurPos);
      datumSpecBlk.nReprCode = ret.nValue;
      nCurPos += 1;
      nCurPos += 5; // Skip Process Indication
      datumSpecBlk.nDataItemNum =
          (datumSpecBlk.nSize ~/
              LISMisc.getReprCodeSize(datumSpecBlk.nReprCode)) ~/
          datumSpecBlk.nNbSamples;
      datumSpecBlk.nOffsetInBytes = offset;
      datumSpecBlk.bFlwChan = datumSpecBlk.nDataItemNum >= 101;
      chansArr.add(datumSpecBlk);
      offset += datumSpecBlk.nSize;
    }
  }

  double getStartDepth() {
    if (datasetArr.isNotEmpty) {
      return datasetArr.first.fDepth1;
    }
    return 0.0;
  }

  double getEndDepth([double? step]) {
    if (datasetArr.isNotEmpty) {
      return datasetArr.first.fDepth2;
    }
    return 0.0;
  }

  int getExtraBytesInLogRec(int nLRIdx) {
    int n = 6;
    n += (lrArr[nLRIdx].physicalRecordNum - 1) * 4;
    return n;
  }

  void releaseDATASETArr() async {
    for (var ds in datasetArr) {
      if (ds.hFile != null) {
        await ds.hFile!.close();
        ds.hFile = null;
      }
    }
    datasetArr.clear();
  }

  Future<void> createDATFiles() async {
    // TODO: Tạo file DAT từ datasetArr nếu cần
  }

  Future<int> readLogRecBytes(int nLRIdx) async {
    int nTotalSize = 0;
    int nCurrentSize = 0;
    nTotalSize = lrArr[nLRIdx].prArr[0].length - 6;
    bool bFileNumPresence = (lrArr[nLRIdx].prArr[0].attr1 & 0x4) > 0;
    bool bRecordNumPresence = (lrArr[nLRIdx].prArr[0].attr1 & 0x2) > 0;
    if (bFileNumPresence) nTotalSize -= 2;
    if (bRecordNumPresence) nTotalSize -= 2;
    for (int i = 1; i < lrArr[nLRIdx].physicalRecordNum; i++) {
      nTotalSize += lrArr[nLRIdx].prArr[i].length - 4;
      bFileNumPresence = (lrArr[nLRIdx].prArr[i].attr1 & 0x4) > 0;
      bRecordNumPresence = (lrArr[nLRIdx].prArr[i].attr1 & 0x2) > 0;
      if (bFileNumPresence) nTotalSize -= 2;
      if (bRecordNumPresence) nTotalSize -= 2;
    }
    // Đọc dữ liệu vào pBytesBuf
    pBytesBuf = Uint8List(nTotalSize);
    nCurrentSize = 0;
    await hFile!.setPosition(lrArr[nLRIdx].prArr[0].address + 6);
    var bytes0 = await hFile!.read(lrArr[nLRIdx].prArr[0].length - 6);
    pBytesBuf!.setRange(nCurrentSize, nCurrentSize + bytes0.length, bytes0);
    nCurrentSize += bytes0.length;
    bFileNumPresence = (lrArr[nLRIdx].prArr[0].attr1 & 0x4) > 0;
    bRecordNumPresence = (lrArr[nLRIdx].prArr[0].attr1 & 0x2) > 0;
    if (bFileNumPresence) nCurrentSize -= 2;
    if (bRecordNumPresence) nCurrentSize -= 2;
    for (int i = 1; i < lrArr[nLRIdx].physicalRecordNum; i++) {
      await hFile!.setPosition(lrArr[nLRIdx].prArr[i].address + 4);
      var bytesI = await hFile!.read(lrArr[nLRIdx].prArr[i].length - 4);
      pBytesBuf!.setRange(nCurrentSize, nCurrentSize + bytesI.length, bytesI);
      nCurrentSize += bytesI.length;
      bFileNumPresence = (lrArr[nLRIdx].prArr[i].attr1 & 0x4) > 0;
      bRecordNumPresence = (lrArr[nLRIdx].prArr[i].attr1 & 0x2) > 0;
      if (bFileNumPresence) nCurrentSize -= 2;
      if (bRecordNumPresence) nCurrentSize -= 2;
    }
    return nTotalSize;
  }

  void releaseChansArr() {
    for (var chan in chansArr) {
      chan.fData = null;
    }
    chansArr.clear();
  }

  Future<void> parse() async {
    var file = File(strFileName);
    hFile = await file.open();
    nFileSize = await file.length();
    lrArr.clear();
    int addr = 0;
    int maxIterations = 10000; // Safety limit
    int iteration = 0;
    while (addr + 16 < nFileSize && iteration < maxIterations) {
      await hFile!.setPosition(addr);
      var blankHeader = await hFile!.read(16);
      if (blankHeader.length < 16) break;
      // Parse blank record header
      // int prevAddr = // Không sử dụng
      blankHeader[0] +
          blankHeader[1] * 256 +
          blankHeader[2] * 65536 +
          blankHeader[3] * 16777216;
      // int curAddr = // Không sử dụng
      blankHeader[4] +
          blankHeader[5] * 256 +
          blankHeader[6] * 65536 +
          blankHeader[7] * 16777216;
      int nextAddr =
          blankHeader[8] +
          blankHeader[9] * 256 +
          blankHeader[10] * 65536 +
          blankHeader[11] * 16777216;
      int nextRecLen = blankHeader[13] + blankHeader[12] * 256;
      // int num = blankHeader[15]; // Không sử dụng
      // Đọc data record sau header
      int dataAddr = addr + 16;
      await hFile!.setPosition(dataAddr);
      var typeBytes = await hFile!.read(1);
      int nType = typeBytes.isNotEmpty ? typeBytes[0] : 0;
      // String name = LISMisc.findLogicalRecordTypeName(nType); // Không sử dụng
      LogicalRecord lr = LogicalRecord(
        length: nextRecLen - 4, // trừ 4 bytes header cuối
        address: dataAddr,
        type: nType,
        physicalRecordNum: 1,
        prArr: [],
      );
      lrArr.add(lr);
      nLogicalRecordNum++;
      // Di chuyển đến record tiếp theo
      addr = nextAddr;
      iteration++;
    }
    await hFile!.close();
  }

  Future<void> createLogicalFileArr() async {
    logicalFileArr.clear();
    int nLogRecNum = lrArr.length;
    int nCurLR = 0;
    while (nCurLR < nLogRecNum) {
      int nFirstIFLR1 = nCurLR;
      int nEndIFLR1 = nCurLR;
      // Tìm Logical File dựa trên các điều kiện (ví dụ: loại record)
      while (nEndIFLR1 + 1 < nLogRecNum && lrArr[nEndIFLR1 + 1].type != 128) {
        nEndIFLR1++;
      }
      LogicalFile lf = LogicalFile(
        nFirstIFLR1: nFirstIFLR1,
        nEndIFLR1: nEndIFLR1,
      );
      logicalFileArr.add(lf);
      nCurLR = nEndIFLR1 + 1;
    }
    nLogicalFileNum = logicalFileArr.length;
  }

  Future<void> createDataSet() async {
    datasetArr.clear();
    // Duyệt qua từng LogicalFile để tạo DataSet
    for (var lf in logicalFileArr) {
      // Ví dụ: lấy thông tin từ LogicalRecord đầu tiên của LogicalFile
      // var lr = lrArr[lf.nFirstIFLR1]; // Không sử dụng
      // Đọc dữ liệu frame spacing, depth, v.v. (giả lập, cần bổ sung logic thực tế)
      double fStep = 0.1;
      int nNbSamples = 1;
      int nTotalItemNum = 0;
      String strDATFileName = 'dataset_${lf.nFirstIFLR1}.dat';
      Dataset ds = Dataset()
        ..strDATFileName = strDATFileName
        ..nNbSamples = nNbSamples
        ..fStep = fStep
        ..nTotalItemNum = nTotalItemNum;
      datasetArr.add(ds);
    }
  }

  Future<void> readDataFromDataSet() async {
    // Đọc dữ liệu chi tiết từ từng DataSet
    for (var ds in datasetArr) {
      // Mở file DAT nếu cần
      // Đọc dữ liệu từ LogicalRecord/PhysicalRecord liên quan
      // Ví dụ: giả lập đọc dữ liệu depth và các giá trị mẫu
      ds.fDepth1 = 100.0; // Giá trị depth đầu
      ds.fDepth2 = 200.0; // Giá trị depth cuối
      ds.fData1 = [1.1, 2.2, 3.3]; // Dữ liệu mẫu đầu
      ds.fData2 = [4.4, 5.5, 6.6]; // Dữ liệu mẫu cuối
      int data1Len = ds.fData1 != null ? ds.fData1!.length : 0;
      int data2Len = ds.fData2 != null ? ds.fData2!.length : 0;
      ds.nTotalItemNum = data1Len + data2Len;
      // Có thể bổ sung logic giải mã dữ liệu thực tế từ file LIS bằng các hàm tiện ích
    }
  }

  // Trả về danh sách LisRecord cho UI
  List<LisRecord> get lisRecords {
    return lrArr
        .map(
          (lr) => LisRecord(
            type: lr.type,
            addr: lr.address,
            length: lr.length,
            name: LISMisc.findLogicalRecordTypeName(lr.type),
            blockNum: lr.physicalRecordNum,
            frameNum: 0,
            depth: -999.25,
          ),
        )
        .toList();
  }
}
