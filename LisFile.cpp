// LisFile.cpp: implementation of the CLisFile class.
//
//////////////////////////////////////////////////////////////////////

#include "stdafx.h"

#include "LisFile.h"
#include <math.h>

#ifdef _DEBUG
#undef THIS_FILE
static char THIS_FILE[]=__FILE__;
#define new DEBUG_NEW
#endif

//////////////////////////////////////////////////////////////////////
// CLisRecord Class
//////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////
// Construction/Destruction
//////////////////////////////////////////////////////////////////////

CLisRecord::CLisRecord()
{

}

CLisRecord::~CLisRecord()
{

}


//////////////////////////////////////////////////////////////////////
// CBlankRecord Class
//////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////
// Construction/Destruction
//////////////////////////////////////////////////////////////////////

CBlankRecord::CBlankRecord()
{
	
}

CBlankRecord::~CBlankRecord()
{

}


//////////////////////////////////////////////////////////////////////
// Construction/Destruction
//////////////////////////////////////////////////////////////////////

CLisFile::CLisFile()
{
	bIsFileOpen=false;
	
	this->dataFormatSpec.init();

	pByteData=new BYTE[150000];
	fFileData=new float[60000];
}

CLisFile::~CLisFile()
{
	CloseLisFile();
	delete[] pByteData;
	delete[] fFileData;
}
void CLisFile::CloseLisFile()
{
	if(bIsFileOpen)
	{
		hFile.Close();
		for(int i=blankArr.GetSize()-1;i>=0;i--)
		{
			delete blankArr[i];
			blankArr.RemoveAt(i);
		}
		for(i=lisRecordArr.GetSize()-1;i>=0;i--)
		{
			delete lisRecordArr[i];
			lisRecordArr.RemoveAt(i);
		}
		for(i=datumArr.GetSize()-1;i>=0;i--)
		{
			delete datumArr[i];
			datumArr.RemoveAt(i);
		}
		for(i=CB3Arr.GetSize()-1;i>=0;i--)
		{
			delete CB3Arr[i];
			CB3Arr.RemoveAt(i);
		}
		for(i=AK73Arr.GetSize()-1;i>=0;i--)
		{
			delete AK73Arr[i];
			AK73Arr.RemoveAt(i);
		}
		/*for(i=CONSArr.GetSize()-1;i>=0;i--)
		{
			delete CONSArr[i];
			CONSArr.RemoveAt(i);
		}*/
		/*for(i=OUTPArr.GetSize()-1;i>=0;i--)
		{
			delete OUTPArr[i];
			OUTPArr.RemoveAt(i);
		}*/
		for(i=ToolArr.GetSize()-1;i>=0;i--)
		{
			delete ToolArr[i];
			ToolArr.RemoveAt(i);
		}
		for(i=ChanArr.GetSize()-1;i>=0;i--)
		{
			delete ChanArr[i];
			ChanArr.RemoveAt(i);
		}
	}
}
////////////////////////////////////////////////

void CLisFile::ParseBlankRecord(BYTE group2[], BYTE group3[], BYTE group4[], long &lPrevAddr, long &lNextAddr, long &lNextRecLen)
{
	long	l16x2=256;
	long	l16x4=65536;
	long	l16x6=16777216;

	lPrevAddr=long(group2[0])+long(group2[1])*l16x2+
				long(group2[2])*l16x4+long(group2[3])*l16x6;
	lNextAddr=long(group3[0])+long(group3[1])*l16x2+
				long(group3[2])*l16x4+long(group3[3])*l16x6;
	lNextRecLen=long(group4[1])+long(group4[0])*l16x2;
}

void CLisFile::OpenNTI(CProgressCtrl& progress)//Halliburton
{
	CLisRecord*		pRec;
	CBlankRecord*	pBlankRec;
	
	BYTE			str[1000];
	BYTE			Entry[1000];

	//Read Record Table Content;
	BYTE		nType;
	CLisRecord*	lisRec;
	CString		strName="";
	int			idx=0;

	BYTE		nSubType;
	BYTE		nRepCode;
	BYTE		nSize;
	BYTE		nCategory;
	char		szMnemonic[5];
	char		szUnit[5];
	char		szValue[100];

	nDataFSRIdx=-1;
	nChanIdx=-1;
	nStartDataRec=-1;
	nEndDataRec=-1;
	nCurDataRec=-1;
	nAK73Idx=-1;
	nToolIdx=-1;
	nCB3Idx=-1;
	nCONSIdx=-1;
	nOUTPIdx = -1;

	long		lCurAddr=0;
	long		lLen;
	long		l16x2=256;
	long		l16x4=65536;
	long		l16x6=16777216;

	int			nContinue;
	long		lWellInfoPos;

	long	lCurPos = hFile.GetPosition();
	long	lPrevPos = hFile.GetPosition();
	
	progress.SetRange32(0, (hFile.GetLength()- lCurPos)/100.0);
	progress.SetStep(1);
	progress.SetPos(0);

	hFile.Seek(lCurPos, CFile::begin);
	while(1)
	{
		hFile.Seek(lCurAddr,SEEK_SET);	

		if(hFile.GetPosition()>=hFile.GetLength()-1)	break;

		//Read Size;
		hFile.Read(str,4);
		lLen=str[1]+str[0]*l16x2;

		nContinue=str[3];

		//int	nTrailer = str[2];

		//if(nTrailer != 0)
		//	AfxMessageBox("Has trailer");

		//Read Type;
		hFile.Read(str,2);
		nType=str[0];

		if(nType==64)
			nDataFSRIdx=idx;

		if(nType==0 && nStartDataRec<0)
			nStartDataRec=idx;
		if(nType==0)
			nEndDataRec=idx;

		if(nType==64)
			strName="Data Format Specification";
		else if(nType==0)
			strName="Data";
		else if(nType==232)
			strName="Comment";
		else if(nType==129)
			strName="File Trailer Record";
		else if(nType==130)
			strName="Tape Header Record";
		else if(nType==131)
			strName="Tape Trailer Record";
		else if(nType==132)
			strName="Real Header Record";
		else if(nType==133)
			strName="Real Trailer Record";
		else if(nType==128)
			strName="File Header Logical Record";
		else if(nType==34)
		{
			strName="Well info";
			lWellInfoPos = hFile.GetPosition();
		}
		else 
			strName="Unknown";

		int		nBlockNum=1;

	 	if(nContinue==1 && 
			(nType == 34 || nType == 232 || nType == 0 || nType == 64 ))//Well Info
		{
			long	lLen1=lLen;
			long	offset=-6;
			nBlockNum=1;
			while(nContinue!=2)
			{
				hFile.Seek(offset,SEEK_CUR);
				hFile.Seek(lLen1,SEEK_CUR);

				hFile.Read(str,4);
				lLen1=str[1]+str[0]*l16x2;

				lLen=lLen+lLen1;

				nContinue=str[3];
				offset=-4;
				nBlockNum++;
			}
		}

		if(nType == 34)
		{
			long	lOldPos = hFile.GetPosition();

			hFile.Seek(lWellInfoPos, SEEK_SET);
			hFile.Read(&nSubType,1);
			if(nSubType==73)
			{
				hFile.Read(&nRepCode,1);
				hFile.Read(&nSize,1);
				hFile.Read(&nCategory,1);
				hFile.Read(szMnemonic,4);
				hFile.Read(szUnit,4);
				hFile.Read(szValue,nSize);
				szValue[nSize]=0;
				for(int j=nSize-1;j>=0;j--)
					if(szValue[j]==' ')
						szValue[j]=0;
					else
						break;
				strName.Format("%s",szValue);
			}
			hFile.Seek(lOldPos, SEEK_SET);
		}
		
		if(strName=="CHAN")
			nChanIdx=idx;

		if(strName=="AK73")
			nAK73Idx=idx;

		if(strName=="TOOL")
			nToolIdx=idx;

		if(strName=="CB3")
			nCB3Idx=idx;

		if(strName=="CONS")
			nCONSIdx=idx;

		if(strName=="OUTP")
			nOUTPIdx=idx;

		//AfxMessageBox(strName);

		lisRec=new CLisRecord(nType,lCurAddr,lLen,strName);
		lisRec->nBlockNum=nBlockNum;
		
		lisRecordArr.Add(lisRec);	

		lCurAddr+=lLen;
		idx++;

		lCurPos = hFile.GetPosition();
		for(int k = 0; k<(lCurPos-lPrevPos)/100.0; k++)
			progress.StepIt();
		lPrevPos = lCurPos;
	}

	progress.SetPos(0);

	ReadDataFormatSpecificationRecord();
		
	this->ReadWellInfo(nCONSIdx, this->CONSArr);

	this->ReadWellInfo(nOUTPIdx, this->OUTPArr);

	//Calculate lStep
	lStep = long(this->dataFormatSpec.fFrameSpacing);
	if(dataFormatSpec.nFrameSpacingUnit==DEPTH_UNIT_FEET)
		;
	else if(dataFormatSpec.nFrameSpacingUnit==DEPTH_UNIT_CM)
		lStep = lStep*10;
	else if(dataFormatSpec.nFrameSpacingUnit==DEPTH_UNIT_M)
		lStep =long( this->dataFormatSpec.fFrameSpacing*1000);
	else if(dataFormatSpec.nFrameSpacingUnit==DEPTH_UNIT_MM)
		;
	else if(dataFormatSpec.nFrameSpacingUnit==DEPTH_UNIT_HMM)
		lStep = lStep/2;
	else if(dataFormatSpec.nFrameSpacingUnit==DEPTH_UNIT_P1IN)
		lStep = long(this->dataFormatSpec.fFrameSpacing*2.54*0.1*0.01*1000);

	//////////////////////////////////////////////////////
	this->nStartDataRec = this->GetStartDataRecordIdx();
	this->nEndDataRec = this->GetEndDataRecordIdx();

	//////////////////////////////////////////////////////
	this->nDepthCurveIdx = -1;
	if(this->dataFormatSpec.nDepthRecordingMode == 0)//Depth in each frame
	{
		for(int i = 0; i<this->datumArr.GetSize();i++)
		{
			if(!strcmp(datumArr[i]->szMnemonic, "DEPT"))
			{
				nDepthCurveIdx = i;
				break;
			}
		}
	}
	////////////////////////////////////////////
	CLisRecord*		lisRecord;
	int				nCount = 0;
	int				nLen;
	int				nBlockNum;

	//////////////////////////////////////////////////////
	this->nFrameNum = nCount;
	this->nCurFrame = 0;
	///////////////////////////////////////////////////////
	this->ReadDepth();


	this->fStartDepth = this->GetStartDepth();
	this->fEndDepth = this->GetEndDepth();

	nRecNum=nEndDataRec-nStartDataRec+1;
	bIsFileOpen=true;
}

