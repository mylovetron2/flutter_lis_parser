import 'dart:math';
import 'dart:typed_data';
import 'dart:io';
import 'lis_record.dart';

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
  File? hFile;
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
    // m,dm, cm, mm, in, ft
    // 1 in = 2.54 cm
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
      int prevAddr =
          blankHeader[0] +
          blankHeader[1] * 256 +
          blankHeader[2] * 65536 +
          blankHeader[3] * 16777216;
      int curAddr =
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
      int num = blankHeader[15];
      // Đọc data record sau header
      int dataAddr = addr + 16;
      await hFile!.setPosition(dataAddr);
      var typeBytes = await hFile!.read(1);
      int nType = typeBytes.isNotEmpty ? typeBytes[0] : 0;
      String name = LISMisc.findLogicalRecordTypeName(nType);
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
      var lr = lrArr[lf.nFirstIFLR1];
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
