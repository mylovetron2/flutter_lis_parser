import 'dart:io';

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