void CLisFile::OpenLIS(CProgressCtrl& progress)//Russia
{
	CLisRecord*		pRec;
	CBlankRecord*	pBlankRec;
	long			lAddr=0;
	long			lPrevAddr;
	long			lNextAddr;
	long			lNextRecLen;
	int				nNum;

	BYTE			group2[4];
	BYTE			group3[4];
	BYTE			group4[4];

	hFile.Seek(0,SEEK_SET);

	//Read Blank Table Content;
	while(1)
	{
		hFile.Seek(4,SEEK_CUR);			
		hFile.Read(group2,4);
		hFile.Read(group3,4);
		hFile.Read(group4,4);

		ParseBlankRecord(group2,group3,group4,lPrevAddr,lNextAddr,lNextRecLen);
		nNum=int(group4[3]);

		pBlankRec=new CBlankRecord(lPrevAddr,lAddr,lNextAddr,lNextRecLen,nNum);
		blankArr.Add(pBlankRec);

		lAddr=lNextAddr;
		hFile.Seek(lNextRecLen-4,SEEK_CUR);

		if(hFile.GetPosition()>=hFile.GetLength()-16)
			break;
	} 
	
	//Read Record Table Content;
	BYTE		nType;
	CLisRecord*	lisRec;
	CString		strName="";
	int			idx=0;

	BYTE		nSubType;
	BYTE		nRepCode;
	BYTE		nSize;
	BYTE		nCategory;
	char		szMnemonic[5];
	char		szUnit[5];
	char		szValue[100];

	nDataFSRIdx=-1;
	nChanIdx=-1;
	nStartDataRec=-1;
	nEndDataRec=-1;
	nCurDataRec=-1;
	nAK73Idx=-1;
	nToolIdx=-1;
	nCB3Idx=-1;
	nCONSIdx=-1;

	progress.SetRange32(0, blankArr.GetSize());
	progress.SetStep(1);
	progress.SetPos(0);

	for(int i=0;i<blankArr.GetSize();i++)
	{
		pBlankRec=blankArr[i];

		if(pBlankRec->nNum>=1)
		{
			lisRec=lisRecordArr[idx-1];
			lisRec->lLen+=pBlankRec->lNextRecLen-4;
			continue;
		}

		lAddr=pBlankRec->lAddr+16;
		hFile.Seek(lAddr,SEEK_SET);
		
		hFile.Read(&nType,1);
		hFile.Seek(1,SEEK_CUR);

		if(nType==64)
			nDataFSRIdx=idx;
		if(nType==0 && nStartDataRec<0)
			nStartDataRec=idx;
		if(nType==0)
			nEndDataRec=idx;

		if(nType==64)
			strName="Data Format Specification";
		else if(nType==0)
			strName="Data";
		else if(nType==128)
			strName="File Header Logical Record";
		else if(nType==34)
		{
			strName="";
			hFile.Read(&nSubType,1);
			if(nSubType==73)
			{
				hFile.Read(&nRepCode,1);
				hFile.Read(&nSize,1);
				hFile.Read(&nCategory,1);
				hFile.Read(szMnemonic,4);
				hFile.Read(szUnit,4);
				hFile.Read(szValue,nSize);
				szValue[nSize]=0;
				for(int j=nSize-1;j>=0;j--)
					if(szValue[j]==' ')
						szValue[j]=0;
					else
						break;
				strName.Format("%s",szValue);
			}		
		}
		else 
			strName="Unknown";

		if(strName=="CHAN")
			nChanIdx=idx;

		if(strName=="AK73")
			nAK73Idx=idx;

		if(strName=="TOOL")
			nToolIdx=idx;

		if(strName=="CB3")
			nCB3Idx=idx;

		if(strName=="CONS")
			nCONSIdx=idx;

		lisRec=new CLisRecord(nType,lAddr,pBlankRec->lNextRecLen-4,strName);
		//lisRec->bMultiBlock = false;
		lisRec->nBlockNum = 1;
		
		lisRecordArr.Add(lisRec);
		idx++;
		progress.StepIt();
	}
	
	progress.SetPos(0);

	ReadDataFormatSpecificationRecord();
	
	this->ReadWellInfo(nOUTPIdx, this->OUTPArr);

	this->ReadWellInfo(nCONSIdx, this->CONSArr);

	this->ReadWellInfo(nAK73Idx, this->AK73Arr);

	this->ReadWellInfo(nCB3Idx, this->CB3Arr);

	this->ReadWellInfo(nToolIdx, this->ToolArr);

	this->ReadWellInfo(nChanIdx, this->ChanArr);
	
	/////////////////  Calculate lStep //////////////////
	lStep = long(this->dataFormatSpec.fFrameSpacing);
	if(dataFormatSpec.nFrameSpacingUnit==DEPTH_UNIT_FEET)
		;
	else if(dataFormatSpec.nFrameSpacingUnit==DEPTH_UNIT_CM)
		lStep = lStep*10;
	else if(dataFormatSpec.nFrameSpacingUnit==DEPTH_UNIT_M)
		lStep = lStep*1000;
	else if(dataFormatSpec.nFrameSpacingUnit==DEPTH_UNIT_MM)
		;
	else if(dataFormatSpec.nFrameSpacingUnit==DEPTH_UNIT_HMM)
		lStep = lStep/2;

	////////////////////////////////////////////////////

	this->nStartDataRec = this->GetStartDataRecordIdx();
	this->nEndDataRec = this->GetEndDataRecordIdx();

	////////////////////////////////////////////////////
	this->nDepthCurveIdx = -1;
	if(this->dataFormatSpec.nDepthRecordingMode == 0)//Depth in each frame
	{
		for(int i = 0; i<this->datumArr.GetSize();i++)
		{
			if(!strcmp(datumArr[i]->szMnemonic, "DEPT"))
			{
				nDepthCurveIdx = i;
				break;
			}
		}
	}
	/////////////////////////////////////////////////////////
	this->ReadDepth();

	this->fStartDepth = this->GetStartDepth();
	this->fEndDepth = this->GetEndDepth();

	bIsFileOpen=true;
}

