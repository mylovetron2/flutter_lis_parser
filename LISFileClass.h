#pragma once

#define LRTYPE_NORMALDATA  0
#define LRTYPE_JOBID  32
#define LRTYPE_WELLSITEDATA  34
#define LRTYPE_TOOLSTRINGINFO  39
#define LRTYPE_TABLEDUMP  47
#define LRTYPE_DATAFORMATSPEC  64
#define LRTYPE_FILEHEADER  128
#define LRTYPE_FILETRAILER  129
#define LRTYPE_TAPEHEADER  130
#define LRTYPE_TAPETRAILER  131
#define LRTYPE_REELHEADER  132
#define LRTYPE_REELTRAILER  133
#define LRTYPE_COMMENT  232

#define REPRCODE_49  49//16 bit floating Point (size = 2);
#define REPRCODE_50  50//32 bit low resolution floating Point (size =4);
#define REPRCODE_56  56//8 bit 2's complement integer (size = 1);
#define REPRCODE_65  65//
#define REPRCODE_66  66//byte format (size = 1);
#define REPRCODE_68  68//32 bit floating Point (size = 4);
#define REPRCODE_70  70//32 bit Fix Point (size = 4);
#define REPRCODE_73  73//32 bit 2's complement integer (size = 4);
#define REPRCODE_79  79//16 bit 2's complement integer (size = 2;

#define MAX_LOGICALFILENUM	10

#define	FILE_TYPE_LIS		1
#define	FILE_TYPE_NTI		2


class PhysicalRecord
{
public: 
	long lLen;
    long lAddress;

    BYTE attr1;
    BYTE attr2;
};

class LogicalRecord
{
public:
	long lLen;
    long lAddress;

    int nType;

    int nPhysicalRecordNum;
    PhysicalRecord* prArr;
};

class ReprCodeReturn
{
public:
	int nType;//1=Integer; 2=double; 3=string

    double fValue;
    CString strValue;
    int nValue;
public:
	ReprCodeReturn()
	{
		Init();
	}
    void Init()
    {
        nType = 1;
        fValue = 0;
        nValue = 0;
        strValue = "";
    }
    void Copy(ReprCodeReturn temp)
    {
        this->nType = temp.nType;
        this->fValue = temp.fValue;
        this->nValue = temp.nValue;
        this->strValue = temp.strValue;
    }
    CString ToString()
    {
        CString str = "";

        if (nType == 1)//Integer
			str.Format("%d", nValue);
        else if (nType == 2)//Double
			str.Format("%f", fValue);
        else if (nType == 3)//string
			str = strValue;
            

        return str;
    }
};


class LogicalFile
{
public:
	//int nStartIdx1;
    //int nStartIdx2;
    //int nEndIdx1;
    //int nEndIdx2;

    int nFirstIFLR1;
    //int nFirstIFLR2;
    int nEndIFLR1;
    //int nEndIFLR2;

    CArray<CPoint> JobIDPos;
    CArray<CPoint> WellsiteDataPos ;
    CArray<CPoint> ToolStringInfoPos ;
    CArray<CPoint> TableDumpPos;
    CArray<CPoint> DataFormatSpecPos ;
    CArray<CPoint> FileHeaderPos;
    CArray<CPoint> FileTrailerPos ;
    CArray<CPoint> TapeHeaderPos ;
    CArray<CPoint> TapeTrailerPos ;
    CArray<CPoint> ReelHeaderPos ;
    CArray<CPoint> ReelTrailerPos ;
    CArray<CPoint> CommentPos ;
    
public:
    void Init()
    {
        //nStartIdx1 = 0;
        //nStartIdx2 = 0;
        //nEndIdx1 = 0;
        //nEndIdx2 = 0;

        nFirstIFLR1 = -1;
        //nFirstIFLR2 = -1;
        nEndIFLR1 = -1;
        //nEndIFLR2 = -1;
    }
    LogicalFile()
    {
        Init();
    }
    void ReleaseResources()
    {
        JobIDPos.RemoveAll();
        WellsiteDataPos.RemoveAll();
        ToolStringInfoPos.RemoveAll();
        TableDumpPos.RemoveAll();
        DataFormatSpecPos.RemoveAll();
        FileHeaderPos.RemoveAll();
        FileTrailerPos.RemoveAll();
        TapeHeaderPos.RemoveAll();
        TapeTrailerPos.RemoveAll();
        ReelHeaderPos.RemoveAll();
        ReelTrailerPos.RemoveAll();
        CommentPos.RemoveAll(); 
    }
};


