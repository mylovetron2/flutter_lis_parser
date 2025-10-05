// LisFile.h: interface for the CLisFile class.
//
//////////////////////////////////////////////////////////////////////

#if !defined(AFX_LISFILE_H__B3E88A1C_2180_4098_891D_383BEF839002__INCLUDED_)
#define AFX_LISFILE_H__B3E88A1C_2180_4098_891D_383BEF839002__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

#include "DatumSpecBlk.h"

#define		FLWHEADER	2048

#define		DIR_UP		1
#define		DIR_DOWN	255
#define		DIR_NEITHER	0

#define		OLDSU_FEET		1	//Optical Log Depth Scale Unit
#define		OLDSU_METERS	255
#define		OLDSU_TIME		0

#define		DEPTH_UNIT_FEET	1
#define		DEPTH_UNIT_CM	2
#define		DEPTH_UNIT_M	3
#define		DEPTH_UNIT_MM	4
#define		DEPTH_UNIT_HMM	5
#define		DEPTH_UNIT_UNKNOWN	6
#define		DEPTH_UNIT_P1IN	7

#define		TYPE_CHAR		1
#define		TYPE_INT		2
#define		TYPE_FLOAT		3
#define		TYPE_UNKNOWN	4


class CBlankRecord:public CObject
{
public:
	long	lPrevAddr;
	long	lAddr;
	long	lNextAddr;
	long	lNextRecLen;
	int		nNum;
public:
	CBlankRecord();
	virtual ~CBlankRecord();
	CBlankRecord(long PrevAddr,long Addr,long NextAddr,long NextRecLen,int Num=0)
	{
		lPrevAddr=PrevAddr;
		lNextAddr=NextAddr;
		lAddr=Addr;
		lNextRecLen=NextRecLen;
		nNum=Num;
	}
};


class CLisRecord:public CObject  
{
public:
	int			nType;
	long		lAddr;
	long		lLen;
	CString		strName;

	//BOOL		bMultiBlock;
	int			nBlockNum;
	//int			nBlockSize;

	int			nFrameNum;
	//int			nStartFrame;
	//int			nEndFrame;
	float		fDepth;
public:
	CLisRecord();
	virtual ~CLisRecord();
	CLisRecord(int nType,long lAddr,long lLen,CString strName)
	{
		this->nType=nType;
		this->lAddr=lAddr;
		this->lLen=lLen;
		this->strName=strName;
		this->nFrameNum=0;
		this->nBlockNum=0;
		this->fDepth = -999.25;
	}
};

typedef CTypedPtrArray<CObArray,CLisRecord*> CLisRecordArray;
typedef CTypedPtrArray<CObArray,CBlankRecord*> CBlankRecordArray;
typedef CTypedPtrArray<CObArray,CDatumSpecBlk*> CDatumSpecBlkArray;
typedef CTypedPtrArray<CObArray,CComponentBlk*> CComponentBlkArray;
typedef CTypedPtrArray<CObArray,CCB3Blk*> CCB3BlkArray;
typedef CTypedPtrArray<CObArray,CWellInfoBlk*> CWellInfoArray;


#define		FILE_TYPE_LIS		0
#define		FILE_TYPE_NTI		1

struct	DataFormatSpec_t
{
	int					nDataRecordType;
	int					nDatumSpecBlockType;
	int					nDataFrameSize;
	int					nDirection;//1=up;255=down;0=neither
	int					nOpticalDepthUnit;

	float				fDataRefPoint;
	int					nDataRefPointUnit;

	float				fFrameSpacing;
	int					nFrameSpacingUnit;

	int					nMaxFramesPerRecord;//moi frame chua bao nhieu record

	float				fAbsentValue;

	int					nDepthRecordingMode;
	int					nDepthUnit;
	int					nDepthRepr;

	int					nDatumSpecBlockSubType;

	void		init()
	{
		//Data Format Specification Record
		nDataRecordType=-1;
		nDatumSpecBlockType=-1;
		nDataFrameSize=-1;
		nDirection=-1;
		nOpticalDepthUnit=-1;
		fDataRefPoint=-1;
		nDataRefPointUnit=-1;
		fFrameSpacing=-1;
		nFrameSpacingUnit=-1;
		nMaxFramesPerRecord=-1;
		fAbsentValue=-1;
		nDepthRecordingMode=-1;	
		nDepthUnit=-1;
		nDepthRepr=-1;
		nDatumSpecBlockSubType=-1;
	}
};

class CLisFile  
{
public:
	int					nFileType;

	CString				m_strFileName;
	CString				m_strDatFileName;

	CBlankRecordArray	blankArr;
	CLisRecordArray		lisRecordArr;
	CDatumSpecBlkArray	datumArr;
	CWellInfoArray		CONSArr;
	CWellInfoArray		OUTPArr;
	CWellInfoArray		AK73Arr;
	CWellInfoArray		CB3Arr;
	CWellInfoArray		ToolArr;
	CWellInfoArray		ChanArr;

	DataFormatSpec_t	dataFormatSpec;

	CFile				hFile;
	bool				bIsFileOpen;
	int					nDataFSRIdx;//Data Format Specification Record Index;
	int					nAK73Idx;
	int					nCB3Idx;
	int					nCONSIdx;
	int					nOUTPIdx;
	int					nToolIdx;
	int					nChanIdx;

	/////////////////////////////////////////////
	long				lStep;
	float				fStartDepth;
	float				fEndDepth;

	int					nStartDataRec;
	int					nEndDataRec;

	int					nDepthCurveIdx;//in case depth in each frame

	float				fCurDepth;
	int					nCurDataRec;





	int					nRecNum;

	int					nFrameNum;
	int					nCurFrame;
	
	
	///////////////////////////////////////////////
	BYTE				*pByteData;
	float				*fFileData;
	
public:
	void GetAllData(int nCurDataRec);
	void OpenLIS(CProgressCtrl& progress);
	void OpenNTI(CProgressCtrl& progress);

	
	
	int GetCodeType(BYTE nCode);
	
	int GetCodeSize(BYTE nCode);
	
	float ReadCode(BYTE Entry[],BYTE nReprCode,BYTE nSize);
	
	void ParseBlankRecord(BYTE group2[],BYTE group3[],BYTE group4[],long &lPrevAddr,long &lNextAddr, long &lNextRecLen);
	int OpenLisFile(CString strFN, CProgressCtrl& progress);
	void CloseLisFile();
	CLisFile();
	virtual ~CLisFile();



	int GetLisRecordNum(void);
	
	int	GetStartDataRecordIdx();
	int	GetEndDataRecordIdx();

	float GetStartDepth();//in meter
	float GetEndDepth();//in meter

	
	//void	WriteToDatFile(float fTop, float fBottom, CProgressCtrl* m_Process, float	fStep, int nStepFactor);
	void	WriteToDatFile(float fTop, float fBottom, CProgressCtrl* m_Process);
	float	GetStep();
	int		GetFrameNum(int nCurDataRec);
	float	ConvertToMeter(float fDepth, int nMode);

	void	ReadDataFormatSpecificationRecord();
	void	ReadWellInfo(int idxTab, CWellInfoArray& arr);
	void	ReadDepth();

	void	GetStepList(float step[], int factor[], int&	nStepCount);
};

#endif // !defined(AFX_LISFILE_H__B3E88A1C_2180_4098_891D_383BEF839002__INCLUDED_)