int CLisFile::OpenLisFile(CString strFN, CProgressCtrl& progress)
{
	CloseLisFile();

	m_strFileName=strFN;
	m_strDatFileName=m_strFileName;

	m_strDatFileName.SetAt(m_strDatFileName.GetLength()-1, 't');
	m_strDatFileName.SetAt(m_strDatFileName.GetLength()-2, 'a');
	m_strDatFileName.SetAt(m_strDatFileName.GetLength()-3, 'd');

	//AfxMessageBox(m_strDatFileName);

	CBlankRecord*	pBlankRec;
	long			lAddr=0;
	long			lPrevAddr;
	long			lNextAddr;
	long			lNextRecLen;
	int				nNum;

	BYTE			group2[4];
	BYTE			group3[4];
	BYTE			group4[4];


	hFile.Open(strFN,CFile::modeRead);

	hFile.Seek(0,SEEK_SET);			
	//Check whether it is a NTI or LIS file
	while(1)
	{
		hFile.Seek(4,SEEK_CUR);			
		hFile.Read(group2,4);
		hFile.Read(group3,4);
		hFile.Read(group4,4);

		ParseBlankRecord(group2,group3,group4,lPrevAddr,lNextAddr,lNextRecLen);
		nNum=int(group4[3]);

		pBlankRec=new CBlankRecord(lPrevAddr,lAddr,lNextAddr,lNextRecLen,nNum);
		blankArr.Add(pBlankRec);

		if(lNextAddr < 0)
			break;
		if(lNextAddr >hFile.GetLength())
			break;

		lAddr=lNextAddr;
		hFile.Seek(lNextRecLen-4,SEEK_CUR);

		if(hFile.GetPosition()>=hFile.GetLength()-16)
			break;
	} 
	nFileType = FILE_TYPE_LIS;

	if(blankArr.GetSize() > 5)
	{
		for(int i = 1; i<blankArr.GetSize()-1; i++)
		{
			if(blankArr[i]->lAddr != blankArr[i+1]->lPrevAddr)
			{
				nFileType = FILE_TYPE_NTI; //file halliburton, khong co blank record
				break;
			}
			if(blankArr[i]->lNextAddr != blankArr[i+1]->lAddr)
			{
				nFileType = FILE_TYPE_NTI; //file halliburton, khong co blank record
				break;
			}
		}
	}
	else
		nFileType = FILE_TYPE_NTI;

	blankArr.RemoveAll();

	hFile.Seek(0,SEEK_SET);			

	/*if(nFileType==FILE_TYPE_NTI)
		AfxMessageBox("Halli");
	else
		AfxMessageBox("Russ");*/

	if(nFileType==FILE_TYPE_NTI)
		OpenNTI(progress);
	else
		OpenLIS(progress);

	return 0;
}

///////////////////////////////////////////////////////////
//
//
//
///////////////////////////////////////////////////////////
void CLisFile::GetAllData(int nCurDataRec)
{
	int				nValue;
	BYTE			Entry[100];
	CLisRecord*		lisRec;

	long			lOldAddr;
	lOldAddr=hFile.GetPosition();
	////////////////////////////////////////////////////
	int		nStartIdx;
	int		nEndIdx;
	BYTE	str[4];
	
	int		nContinue;

	long	lLen;
	long	lStart;
	int		index;
	int		DepthRepr;
	
	lisRec = lisRecordArr[nCurDataRec];

	int		nCurveNum=0;

	for(int i = 0; i<this->datumArr.GetSize(); i++)
		nCurveNum += datumArr[i]->nDataItemNum;
	
	if(this->dataFormatSpec.nDepthRecordingMode == 0)//depth per frame
		nCurveNum -= 1;

	/*if(nCurDataRec == 237)//237
	{
		int k = 0;
	}*/
	if(nFileType == FILE_TYPE_NTI)
		hFile.Seek(lisRec->lAddr+6,SEEK_SET);
	else
		hFile.Seek(lisRec->lAddr+2,SEEK_SET);

	if(nFileType == FILE_TYPE_NTI)
	{
		hFile.Seek(-6,SEEK_CUR);

		//Read Size;
		lStart=hFile.GetPosition();
		hFile.Read(str,4);
		lLen=str[1]+str[0]*256;
		nContinue=str[3];
		//Skip Type;
		hFile.Seek(2,SEEK_CUR);

		//Skip depth;
		//hFile.Seek(4,SEEK_CUR);

		//Read Depth
		//hFile.Read(Entry,GetCodeSize(68));
		//fCurDepth=ReadCode(Entry,68,GetCodeSize(68));
		DepthRepr = this->dataFormatSpec.nDepthRepr;
		hFile.Read(Entry,GetCodeSize(DepthRepr));
		fCurDepth=ReadCode(Entry,DepthRepr,GetCodeSize(DepthRepr));

		index=0;
		lLen=lLen-10;//4 for len, 2 for type, 4 for depth
		if(nContinue == 0)
		{
			hFile.Read(&pByteData[index],lLen);
			index=index+lLen;
		}
		else
		{
			while(1)
			{	
				hFile.Read(&pByteData[index],lLen);
				index=index+lLen;
				
				if(nContinue==2)	break;
				
				hFile.Read(str,4);
				lLen=str[1]+str[0]*256;
				lLen=lLen-4;
				nContinue=str[3];
			}
		}

		
		//int		nDepthSize = GetCodeSize(this->dataFormatSpec.nDepthRepr);
		int		nDepthSize = 4;
		int		byteDataIdx = 0;

		fCurDepth = this->ConvertToMeter(fCurDepth, dataFormatSpec.nDepthUnit);

		int		nFrameNum;
		nFrameNum = this->GetFrameNum(nCurDataRec);
		
		int		nCurFrame = 0;
		
		int		fileDataIdx  = 0;
		float	fValue;

		do
		{
			for(int i = 0; i<this->datumArr.GetSize(); i++)
			{
				if(i == 0 && dataFormatSpec.nDepthRecordingMode == 0) //depth per frame
				{
					continue;
				}
				
				if(datumArr[i]->nSize <= 4)
				{
					for(int j = 0; j<datumArr[i]->nSize; j++)
						Entry[j] = pByteData[byteDataIdx++];

					
					fValue = ReadCode(Entry, datumArr[i]->nReprCode, datumArr[i]->nSize);	
					
					
					if(fabs(fValue - this->dataFormatSpec.fAbsentValue) < 0.00001)
						fValue = NULLVALUE;
					
					fFileData[fileDataIdx++] = fValue;
				}
				else
				{
					int		nNb = datumArr[i]->nSize/GetCodeSize(datumArr[i]->nReprCode);
					for(int j = 0; j<nNb; j++)
					{
						for(int k = 0; k < GetCodeSize(datumArr[i]->nReprCode); k++)
							Entry[k] = pByteData[byteDataIdx++];
						//fFileData[fileDataIdx++] = ReadCode(Entry, datumArr[i]->nReprCode, GetCodeSize(datumArr[i]->nReprCode));
						fValue = ReadCode(Entry, datumArr[i]->nReprCode, datumArr[i]->nSize);	
						if(fabs(fValue - this->dataFormatSpec.fAbsentValue) < 0.00001)
							fValue = NULLVALUE;
						fFileData[fileDataIdx++] = fValue;
					}
				}
			}
			//Bypass depth
			if(this->dataFormatSpec.nDepthRecordingMode == 0) //Depth per frame
				byteDataIdx+= nDepthSize;
			
			nCurFrame++;
		}while(nCurFrame<nFrameNum);
	}
	else //Russia LIS file
	{
		lLen = lisRec->lLen;
		hFile.Read(&pByteData[0],lLen);

		int		nDepthSize = GetCodeSize(this->dataFormatSpec.nDepthRepr);
		int		byteDataIdx;

		for(byteDataIdx = 0; byteDataIdx<nDepthSize; byteDataIdx++)
			Entry[byteDataIdx] = pByteData[byteDataIdx];

		fCurDepth = ReadCode(Entry,this->dataFormatSpec.nDepthRepr,nDepthSize);

		fCurDepth = this->ConvertToMeter(fCurDepth, dataFormatSpec.nDepthUnit);

		int		nFrameNum;
		nFrameNum = this->GetFrameNum(nCurDataRec);
		
		int		nCurFrame = 0;
		
		int		fileDataIdx  = 0;
		float	fValue;

		do
		{
			for(int i = 0; i<this->datumArr.GetSize(); i++)
			{
				if(i == 0 && dataFormatSpec.nDepthRecordingMode == 0) //depth per frame
				{
					continue;
				}
				
				if(datumArr[i]->nSize <= 4)
				{
					for(int j = 0; j<datumArr[i]->nSize; j++)
						Entry[j] = pByteData[byteDataIdx++];

					
					fValue = ReadCode(Entry, datumArr[i]->nReprCode, datumArr[i]->nSize);	
					
					
					if(fabs(fValue - this->dataFormatSpec.fAbsentValue) < 0.00001)
						fValue = NULLVALUE;
					
					fFileData[fileDataIdx++] = fValue;
				}
				else
				{
					int		nNb = datumArr[i]->nSize/GetCodeSize(datumArr[i]->nReprCode);
					for(int j = 0; j<nNb; j++)
					{
						for(int k = 0; k < GetCodeSize(datumArr[i]->nReprCode); k++)
							Entry[k] = pByteData[byteDataIdx++];
						//fFileData[fileDataIdx++] = ReadCode(Entry, datumArr[i]->nReprCode, GetCodeSize(datumArr[i]->nReprCode));
						fValue = ReadCode(Entry, datumArr[i]->nReprCode, datumArr[i]->nSize);	
						if(fabs(fValue - this->dataFormatSpec.fAbsentValue) < 0.00001)
							fValue = NULLVALUE;
						fFileData[fileDataIdx++] = fValue;
					}
				}
			}
			//Bypass depth
			if(this->dataFormatSpec.nDepthRecordingMode == 0) //Depth per frame
				byteDataIdx+= nDepthSize;
			
			nCurFrame++;
		}while(nCurFrame<nFrameNum);
	}

	////////////////////////////////////////////////
	hFile.Seek(lOldAddr,SEEK_SET);
}

