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
