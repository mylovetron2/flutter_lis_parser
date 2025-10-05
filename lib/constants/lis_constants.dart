// LIS Constants - converted from C++ defines

class LisConstants {
  // File Types
  static const int fileTypeLis = 0;
  static const int fileTypeNti = 1;

  // Direction
  static const int dirUp = 1;
  static const int dirDown = 255;
  static const int dirNeither = 0;

  // Optical Log Depth Scale Unit
  static const int oldsuFeet = 1;
  static const int oldsuMeters = 255;
  static const int oldsuTime = 0;

  // Depth Units
  static const int depthUnitFeet = 1;
  static const int depthUnitCm = 2;
  static const int depthUnitM = 3;
  static const int depthUnitMm = 4;
  static const int depthUnitHmm = 5;
  static const int depthUnitUnknown = 6;
  static const int depthUnitP1in = 7;

  // Data Types
  static const int typeChar = 1;
  static const int typeInt = 2;
  static const int typeFloat = 3;
  static const int typeUnknown = 4;

  // Null value
  static const double nullValue = -999.25;

  // Record Types
  static const int recordTypeData = 0;
  static const int recordTypeFileHeader = 128;
  static const int recordTypeFileTrailer = 129;
  static const int recordTypeTapeHeader = 130;
  static const int recordTypeTapeTrailer = 131;
  static const int recordTypeRealHeader = 132;
  static const int recordTypeRealTrailer = 133;
  static const int recordTypeWellInfo = 34;
  static const int recordTypeDataFormatSpec = 64;
  static const int recordTypeComment = 232;
}