//////////////////////////////////////////////////////////

int CLisFile::GetLisRecordNum(void)
{
	return lisRecordArr.GetSize();
}
int		CLisFile::GetFrameNum(int nCurDataRec)
{
	int				nResult = 0;
	CLisRecord*		lisRec;
	int				nLen;

	if(nFileType == FILE_TYPE_LIS)
	{
		lisRec = lisRecordArr[nCurDataRec];
		nLen  = lisRec->lLen;
		nLen -= 2;

		if(this->dataFormatSpec.nDepthRecordingMode == 1)
			nLen -= GetCodeSize(this->dataFormatSpec.nDepthRepr);
		nResult = nLen / this->dataFormatSpec.nDataFrameSize;
	}
	else if(nFileType == FILE_TYPE_NTI)
	{
		lisRec = lisRecordArr[nCurDataRec];
		nLen  = lisRec->lLen;
		nLen -= 6;
		//nLen -= (lisRec->nBlockNum - 1)*4;

		if(this->dataFormatSpec.nDepthRecordingMode == 1)
			nLen -= GetCodeSize(this->dataFormatSpec.nDepthRepr);
		nResult = nLen / this->dataFormatSpec.nDataFrameSize;
	}

	return nResult;
}
//void	CLisFile::WriteToDatFile(float fTop, float fBottom,  CProgressCtrl* m_Process,
//								 float	fStep, int nStepFactor)
void	CLisFile::WriteToDatFile(float fTop, float fBottom,  CProgressCtrl* m_Process)
{
	HANDLE hFile1 = CreateFile(m_strDatFileName,
		GENERIC_WRITE, FILE_SHARE_READ,
		NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);

	CString		strTextFile = m_strDatFileName + "1";
	
	//FILE*		file2;
	//file2 = fopen(strTextFile.GetBuffer(), "w");

	if (hFile1 == INVALID_HANDLE_VALUE)
	{
		AfxMessageBox(_T("Couldn't create DAT file!"));
		return;
	}

	// Attach a CFile object to the handle we have.
	CFile file1(hFile1);
	

	int		nCurveNum = 0;
	CLisRecord*	lisRec;

	for(int i = 0; i<this->datumArr.GetSize(); i++)
		nCurveNum += datumArr[i]->nRealSize;
	
	if(this->dataFormatSpec.nDepthRecordingMode == 0)//Depth per frame
		nCurveNum -= 1;

	file1.Write(&nCurveNum, sizeof(int));

	long	lSmallStep;
	int		nMaxNbSample = 1;
	for(int i = 0; i<this->datumArr.GetSize(); i++)
		if(this->datumArr[i]->nNbSample > nMaxNbSample)
			nMaxNbSample = this->datumArr[i]->nNbSample;
	lSmallStep = lStep/nMaxNbSample;

	file1.Write(&lSmallStep, sizeof(long));
	file1.Write(&nMaxNbSample, sizeof(int));

	if(m_Process != NULL)
	{
		m_Process->SetRange(0, this->nEndDataRec - this->nStartDataRec);
		m_Process->SetStep(1);
		m_Process->SetPos(0);
	}

	if(nFileType == FILE_TYPE_NTI)//Halliburton
	{
		long	lCurDepth;
		float**	fWriteData;
		int		firstCurveIdx = 0;

		if(this->dataFormatSpec.nDepthRecordingMode == 0)
			firstCurveIdx = 1;

		if(nMaxNbSample > 1)
		{
			fWriteData = new float*[nMaxNbSample];
			for(int i= 0; i<nMaxNbSample; i++)
				fWriteData[i] = new float[nCurveNum];
		}

		if(this->dataFormatSpec.nDirection == 1) //up
		{
			int		nFrameNum;
			int		nCurFrame;
			long	lCurDepth;
			
			for(nCurDataRec=nEndDataRec; 	
				nCurDataRec>=nStartDataRec;nCurDataRec--)
			{
				nFrameNum = this->GetFrameNum(nCurDataRec);
				this->GetAllData(nCurDataRec);
				
				lCurDepth = long(fCurDepth*1000);

				lCurDepth = lCurDepth - (nFrameNum-1)*lStep;

				nCurFrame = nFrameNum - 1;

				do
				{
					if(nMaxNbSample <= 1)
					{
						file1.Write(&lCurDepth, sizeof(long));
						file1.Write(&fFileData[nCurFrame*nCurveNum], sizeof(float)*nCurveNum);
					}
					else
					{
						//Copy data
						int		dataItemIdx = 0;
						int		startIdx = 0;
						for(int i = firstCurveIdx; i<this->datumArr.GetSize();i++)
						{
							for(int j = 0; j<nMaxNbSample; j++)
							{
								float*	pt = fWriteData[j];
								for(int k = 0; k<this->datumArr[i]->nRealSize;k++)
									pt[startIdx + k] = fFileData[nCurFrame*nCurveNum + dataItemIdx + k];
								if(this->datumArr[i]->nNbSample > j+1)
									dataItemIdx += this->datumArr[i]->nRealSize;
							}
							dataItemIdx += this->datumArr[i]->nRealSize;
							startIdx += this->datumArr[i]->nRealSize;
						}
						for(int i = 0; i<nMaxNbSample;i++)
						{
							long	lDepth;
							lDepth = lCurDepth + i*lSmallStep;

							file1.Write(&lDepth, sizeof(long));
							file1.Write(fWriteData[i], sizeof(float)*nCurveNum);

							
						}
					}
					
					nCurFrame--;
					lCurDepth += lStep;
				}while(nCurFrame >= 0 );

				if(m_Process != NULL)
					m_Process->StepIt();
			}
		}
		else//down
		{
			/*for(nCurDataRec=nStartDataRec; 	
				nCurDataRec<=nEndDataRec;nCurDataRec++)
			{
				
				this->GetAllData(nCurDataRec);
				lCurDepth = fCurDepth*1000;
				file1.Write(&lCurDepth, sizeof(long));
				file1.Write(fFileData, sizeof(float)*nCurveNum);
				m_Process->StepIt();
			}*/
			int		nFrameNum;
			int		nCurFrame;
			long	lCurDepth;
			
			for(nCurDataRec=nStartDataRec; 	
				nCurDataRec<=nEndDataRec;nCurDataRec++)
			{
				nFrameNum = this->GetFrameNum(nCurDataRec);
				this->GetAllData(nCurDataRec);
				
				lCurDepth = long(fCurDepth*1000);

				//lCurDepth = lCurDepth - (nFrameNum-1)*lStep;

				//nCurFrame = nFrameNum - 1;
				nCurFrame = 0;

				do
				{
					if(nMaxNbSample <= 1)
					{
						file1.Write(&lCurDepth, sizeof(long));
						file1.Write(&fFileData[nCurFrame*nCurveNum], sizeof(float)*nCurveNum);
					}
					else
					{
						//Copy data
						int		dataItemIdx = 0;
						int		startIdx = 0;
						for(int i = firstCurveIdx; i<this->datumArr.GetSize();i++)
						{
							for(int j = 0; j<nMaxNbSample; j++)
							{
								float*	pt = fWriteData[j];
								for(int k = 0; k<this->datumArr[i]->nRealSize;k++)
									pt[startIdx + k] = fFileData[nCurFrame*nCurveNum + dataItemIdx + k];
								if(this->datumArr[i]->nNbSample > j+1)
									dataItemIdx += this->datumArr[i]->nRealSize;
							}
							dataItemIdx += this->datumArr[i]->nRealSize;
							startIdx += this->datumArr[i]->nRealSize;
						}
						for(int i = 0; i<nMaxNbSample;i++)
						{
							long	lDepth;
							lDepth = lCurDepth + i*lSmallStep;

							file1.Write(&lDepth, sizeof(long));
							file1.Write(fWriteData[i], sizeof(float)*nCurveNum);
						}
					}
					
					nCurFrame++;
					lCurDepth += lStep;
				}while(nCurFrame < nFrameNum );

				if(m_Process != NULL)
					m_Process->StepIt();
			}
		}

		if(nMaxNbSample > 1)
		{
			for(int i = 0; i<nMaxNbSample; i++)
				delete[] fWriteData[i];
			delete[] fWriteData;
		}
	}
	else //Russia
	{	
		if(this->dataFormatSpec.nDirection == 1) //up
		{
			int		nFrameNum;
			int		nCurFrame;
			long	lCurDepth;

			for(nCurDataRec=nEndDataRec; 	
				nCurDataRec>=nStartDataRec;nCurDataRec--)
			{
				nFrameNum = this->GetFrameNum(nCurDataRec);
				this->GetAllData(nCurDataRec);
				
				lCurDepth = long(fCurDepth*1000);

				//fCurDepth = fCurDepth - (nFrameNum-1)*(lStep/1000.0);
				lCurDepth = lCurDepth - (nFrameNum-1)*lStep;
				

				nCurFrame = nFrameNum - 1;

				do
				{
					//fCurDepth = float(lCurDepth)/1000.0;
					//file1.Write(&this->fCurDepth, sizeof(float));
					file1.Write(&lCurDepth, sizeof(long));
					file1.Write(&fFileData[nCurFrame*nCurveNum], sizeof(float)*nCurveNum);

					nCurFrame--;
					//fCurDepth += (lStep/1000.0);
					lCurDepth += lStep;
				}while(nCurFrame > 0 );

				if(m_Process != NULL)
					m_Process->StepIt();
			}
		}
		else //if(this->dataFormatSpec.nDirection == 2) //down
		{
			//int k =0;
			/*for(nCurDataRec=nStartDataRec; 	
				nCurDataRec<=nEndDataRec;nCurDataRec++)
			{
				//lisRec = lisRecordArr[nCurDataRec];
				//hFile.Seek(lisRec->lAddr+6,SEEK_SET);
				this->GetAllData(nCurDataRec);
				file1.Write(&this->fCurDepth, sizeof(float));
				file1.Write(fFileData, sizeof(float)*nCurveNum);
			}*/

			int		nFrameNum;
			int		nCurFrame;
			long	lCurDepth;

			//for(nCurDataRec=nEndDataRec; 	
			//	nCurDataRec>=nStartDataRec;nCurDataRec--)
			for(nCurDataRec=nStartDataRec; 	
				nCurDataRec<=nEndDataRec;nCurDataRec++)
			{
				nFrameNum = this->GetFrameNum(nCurDataRec);
				this->GetAllData(nCurDataRec);
				
				lCurDepth = long(fCurDepth*1000);

				//fCurDepth = fCurDepth - (nFrameNum-1)*(lStep/1000.0);
				lCurDepth = lCurDepth + (nFrameNum-1)*lStep;

				//nCurFrame = nFrameNum - 1;
				nCurFrame = 0;

				do
				{
					//fCurDepth = float(lCurDepth)/1000.0;
					//file1.Write(&this->fCurDepth, sizeof(float));
					file1.Write(&lCurDepth, sizeof(long));
					file1.Write(&fFileData[nCurFrame*nCurveNum], sizeof(float)*nCurveNum);

					nCurFrame++;
					//fCurDepth += (lStep/1000.0);
					lCurDepth += lStep;
				}while(nCurFrame < nFrameNum );

				if(m_Process != NULL)
					m_Process->StepIt();
			}
		}
	}
	file1.Close();
	
	/*if(nCurDataRec == nEndDataRec - 2500)
	{
		CString	str;
		str.Format("%ld ", lDepth);
		fwrite(str.GetBuffer(), 1, str.GetLength(), file2);
		float*	pt = fWriteData[i];
		for(int j = 0; j<nCurveNum; j++)
		{
			str.Format("%.2f ", pt[j]);
			fwrite(str.GetBuffer(), 1, str.GetLength(), file2);
		}
		str = "\r\n";
		fwrite(str.GetBuffer(), 1, str.GetLength(), file2);
	}*/
	//fclose(file2);
	if(m_Process != NULL)
		m_Process->SetPos(0);
}