class EntryBlock_t
{
public:
    int nDataRecordType; //(1)
    int nDatumSpecBlockType; //(2)
    int nDataFrameSize; //(3)
    int nDirection;// (4)       1=up;255=down;0=neither
    int nOpticalDepthUnit;//(5) 1=feet; 255 meter; 0 = time

    double fDataRefPoint;// (6)
    CString strDataRefPointUnit;//(7)

    double fFrameSpacing; //(8)
    CString strFrameSpacingUnit;//(9)

    int nMaxFramesPerRecord;// (11) moi frame chua bao nhieu record

    double fAbsentValue; //(12)

	int nDepthRecordingMode;//(13) 1-Depth occurs only once per data record preceding the first frame
    CString strDepthUnit;//(14)
    int nDepthRepr;//(15)

    int nDatumSpecBlockSubType;//(16)
public:
    void Init()
    {
        nDataRecordType = 0; 
        nDatumSpecBlockType = 0;
        nDataFrameSize = 0; 
        nDirection = 0;    
        nOpticalDepthUnit = 0;

        fDataRefPoint = 0;// (6)
        strDataRefPointUnit = "";//(7)

        fFrameSpacing = 0; //(8)
        strFrameSpacingUnit = "";//(9)

        nMaxFramesPerRecord = 0;

        fAbsentValue = -999.255f;

        nDepthRecordingMode = 0;
        strDepthUnit = "";
        nDepthRepr = 68;
        nDatumSpecBlockSubType = 0;
    }
    EntryBlock_t()
    {
        Init();
    }
};
class DatumSpecBlock_t
{
public:
	CString strMnemonic;
    CString strServiceID;
    CString strServiceOrderNb;
    CString strUnits;

    int nFileNb;//Don't use
    int nSize;//int bytes 

    int nNbSamples;//For fast Channel: nNbSamples > 1
    int nReprCode;

	//Doi voi kenh fast channel, du lieu duoc luu lien tuc gan nhau
	///////////////////////////////////////
	int nDatasetIdx;//duong cong nay thuoc Dataset nao
	int nIndexInDataset;
	int nPosInDataset;

	float*	fData;
	int nDataItemNum;//So luong du lieu o 1 do sau

    int nOffsetInBytes;//Vi tri cua du lieu dau tien (tinh theo byte)-dung de ghi file DAT
	//////////////////////////////////////////////////////////
	// Cac bien du lieu dung cho viec load DAT file --> Database
	bool	bLoad;
	CString	strMnemonicLoad;
	CString	strUnitsLoad;
	int		nIdxInDatabase;// Index in Loginter database
	bool	bFlwChan;

	bool	bLoadNew; // Use for overwrite curve
	
public:
    void Init()
    {
        strMnemonic = "";
        strServiceID = "";
        strServiceOrderNb = "";
        strUnits = "";

        nFileNb = 0;
        nSize = 0;//int bytes

        nNbSamples = 0;
        nReprCode = 0;
		//////////////////////////////////////
		nDatasetIdx = 0;
		nIndexInDataset = 0;
		nPosInDataset = 0;
		
		fData = NULL; 
		nDataItemNum = 0;

        nOffsetInBytes = 0;
		///////////////////////////////////////
        this->bLoad = 0;
		this->strMnemonicLoad = "";
		this->strUnitsLoad = "";
		this->nIdxInDatabase = 0;
		this->bFlwChan = false;
    }
    DatumSpecBlock_t()
    {
        this->Init();
    }
};


class Dataset_t
{
public:
	CString strDATFileName; //Ten day du cua file DAT (dung de ghi file DAT)

	int		nNbSamples;
	float	fStep;//in meters
	int		nTotalItemNum;

	FILE*	hFile;
	////////////////////////////////////////////////
	// Use for load DAT to Database
	bool	bLoad; //bLoad=true neu co it nhat 1 duong cong duoc load (co the la d/c binh thuong
					// hoac duong cong vector (fullwave)
	float	fDepth1;
	float*	fData1;
	float	fDepth2;
	float*	fData2;
	
