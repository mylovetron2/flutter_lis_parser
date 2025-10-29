class EntryBlock {
  int nDataRecordType = 0;
  int nDatumSpecBlockType = 0;
  int nDataFrameSize = 0;
  int nDirection = 0; // 1 UP   255 DOWN
  int nOpticalDepthUnit = 0; // 0 TIME 1 FEET 255 M
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