//////////////////////////////////////////////////////////////
//					
//			Version: Final
//			Date:	 10/12/2012
//
//////////////////////////////////////////////////////////////
float CLisFile::GetStep() //Step in meter
{
	return lStep/1000.0;
}

float CLisFile::ReadCode(BYTE Entry[], BYTE nReprCode, BYTE nSize)
{
	if(nReprCode == 56)
	{
		unsigned char	ch[4];
		unsigned int	nResult=0;
		float			fResult;

		ch[0]=unsigned char(Entry[0]);

		if(ch[0] < 128)//So duong
		{
			fResult = ch[0];
		}
		else//so am
		{
			nResult = ch[0];
			nResult=~nResult;
			nResult=nResult+1;

			fResult = nResult;
			fResult = (-1)*fResult;
		}

		return fResult;
	}
	if(nReprCode==65)//chuoi ky tu
	{
		char	sz[100];
		for(int i=0;i<nSize;i++)
		{
			if(Entry[i]==32)
			{
				sz[i]=0;
				break;
			}
			sz[i]=Entry[i];
		}
		sz[i]=0;
		if(!strcmp(sz,"CM"))
			return DEPTH_UNIT_CM;
		else if(!strcmp(sz,".5MM"))
			return DEPTH_UNIT_HMM;
		else if(!strcmp(sz,"MM"))
			return DEPTH_UNIT_MM;
		else if(!strcmp(sz,"M"))
			return DEPTH_UNIT_M;
		else if(!strcmp(sz,".1IN"))
			return DEPTH_UNIT_P1IN;

		return DEPTH_UNIT_UNKNOWN;
	}
	if(nReprCode==66)
	{
		return Entry[0];
	}

	if(nReprCode==68)//so thuc 32 bit
	{
		unsigned char	ch[4];
		unsigned int	nResult=0;
		float			fResult;
		float			lExponent;
		float			fFraction;
		unsigned int	ntemp;
	
		CString str;

		ch[0]=unsigned char(Entry[0]);
		ch[1]=unsigned char(Entry[1]);
		ch[2]=unsigned char(Entry[2]);
		ch[3]=unsigned char(Entry[3]);

		ntemp=int(ch[0]);
		ntemp=ntemp<<24;
		nResult=nResult | ntemp;
		ntemp=int(ch[1]);
		ntemp=ntemp<<16;
		nResult=nResult | ntemp;
		ntemp=int(ch[2]);
		ntemp=ntemp<<8;
		nResult=nResult | ntemp;
		ntemp=int(ch[3]);	
		nResult=nResult | ntemp;
		if(ch[0]>=128)//negative number
		{
			//Calculate Exponent
			ntemp=nResult & 0x7f800000;
			ntemp=ntemp>>23;
			if(ntemp<=127)
				lExponent=pow(2,127-ntemp);
			else
			{
				//lExponent=1.0/pow(2,ntemp-127);
				lExponent = 1.0;
				for(int ii = 0; ii<ntemp - 127; ii++)
					lExponent/=2.0;
			}
			//Calculate Fraction
			ntemp=nResult & 0x7fffff;
			ntemp=~ntemp;
			ntemp=ntemp+1;
			ntemp=ntemp<<9;
			float	fFactor=0.5;
			fFraction=0;		
			do
			{
				if(ntemp>=0x80000000)
					fFraction+=fFactor;
				fFactor/=2;
				ntemp=ntemp<<1;			
			}while(ntemp>0) ;
			fResult=(-1.0)*fFraction*float(lExponent);
		}
		else// positive
		{
			//Calculate Exponent
			ntemp=nResult & 0x7f800000;
			ntemp=ntemp>>23;
			if(ntemp>=128)
				lExponent=pow(2,ntemp-128);
			else
			{
				//lExponent=1.0/pow(2,128-ntemp);
				lExponent = 1.0;
				for(int ii = 0; ii<128-ntemp; ii++)
					lExponent /=2.0;
			}
			//Calculate Fraction
			ntemp=nResult & 0x7fffff;
			ntemp=ntemp<<9;
			float	fFactor=0.5;
			fFraction=0;		
			do
			{
				if(ntemp>=0x80000000)
					fFraction+=fFactor;
				fFactor/=2;
				ntemp=ntemp<<1;			
			}while(ntemp>0) ;
			fResult=fFraction*float(lExponent);
		}
		return fResult;
	}

	if(nReprCode==73)//So nguyen 32 bit
	{
		unsigned char	ch[4];
		unsigned int	nResult=0;
		unsigned int	ntemp;
		CString str;

		ch[0]=unsigned char(Entry[0]);
		ch[1]=unsigned char(Entry[1]);
		ch[2]=unsigned char(Entry[2]);
		ch[3]=unsigned char(Entry[3]);

		
		ntemp=int(ch[0]);
		ntemp=ntemp<<24;
		nResult=nResult | ntemp;
		ntemp=int(ch[1]);
		ntemp=ntemp<<16;
		nResult=nResult | ntemp;
		ntemp=int(ch[2]);
		ntemp=ntemp<<8;
		nResult=nResult | ntemp;
		ntemp=int(ch[3]);	
		nResult=nResult | ntemp;
		if(ch[0]>=128)
		{
			nResult=~nResult;
			nResult=nResult+1;
			//nResult=-nResult;
			float	fResult = nResult;
			fResult = (-1)*fResult;
			return fResult;
		}

		return nResult;
	}

	if(nReprCode==79)//So nguyen 16 bit
	{
		if(Entry[0]>128)
		{
			short ntemp;
			ntemp=Entry[0];
			ntemp<<=8;
			ntemp+=Entry[1];

			ntemp=~ntemp;
			ntemp+=1;
			return (-1)*ntemp;
		}
		else
		{
			return Entry[0]*256+Entry[1];
		}
	}


	MessageBox(NULL,"ReadCode","Error",MB_OK);
	return -1;
}
int CLisFile::GetCodeSize(BYTE nCode)
{
	if(nCode==49)
		return 2;
	if(nCode==50)
		return 4;
	if(nCode==56)
		return 1;
	if(nCode==66)
		return 1;
	if(nCode==68)
		return 4;
	if(nCode==70)
		return 4;
	if(nCode==73)
		return 4;
	if(nCode==79)
		return 2;
}
int CLisFile::GetCodeType(BYTE nCode)
{
	if(nCode==49)
		return TYPE_FLOAT;
	if(nCode==50)
		return TYPE_FLOAT;
	if(nCode==56)
		return TYPE_INT;
	if(nCode==65)
		return TYPE_CHAR;
	if(nCode==66)
		return TYPE_INT;
	if(nCode==68)
		return TYPE_FLOAT;
	if(nCode==70)
		return TYPE_FLOAT;
	if(nCode==73)
		return TYPE_INT;
	if(nCode==79)
		return TYPE_INT;
	return -1;
}
void CLisFile::ReadDataFormatSpecificationRecord()
{
	if(nDataFSRIdx<0)
		return;

	CLisRecord*	lisRec;
	int			lLen;
	int			nContinue;
	BYTE		str[4];
	int			index=0;

	lisRec=lisRecordArr[nDataFSRIdx];

	if(nFileType==FILE_TYPE_LIS)//Rus
	{
		hFile.Seek(lisRec->lAddr,SEEK_SET);
	
		lLen = lisRec->lLen;
		hFile.Read(&pByteData[0],lLen);
	}
	else //Halli
	{
		hFile.Seek(lisRec->lAddr+6,SEEK_SET);

		//Read data to array
		hFile.Seek(-6,SEEK_CUR);

		//Read Size;
		hFile.Read(str,4);
		lLen=str[1]+str[0]*256;
		nContinue=str[3];
		//Skip Type;
		hFile.Seek(2,SEEK_CUR);

		index=0;
		lLen=lLen-6;//4 for len, 2 for type

		if(nContinue == 1)
		{
			while(1)
			{		
				hFile.Read(&pByteData[index],lLen);
				index=index+lLen;

				if(nContinue==2)	break;
				
				hFile.Read(str,4);
				lLen=str[1]+str[0]*256;
				lLen=lLen-4;
				nContinue=str[3];
			}
		}
		else
		{
			hFile.Read(&pByteData[index],lLen);
			index=index+lLen;
		}
	}
	////////////////////////////////////////////////////////
	//Process array
	BYTE		nEntryBlockType;
	BYTE		nSize;
	BYTE		nReprCode;
	BYTE		Entry[1000];
	int			idx = 0;

	if(nFileType==FILE_TYPE_LIS)//Rus
	{	
		idx = 2;
		nEntryBlockType = pByteData[idx++];
	}
	else
		nEntryBlockType = pByteData[idx++];
	
	dataFormatSpec.nDepthRepr = 68;

	bool bDataFrameSizeExist = false;
	while(nEntryBlockType!=0)
	{
		nSize = pByteData[idx++];
		nReprCode = pByteData[idx++];
		for(int i = 0; i<nSize; i++)
			Entry[i] = pByteData[idx++];
		switch(nEntryBlockType)
		{
		case 1:
			dataFormatSpec.nDataRecordType=int(ReadCode(Entry,nReprCode,nSize));		
			break;
		case 2:
			dataFormatSpec.nDatumSpecBlockType=int(ReadCode(Entry,nReprCode,nSize));		
			break;
		case 3:		
			dataFormatSpec.nDataFrameSize=int(ReadCode(Entry,nReprCode,nSize));
			bDataFrameSizeExist = true;
			break;
		case 4:
			dataFormatSpec.nDirection=int(ReadCode(Entry,nReprCode,nSize));
			break;
		case 5:
			dataFormatSpec.nOpticalDepthUnit=int(ReadCode(Entry,nReprCode,nSize));
			break;
		case 6:		
			dataFormatSpec.fDataRefPoint=ReadCode(Entry,nReprCode,nSize);
			break;
		case 7:
			dataFormatSpec.nDataRefPointUnit=int(ReadCode(Entry,nReprCode,nSize));
			break;
		case 8:
			dataFormatSpec.fFrameSpacing=ReadCode(Entry,nReprCode,nSize);
			break;
		case 9:
			dataFormatSpec.nFrameSpacingUnit=int(ReadCode(Entry,nReprCode,nSize));
			break;
		case 10:
			//Currently Undefined
			break;
		case 11://Khong su dung
			dataFormatSpec.nMaxFramesPerRecord=int(ReadCode(Entry,nReprCode,nSize));
			break;
		case 12:
			dataFormatSpec.fAbsentValue=ReadCode(Entry,nReprCode,nSize);
			break;
		case 13:
			dataFormatSpec.nDepthRecordingMode=int(ReadCode(Entry,nReprCode,nSize));
			break;
		case 14:
			dataFormatSpec.nDepthUnit=int(ReadCode(Entry,nReprCode,nSize));
			break;
		case 15:
			dataFormatSpec.nDepthRepr=int(ReadCode(Entry,nReprCode,nSize));
			break;
		case 16:
			dataFormatSpec.nDatumSpecBlockSubType=int(ReadCode(Entry,nReprCode,nSize));
			break;
		}

		//hFile.Read(&nEntryBlockType,1);
		nEntryBlockType = pByteData[idx++];
	}

	if(bDataFrameSizeExist == false)
	{
		CLisRecord*	lisRec = lisRecordArr[nStartDataRec];

		int nTotalLen = lisRec->lLen;
		int	nDataFrameSize;

		//dataFormatSpec.nDataFrameSize
		if(this->dataFormatSpec.nDepthRecordingMode == 0)//depth per frame
		{
			if(nFileType == FILE_TYPE_NTI)//Halli
				nDataFrameSize = nTotalLen - 6;
			else
				nDataFrameSize = nTotalLen - 2;
		}
		else//Depth per record
		{
			if(nFileType == FILE_TYPE_NTI)//Halli
				nDataFrameSize = nTotalLen - 6;
			else
				nDataFrameSize = nTotalLen - 2;
			
			nDataFrameSize -=GetCodeSize(dataFormatSpec.nDepthRepr);
		}
		dataFormatSpec.nDataFrameSize = nDataFrameSize;
	}
	/////////////////////////////////////////////////////
	nSize = pByteData[idx++];
	nReprCode = pByteData[idx++];
	for(int i = 0; i<nSize; i++)
		idx++;

	int				nDatumSpecBlockNum=0;
	CDatumSpecBlk	*datumBlk;
	
	BYTE			tempchar;
	BYTE			szEntry[100];
	int				nOffset=0;

	int				m = (idx+6);////4 for len, 2 for type
	if(nFileType==FILE_TYPE_LIS)//Rus
		m = idx;
	else
		m = (idx+6);

	int				nGaps = (lisRec->nBlockNum-1)*4;
	nDatumSpecBlockNum=(lisRec->lLen - m - nGaps)/40;
	for(int i=0;i<nDatumSpecBlockNum;i++)
	{
		datumBlk=new CDatumSpecBlk();

		for(int j = 0; j<4; j++)
			datumBlk->szMnemonic[j] = pByteData[idx++];
		datumBlk->szMnemonic[4]=0;
		for(int j=3;j>=0;j--)
			if(datumBlk->szMnemonic[j]==' ')
				datumBlk->szMnemonic[j]=0;
			else
				break;
		if(i>0 && (!strcmp(datumBlk->szMnemonic, "DEPT")))
			strcpy(datumBlk->szMnemonic, "DEP1");

		for(int j = 0; j<6; j++)
			datumBlk->szServiceID[j] = pByteData[idx++];
		datumBlk->szServiceID[6]=0;
		for(j=5;j>=0;j--)
			if(datumBlk->szServiceID[j]==' ')
				datumBlk->szServiceID[j]=0;
			else
				break;

		for(int j = 0; j<8; j++)
			datumBlk->szServiceOrderNb[j] = pByteData[idx++];
		datumBlk->szServiceOrderNb[8]=0;
		for(j=7;j>=0;j--)
			if(datumBlk->szServiceOrderNb[j]==' ')
				datumBlk->szServiceOrderNb[j]=0;
			else
				break;

		for(int j = 0; j<4; j++)
			datumBlk->szUnits[j] = pByteData[idx++];
		datumBlk->szUnits[4]=0;
		for(j=3;j>=0;j--)
			if(datumBlk->szUnits[j]==' ')
				datumBlk->szUnits[j]=0;
			else
				break;

		//API Codes
		idx = idx+4;
		
		//File Number
		szEntry[0] = pByteData[idx++];
		szEntry[1] = pByteData[idx++];
		datumBlk->nFileNb=int(ReadCode(szEntry,79,2));

		//hFile.Read(szEntry,2);
		szEntry[0] = pByteData[idx++];
		szEntry[1] = pByteData[idx++];
		datumBlk->nSize=int(ReadCode(szEntry,79,2));

		idx = idx+3;

		tempchar = pByteData[idx++];
		datumBlk->nNbSample=int(tempchar);

		tempchar = pByteData[idx++];
		datumBlk->nReprCode=int(tempchar);

		datumBlk->nOffset=nOffset;

		datumBlk->nDataItemNum = datumBlk->nSize/GetCodeSize(datumBlk->nReprCode);
				
		idx = idx + 5;

		nOffset+=(datumBlk->nSize);

		datumBlk->nRealSize = datumBlk->nDataItemNum/datumBlk->nNbSample;

		datumArr.Add(datumBlk);
	}
}
void CLisFile::ReadWellInfo(int idxTab, CWellInfoArray& arr)
{
	if(idxTab<0)
		return;

	BYTE		nType;
	BYTE		nReprCode;
	BYTE		nCategory;
	BYTE		nSize;
	BYTE		szMnemonic[5];
	BYTE		szUnit[5];
	
	CLisRecord*	lisRec;
	BYTE		Entry[1000];

	lisRec=lisRecordArr[idxTab];


	int				nValue;	
	long			lOldAddr;
	lOldAddr=hFile.GetPosition();

	int				nStartIdx;
	int				nEndIdx;
	BYTE			str[4];
	int				nContinue;

	long			lLen;
	long			lStart;
	int				index;
	
	hFile.Seek(lisRec->lAddr, SEEK_SET);


	if(nFileType==FILE_TYPE_LIS)
	{
		hFile.Seek(lisRec->lAddr,SEEK_SET);
		
		lLen = lisRec->lLen;
		hFile.Read(&pByteData[0],lLen);
		index = lLen;
	}
	else
	{
		//Read Size;
		lStart=hFile.GetPosition();
		hFile.Read(str,4);
		lLen=str[1]+str[0]*256;
		nContinue=str[3];
		//Skip Type;
		hFile.Seek(2,SEEK_CUR);

		index=0;
		lLen=lLen-6;//4 for len, 2 for type
		if(nContinue == 0)
		{
			hFile.Read(&pByteData[index],lLen);
			index=index+lLen;
		}
		else
		{
			while(1)
			{	
				hFile.Read(&pByteData[index],lLen);
				index=index+lLen;
				
				if(nContinue==2)	break;
				
				hFile.Read(str,4);
				lLen=str[1]+str[0]*256;
				lLen=lLen-4;
				nContinue=str[3];
			}
		}
	}

	hFile.Seek(lOldAddr,SEEK_SET);
	//////////////////////////////////////////////
	lLen = index;
	index = 0;

	CWellInfoBlk*	pHeaderBlk;
	int				i;

	//while(hFile.GetPosition()<=lisRec->lAddr+lisRec->lLen-1)
	if(nFileType==FILE_TYPE_LIS)
		index = 2;

	while(index < lLen-1)
	{
		pHeaderBlk=new CWellInfoBlk();

		nType = pByteData[index++];
		nReprCode = pByteData[index++];
		nSize = pByteData[index++];
		nCategory = pByteData[index++];
		for(i = 0; i<4; i++)
			szMnemonic[i] = pByteData[index++];
		for(i = 0; i<4; i++)
			szUnit[i] = pByteData[index++];
		pHeaderBlk->nNo = nType;
		pHeaderBlk->nReprCode = nReprCode;
		pHeaderBlk->nSize = nSize;
		pHeaderBlk->nCategory = nCategory;
		pHeaderBlk->szMnemonic[4] = 0;
		pHeaderBlk->szUnit[4] = 0;
		for(i = 0; i< 4; i++)
		{
			pHeaderBlk->szMnemonic[i] = szMnemonic[i];
			pHeaderBlk->szUnit[i] = szUnit[i];
		}
		for(i = 0; i<nSize; i++)
			Entry[i] = pByteData[index++];

		Entry[nSize]=0;
		for(i=nSize-1;i>=0;i--)
			if(Entry[i]==' ')
				Entry[i]=0;
			else
				break;
		Entry[i+1]=0;

		
		if(GetCodeType(nReprCode)==TYPE_CHAR)
		{
			pHeaderBlk->nType=TYPE_CHAR;
			for(i=nSize-1;i>=0;i--)
			if(Entry[i]==' ')
				Entry[i]=0;
			else
				break;
			Entry[i+1]=0;

			if(nSize >= 90)
				Entry[90] = 0;
			strcpy(pHeaderBlk->szValue,(char*)Entry);
		}
		else if(GetCodeType(nReprCode)==TYPE_INT)
		{
			pHeaderBlk->nType=TYPE_INT;
			pHeaderBlk->nValue=int(ReadCode(Entry,nReprCode,nSize));
		}
		else if(GetCodeType(nReprCode)==TYPE_FLOAT)
		{
			pHeaderBlk->nType=TYPE_FLOAT;
			pHeaderBlk->fValue=ReadCode(Entry,nReprCode,nSize);
		}
		
		arr.Add(pHeaderBlk);
	}
}