	float	fFactor;//Use for interpolate data;

	int		nTimeCount;//Duoc su dung khi load file LIS.
public:
	void Init()
	{
		strDATFileName = "";
		nNbSamples = 1;

		fStep = 0.1;
		nTotalItemNum = 0;

		hFile = NULL;
		////////////////////////////////////////////////
		bLoad = false;
	}
	DataSet_t()
    {
        Init();
    }
};


class LISMisc
{
public:
	static int GetReprCodeSize(int nReprCode);
	static CString FindLogicalRecordTypeName(int nType);
	static double ConvertDepthValue(double fDepth, CString strOldDU, CString strNewDU);
	static int ReadReprCode(BYTE byteArr[], int nCount, int nReprCode,
                 ReprCodeReturn& ret, int& nRealSize, int nCurPos = 0);
    static long Convert4Bytes2Long(BYTE group[]);  
};

class LISFileClass
{
public:
	CString						strFileName;
	CString						strDirName;
    FILE*						hFile;
    long						nFileSize;
	int							nFileType;//Russian or Halliburton
    CProgressCtrl				*progressBar;

	LogicalRecord*				lrArr;
	int							nLogicalRecordNum;

	LogicalFile					logicalFileArr[MAX_LOGICALFILENUM];
    int							nCurLogicalFile;
	int							nLogicalFileNum;

	CArray<Dataset_t>			DATASETArr;
	EntryBlock_t				entryBlock;
	CArray<DatumSpecBlock_t>	chansArr;

    int							nFirstIFLR1;
    int							nEndIFLR1;

	//////////////////////////////////////////////
	// Moi Logical Rec co the chua tu 1 den nhieu Physical Rec
	// Moi Logical Rec co the chua tu 1 den nhieu Frame du lieu
	// Physical Rec KHAC Frame du lieu
	int				nLogRecMaxSize; // Chieu dai cua Logical Rec lon nhat
	int				nDepthCurveIdx;
	int				nFrameSizeInBytes; // Kich thuoc tinh bang byte cua mot Frame du lieu
	BYTE*			pBytesBuf;

	double			fStep;//in meter
    double			fStartDepth;//in meter
    double			fEndDepth;//in meter

	int				nMaxNbSamples;

	////////////////////////////////////////////////////
	CArray<CPoint>	JobIDPos;
    CArray<CPoint>	WellsiteDataPos;
    CArray<CPoint>	ToolStringInfoPos;
    CArray<CPoint>	TableDumpPos;
    CArray<CPoint>	DataFormatSpecPos;
    CArray<CPoint>	FileHeaderPos;
    CArray<CPoint>	FileTrailerPos;
    CArray<CPoint>	TapeHeaderPos;
    CArray<CPoint>	TapeTrailerPos;
    CArray<CPoint>	ReelHeaderPos;
    CArray<CPoint>	ReelTrailerPos ;
    CArray<CPoint>	CommentPos;

public:
	LISFileClass(void);
	~LISFileClass(void);
	void ParseBlankRecord(BYTE group2[], BYTE group3[], BYTE group4[], long &lPrevAddr, long &lNextAddr, long &lRecLen);
	void Parse(void);
	void ReleaseResources(void);
	//CString FindLogicalRecordTypeName(int nType);
	void ReleaseEFLRArr(bool bAll=true);
	int GetNextPR(int nLRNum, int nCurIdx1, int nCurIdx2, int& nNextIdx1, int& nNextIdx2);
	int GetPrevPR(int nCurIdx1, int nCurIdx2, int& nPrevIdx1, int& nPrevIdx2);
	void CreateLogicalFileArr(void);
	void ParseLogicalFile(int nCurLF);
	void ParseDataFormatSpecRecord(void);
	void CreateDataSet(void);
	double GetStartDepth(void);
	double GetEndDepth(double fStep);
	int GetExtraBytesInLogRec(int nLRIdx);
	void ReleaseDATASETArr(void);
	void CreateDATFiles(void);
	int ReadLogRecBytes(int nLRIdx);
	void ReleaseChansArr(void);
};
