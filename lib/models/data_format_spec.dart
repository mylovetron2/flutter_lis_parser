// DataFormatSpec model - converted from DataFormatSpec_t C++ struct

class DataFormatSpec {
  int dataRecordType;
  int datumSpecBlockType;
  int dataFrameSize;
  int direction; // 1=up; 255=down; 0=neither
  int opticalDepthUnit;
  double dataRefPoint;
  int dataRefPointUnit;
  double frameSpacing;
  int frameSpacingUnit;
  int maxFramesPerRecord;
  double absentValue;
  int depthRecordingMode;
  int depthUnit;
  int depthRepr;
  int datumSpecBlockSubType;

  DataFormatSpec({
    this.dataRecordType = -1,
    this.datumSpecBlockType = -1,
    this.dataFrameSize = -1,
    this.direction = -1,
    this.opticalDepthUnit = -1,
    this.dataRefPoint = -1,
    this.dataRefPointUnit = -1,
    this.frameSpacing = -1,
    this.frameSpacingUnit = -1,
    this.maxFramesPerRecord = -1,
    this.absentValue = -1,
    this.depthRecordingMode = -1,
    this.depthUnit = -1,
    this.depthRepr = -1,
    this.datumSpecBlockSubType = -1,
  });

  void init() {
    dataRecordType = -1;
    datumSpecBlockType = -1;
    dataFrameSize = -1;
    direction = -1;
    opticalDepthUnit = -1;
    dataRefPoint = -1;
    dataRefPointUnit = -1;
    frameSpacing = -1;
    frameSpacingUnit = -1;
    maxFramesPerRecord = -1;
    absentValue = -1;
    depthRecordingMode = -1;
    depthUnit = -1;
    depthRepr = -1;
    datumSpecBlockSubType = -1;
  }

  String get directionName {
    switch (direction) {
      case 1:
        return 'Up';
      case 255:
        return 'Down';
      case 0:
        return 'Neither';
      default:
        return 'Unknown';
    }
  }

  String get depthUnitName {
    switch (depthUnit) {
      case 1:
        return 'Feet';
      case 2:
        return 'CM';
      case 3:
        return 'M';
      case 4:
        return 'MM';
      case 5:
        return 'HMM';
      case 6:
        //return 'Unknown';
        return 'MS';
      case 7:
        return '0.1 IN';
      default:
        return 'Unknown';
    }
  }

  @override
  String toString() {
    return 'DataFormatSpec(direction: $directionName, frameSpacing: $frameSpacing, depthUnit: $depthUnitName)';
  }
}