int CLisFile::GetStartDataRecordIdx()
{
	CLisRecord*	lisRec;

	for(int i=0;i<lisRecordArr.GetSize();i++)
	{
		lisRec=lisRecordArr[i];
		
		if(lisRec->nType==0 && lisRec->lLen > dataFormatSpec.nDataFrameSize)
		{
			return i;			
		}
	}

	return -1;
}

int CLisFile::GetEndDataRecordIdx()
{
	CLisRecord*	lisRec;

	for(int i = lisRecordArr.GetSize()-1;i >= 0; i--)
	{
		lisRec=lisRecordArr[i];
		
		if(lisRec->nType==0 && lisRec->lLen > dataFormatSpec.nDataFrameSize)
		{
			return i;			
		}
	}

	return -1;
}
float	CLisFile::ConvertToMeter(float fDepth, int nMode)
{
	float	fRet = fDepth;

	if(nMode==DEPTH_UNIT_FEET)
		;
	else if(nMode==DEPTH_UNIT_CM)
		fRet = fRet/100.0;
	else if(nMode==DEPTH_UNIT_M)
		;
	else if(nMode==DEPTH_UNIT_MM)
		fRet = fRet/1000.0;
	else if(nMode==DEPTH_UNIT_HMM)
		fRet = fRet/2000.0;
	else if(nMode==DEPTH_UNIT_P1IN)
		fRet = fRet*0.00254;

	return fRet;
}
float CLisFile::GetStartDepth()
{
	float		fDepth = -1;

	if(this->dataFormatSpec.nDepthRecordingMode == 0)//depth per frame
	{
		if(nFileType == FILE_TYPE_NTI)//Halli
			hFile.Seek(lisRecordArr[this->nStartDataRec]->lAddr + 6, SEEK_SET);
		else
			hFile.Seek(lisRecordArr[this->nStartDataRec]->lAddr + 2, SEEK_SET);;
		
		BYTE		Entry[100];
		int			DepthRepr;
		
		DepthRepr = datumArr[this->nDepthCurveIdx]->nReprCode;

		hFile.Read(Entry,GetCodeSize(DepthRepr));
		fDepth=ReadCode(Entry,DepthRepr,GetCodeSize(DepthRepr));
	}
	else //Depth per record
	{
		if(nFileType == FILE_TYPE_NTI)//Halli
			hFile.Seek(lisRecordArr[this->nStartDataRec]->lAddr + 6, SEEK_SET);
		else
			hFile.Seek(lisRecordArr[this->nStartDataRec]->lAddr + 2, SEEK_SET);;
		
		BYTE		Entry[100];
		int			DepthRepr;

		DepthRepr = this->dataFormatSpec.nDepthRepr;
		hFile.Read(Entry,GetCodeSize(DepthRepr));
		fDepth=ReadCode(Entry,DepthRepr,GetCodeSize(DepthRepr));
	}
	
	fDepth = this->ConvertToMeter(fDepth, dataFormatSpec.nDepthUnit);

	return fDepth;
}

float CLisFile::GetEndDepth()
{
	float		fDepth;

	if(this->dataFormatSpec.nDepthRecordingMode == 0)//depth per frame
	{
		if(nFileType == FILE_TYPE_NTI)//Halli
			hFile.Seek(lisRecordArr[this->nEndDataRec]->lAddr + 6, SEEK_SET);
		else
			hFile.Seek(lisRecordArr[this->nEndDataRec]->lAddr + 2, SEEK_SET);

		BYTE		Entry[100];
		
		int			DepthRepr;
		
		DepthRepr = datumArr[this->nDepthCurveIdx]->nReprCode;

		hFile.Read(Entry,GetCodeSize(DepthRepr));
		fDepth=ReadCode(Entry,DepthRepr,GetCodeSize(DepthRepr));
		
		fDepth = this->ConvertToMeter(fDepth, dataFormatSpec.nDepthUnit);
		
		int			nFrameNum = 0;

		nFrameNum = int(lisRecordArr[this->nEndDataRec]->lLen/this->dataFormatSpec.nDataFrameSize);

		//fDepth += (nFrameNum-1)*(lStep/1000.0);
		if(this->dataFormatSpec.nDirection == 2) // down
			fDepth += (nFrameNum-1)*(lStep/1000.0);
		else if(this->dataFormatSpec.nDirection == 1) //up
			fDepth -= (nFrameNum-1)*(lStep/1000.0);
	}
	else //depth per record
	{
		if(nFileType == FILE_TYPE_NTI)//Halli
			hFile.Seek(lisRecordArr[this->nEndDataRec]->lAddr + 6, SEEK_SET);
		else
			hFile.Seek(lisRecordArr[this->nEndDataRec]->lAddr + 2, SEEK_SET);

		BYTE		Entry[100];
		int			DepthRepr;
		
		DepthRepr = this->dataFormatSpec.nDepthRepr;
		hFile.Read(Entry,GetCodeSize(DepthRepr));
		fDepth=ReadCode(Entry,DepthRepr,GetCodeSize(DepthRepr));
		fDepth = this->ConvertToMeter(fDepth, dataFormatSpec.nDepthUnit);

		int			nFrameNum = 0;

		nFrameNum = int(lisRecordArr[this->nEndDataRec]->lLen/this->dataFormatSpec.nDataFrameSize);
		
		if(this->dataFormatSpec.nDirection == 2) // down
			fDepth += (nFrameNum-1)*(lStep/1000.0);
		else if(this->dataFormatSpec.nDirection == 1) //up
			fDepth -= (nFrameNum-1)*(lStep/1000.0);

	}
	return fDepth;
}


void CLisFile::ReadDepth()
{
	for(int nCurDataRec=nStartDataRec; 	
				nCurDataRec<=nEndDataRec;nCurDataRec++)
	{
		CLisRecord*		lisRec;

		////////////////////////////////////////////////////
		int		nStartIdx;
		int		nEndIdx;
		BYTE	str[4];
		BYTE	Entry[256];
		float	fCurDepth;

		long	lLen;
		long	lStart;
		int		index;
	
		lisRec = lisRecordArr[nCurDataRec];

		if(lisRec->nType != 0)
			continue;
		
		if(nFileType == FILE_TYPE_NTI)
			hFile.Seek(lisRec->lAddr+6,SEEK_SET);
		else
			hFile.Seek(lisRec->lAddr+2,SEEK_SET);

		if(nFileType == FILE_TYPE_NTI)
		{
			hFile.Seek(-6,SEEK_CUR);

			//Read Size;
			lStart=hFile.GetPosition();
			hFile.Read(str,4);
			lLen=str[1]+str[0]*256;
			//nContinue=str[3];
			//Skip Type;
			hFile.Seek(2,SEEK_CUR);

			//Read Depth
			hFile.Read(Entry,GetCodeSize(68));
			//hFile.Read(Entry,100);
			fCurDepth=ReadCode(Entry,68,GetCodeSize(68));

			int		nDepthSize = 4;
			int		byteDataIdx = 0;
		
			fCurDepth = this->ConvertToMeter(fCurDepth, dataFormatSpec.nDepthUnit);
		}
		else //Russia LIS file
		{
			lLen = lisRec->lLen;
			hFile.Read(&pByteData[0],lLen);

			int		nDepthSize = GetCodeSize(this->dataFormatSpec.nDepthRepr);
			int		byteDataIdx;

			for(byteDataIdx = 0; byteDataIdx<nDepthSize; byteDataIdx++)
				Entry[byteDataIdx] = pByteData[byteDataIdx];

			fCurDepth = ReadCode(Entry,this->dataFormatSpec.nDepthRepr,nDepthSize);

			fCurDepth = this->ConvertToMeter(fCurDepth, dataFormatSpec.nDepthUnit);
		}
		lisRec->fDepth = fCurDepth;
	}

	//Recalculate 
	//int				nCurDataRec=nStartDataRec;
	CLisRecord*		lisRec;
	int				startArr[100];
	int				endArr[100];
	int				nCount = 0;

	int				nCurDataRec1=nStartDataRec;

	while(1)
	{
		lisRec = lisRecordArr[nCurDataRec1];
		while(lisRec->nType != 0 && nCurDataRec1 <= nEndDataRec)	
		{
			nCurDataRec1++;
			lisRec = lisRecordArr[nCurDataRec1];
		}

		startArr[nCount] = nCurDataRec1;
		while(lisRec->nType == 0 && nCurDataRec1 < nEndDataRec)
		{
			nCurDataRec1++;
			lisRec = lisRecordArr[nCurDataRec1];
		}
		//endArr[nCount] = nCurDataRec1-1;
		if(lisRecordArr[nCurDataRec1]->nType == 0)
			endArr[nCount] = nCurDataRec1;
		else
			endArr[nCount] = nCurDataRec1-1;
		nCount++;
		
		if(nCurDataRec1 >= nEndDataRec)
			break;
	}

	if(nCount == 1)
	{
		nStartDataRec = startArr[0];
		nEndDataRec = endArr[0];
	}
	else
	{
		int		maxLen = -1;
		int		maxIdx = 0;
		for(int i = 0; i<nCount;i++)
		{
			if(endArr[i] - startArr[i]> maxLen)
			{
				maxIdx = i;
				maxLen = endArr[i] - startArr[i];
			}
		}
		nStartDataRec = startArr[maxIdx];
		nEndDataRec = endArr[maxIdx];
	}


	if(this->dataFormatSpec.fFrameSpacing <= 0)
	{
		CLisRecord*		lisRec;
		float			fDepth1, fDepth2;

		lisRec = lisRecordArr[nStartDataRec];
		fDepth1 = lisRec->fDepth;

		lisRec = lisRecordArr[nStartDataRec+1];
		fDepth2 = lisRec->fDepth;

		int nFrameNum;

		nFrameNum = lisRecordArr[nStartDataRec]->lLen / this->dataFormatSpec.nDataFrameSize;
		
		this->dataFormatSpec.fFrameSpacing = fabs(fDepth1 - fDepth2)/nFrameNum;

		this->lStep = this->dataFormatSpec.fFrameSpacing*1000;
	}
}
void	CLisFile::GetStepList(float step[], int factor[], int&	nStepCount)
{
#define		LISTMAXSIZE		20
struct	StepInfo_t
{
	int		nCount;
	int		idx;
};
	StepInfo_t		stepArr[LISTMAXSIZE];
	

	for(int i = 0; i<LISTMAXSIZE; i++)	
	{
		stepArr[i].nCount = 0;
		stepArr[i].idx    = i;
	}
	nStepCount = 0;

	for(int i = 0; i<this->datumArr.GetSize(); i++)
	{
		int		idx = this->datumArr[i]->nNbSample;
		stepArr[idx].nCount++;
	}

	for(int i = 0; i<LISTMAXSIZE-1; i++)
		for(int j = i+1; j<LISTMAXSIZE; j++)
			if(stepArr[i].nCount < stepArr[j].nCount)
			{
				StepInfo_t temp;
				temp = stepArr[i];
				stepArr[i] = stepArr[j];
				stepArr[j] = temp;
			}

	for(int i = 0; i<LISTMAXSIZE; i++)
		if(stepArr[i].nCount <= 0)
			break;
		else
			nStepCount++;

	for(int i = 0; i<nStepCount; i++)
	{
		step[i]   = this->lStep/stepArr[i].idx;
		factor[i] = stepArr[i].idx;
	}
}