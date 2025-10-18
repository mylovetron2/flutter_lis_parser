#include "StdAfx.h"
#include ".\lisfileclass.h"
#include <math.h>

int LISMisc::GetReprCodeSize(int nReprCode)
{
    switch (nReprCode)
    {
        case REPRCODE_56:
        case REPRCODE_66:
            return 1;
        case REPRCODE_49:
        case REPRCODE_79:
                return 2;
        case REPRCODE_50:
        case REPRCODE_68:
        case REPRCODE_70:
        case REPRCODE_73:
                return 4;
    }
    return 2;
}

CString LISMisc::FindLogicalRecordTypeName(int nType)
{
	switch (nType)
    {
        case 0: return "Normal Data";
        case 1: return "Alternate Data";

        case 32: return "Job Identification";
        case 34: return "Wellsite Data";
        case 39: return "Tool String Info";
        case 42: return "Encrypted Table Dump";
        case 47: return "Table Dump";

        case 64: return "Data Format Specification";
        case 65: return "Data Descriptor";

        case 95: return "TU10 Software Boot";
        case 96: return "Bootstrap Loader";
        case 97: return "CP-Kernel Loader Boot";
        case 100: return "Program File Header";
        case 101: return "Program Overlay Header";
        case 102: return "Program Overlay Load";

        case 128: return "File Header";
        case 129: return "File Trailer";
        case 130: return "Tape Header";
        case 131: return "Tape Trailer";
        case 132: return "Real Header";
        case 133: return "Real Trailer";
        case 137: return "Logical EOF";
        case 138: return "Logical BOT";
        case 139: return "Logical EOT";
        case 141: return "Logical EOM";

        case 224: return "Operator Command Inputs";
        case 225: return "Operator Response Inputs";
        case 227: return "System Outputs to Operator";
        case 232: return "FLIC Comment";
        case 234: return "Blank Record/CSU Comment";
        case 85: return "Picture";
        case 86: return "Image";
    }
    return "Unknown";
}
double LISMisc::ConvertDepthValue(double fDepth, CString strOldDU, CString strNewDU)
{
	double fDepth1 = fDepth;
    //m,dm, cm, mm, in, ft
    // 1 in = 2.54 cm
    // 1 foot = 30.48 centimeters
    // 1 foot = 12 in
    strOldDU = strOldDU.MakeLower();
    strNewDU = strNewDU.MakeLower();
    strOldDU.Trim();
    strNewDU.Trim();

    if (strOldDU == "") strOldDU = "mm";

    float fFactor = 1;

    //Xu ly truong hop don vi do co dang 0.1 in, 20 cm
    int     idx = 0;
    CString strUnit="";
    CString strFactor="";

    while ((strOldDU[idx] >= '0' && strOldDU[idx] <= '9') || strOldDU[idx] == '.')
        idx++;

    strFactor = strOldDU.Mid(0, idx);
    if(strFactor.GetLength()>=1)
		fFactor = fabs(atof(strFactor));
    strUnit = strOldDU.Mid(idx , strOldDU.GetLength() - idx );
    strOldDU = strUnit;

    if (strNewDU == "m")
    {
        if (strOldDU == "m") return fFactor * fDepth;
        else if (strOldDU == "dm") return fFactor * fDepth * 0.1;
        else if (strOldDU == "cm") return fFactor * fDepth * 0.01;
        else if (strOldDU == "mm") return fFactor * fDepth * 0.001;
        else if (strOldDU == "in") return fFactor * fDepth * 0.0254;
        else if (strOldDU == "ft") return fFactor * fDepth * 0.3048;
    }

    return fDepth1;
	
}

int LISMisc::ReadReprCode(BYTE byteArr[], int nCount, int nReprCode,
                 ReprCodeReturn& ret, int& nRealSize, int nCurPos)
{
	//nType //1=Integer; 2=double; 3=string

    int byte1, byte2, byte3, byte4 ;
    int tmp1, tmp2, tmp3, tmp4, temp;

    nRealSize = nCount;

	ret.Init();

	// REPRCODE_49 - 16 bit floating point
    if (nReprCode == REPRCODE_49)//16 bit floating point
    {
        ret.nType = 2; //double;

        nRealSize = 2;

        byte1 = byteArr[0 + nCurPos];
        byte2 = byteArr[1 + nCurPos];

        int S = 1, E = 128;
        double M = 0;

        tmp1 = (byte1 << 4);
        tmp2 = (byte2 >> 4);
        tmp1 = (tmp1 | tmp2);

        S = 1;
        if ((tmp1 & 0x800) == 0x800)//so am
        {
            tmp1 = (~tmp1) & 0xFFF;
            tmp1 = tmp1 + 1;
            tmp1 = (tmp1 & 0xFFF);
            S = -1;
        }

        E = (byte2 & 0x0F);

        /////////////////////////////////////////////////////
        double factor[] = { 0.5, 0.25, 0.125, 0.0625, 0.03125, 0.015625, 0.0078125,
                            0.00390625, 0.001953125, 0.0009765625, 0.00048828125};
        tmp1 = tmp1 << 1;
        for (int i = 0; i < 11; i++)
        {
            if ((tmp1 & 0x800) == 0x800) M += factor[i];
            tmp1 = tmp1 << 1;
        }
        
        //////////////////////////////////////////////////////

        //ret.fValue = M * Math.Pow(2.0, E);
		ret.fValue = M * pow(2.0, E);

        if (S < 0) ret.fValue = -ret.fValue;

		ret.nValue = ret.fValue;

        return 1;
    }
	
	//REPRCODE_50 - 32 bit low Resolution floating point
    if (nReprCode == REPRCODE_50)//32 bit low Resolution floating point
    {
        ret.nType = 2; //double;

        nRealSize = 4;
	
        return 1;
    }



	
	// REPRCODE_56 - 8 bit integer
    if (nReprCode == REPRCODE_56)//8 bit integer
    {
        ret.nType = 1;

        nRealSize = 1;

        byte1 = byteArr[0 + nCurPos];

        if ((byte1 & 0x80) == 0)//so duong
            ret.nValue = byte1;
        else
        {
            tmp1 = byte1;
            tmp1 = (~tmp1 + 1) & 0xFF;
            ret.nValue = tmp1;
            ret.nValue = -ret.nValue;
        }

        ret.fValue = ret.nValue;

        return 1;
    }
    
	// REPRCODE_65 - string
    if (nReprCode == REPRCODE_65)//string
    {
        int nCount1;

        ret.nType = 3;

        nRealSize = nCount;
        nCount1 = nCount;

        for (int i = nCount - 1; i >= 0; i--)
            if (byteArr[i+nCurPos] == 0) nCount1--;

        //string sStr = Encoding.UTF8.GetString(byteArr, nCurPos, nCount1);
		CString sStr((char*)(byteArr+nCurPos), nCount1);

        ret.strValue = sStr;
		ret.strValue.Trim();
		
        return 1;
    }



	
	//REPRCODE_66 - unsigned 8-bit integer
    if (nReprCode == REPRCODE_66)//unsigned 8-bit integer
    {
        ret.nType = 1;

        nRealSize = 1;

        ret.nValue = (int)byteArr[0 + nCurPos];

        ret.fValue = ret.nValue;

        return 1;
    }
     
	// REPRCODE_68 - 32-bit floating point
    if (nReprCode == REPRCODE_68)//32 bit low Resolution floating point
    {
        ret.nType = 2; //double;
        nRealSize = 4;

        byte1 = byteArr[0 + nCurPos];
        byte2 = byteArr[1 + nCurPos];
        byte3 = byteArr[2 + nCurPos];
        byte4 = byteArr[3 + nCurPos];

        int E = 128;
        double M = 0;

        unsigned int E_part;
        unsigned int M_part;

        double factor[] = { 0, 0.5, 0.25, 0.125, 0.0625, 0.03125, 0.015625, 0.0078125,
                            
                                0.00390625, 0.001953125, 0.0009765625, 0.00048828125, 0.000244140625, 0.0001220703125, 0.00006103515625, 0.000030517578125,
                            
                            0.0000152587890625, 0.00000762939453125, 0.000003814697265625, 0.0000019073486328125, 
							    0.00000095367431640625, 0.000000476837158203125, 0.0000002384185791015625,
								0.00000011920928955078125};

        E_part = (unsigned int)(byte1 << 1);
        E_part = E_part & 0xff;
        if (byte2 >= 128) E_part += 1;

        M_part = (unsigned int)((byte2 << 16) | (byte3 << 8) | byte4);
        M_part = M_part & 0x7fffff;

        /////////////////////////////////////////
        if (byte1 >= 128)
            M_part = (~M_part + 1) & 0x7fffff;
        
        E = (int)E_part;

        M_part = (M_part << 8);
        for (int i = 0; i < 24; i++)
        {
            if ((M_part & 0x80000000) == 0x80000000) M += factor[i];
            M_part = (M_part << 1);
        }


        if (byte1 < 128)//So duong
        {
            ret.fValue = M * pow(2.0, E - 128);
        }
        else
        {
            if (fabs(M) < 0.00000001)
                ret.fValue = 0;
            else
                ret.fValue = -M * pow(2.0, 127 - E);       
        }

		ret.nValue = ret.fValue;

        return 1;
    }
	
	//REPRCODE_73 - 2's completement 32 bit integer;
    if (nReprCode == REPRCODE_73)//unsigned 8-bit integer
    {
        ret.nType = 1;

        nRealSize = 4;

        unsigned int	nResult=0;
		unsigned int	ntemp;

        byte1 = byteArr[0 + nCurPos];
        byte2 = byteArr[1 + nCurPos];
        byte3 = byteArr[2 + nCurPos];
        byte4 = byteArr[3 + nCurPos];

        ntemp= (unsigned int)byte1;
		ntemp=ntemp<<24;
		nResult=nResult | ntemp;
		ntemp=(unsigned int)byte2;
		ntemp=ntemp<<16;
		nResult=nResult | ntemp;
		ntemp=(unsigned int)byte3;
		ntemp=ntemp<<8;
		nResult=nResult | ntemp;
		ntemp=(unsigned int)byte4;	
		nResult=nResult | ntemp;

        ret.nValue = (int)nResult;
        if (byte1 >= 128)
        {
            nResult = ~nResult;
            nResult = (nResult + 1) & 0xffffffff;

            ret.nValue = -(int)nResult;
        }

        ret.fValue = ret.nValue;

        return 1;
    }

	
	//REPRCODE_79 - 2's completement 16-bit integer
    if (nReprCode == REPRCODE_79)//unsigned 8-bit integer
    {
        ret.nType = 1;

        nRealSize = 2;

        byte1 = byteArr[0 + nCurPos];
        byte2 = byteArr[1 + nCurPos];

        if (byte1 >= 128)
        {
            unsigned int ntemp;

            ntemp = (unsigned int)byte1;
            ntemp <<= 8;
            ntemp += (unsigned int)byte2;

            ntemp = ~ntemp;
            ntemp = (ntemp + 1) & 0xffff;

            ret.nValue = -(int)ntemp;
        }
        else
        {
            ret.nValue = 256 * byte1 + byte2;
        }

        ret.fValue = ret.nValue;

        return 1;
    }

	AfxMessageBox("Read Repr. Code");
	return 0;
}


long LISMisc::Convert4Bytes2Long(BYTE group[])
{
	long	l16x2=256;
	long	l16x4=65536;
	long	l16x6=16777216;

	long	lValue =long(group[0])+long(group[1])*l16x2+
				long(group[2])*l16x4+long(group[3])*l16x6;
	return lValue;
}

/////////////////////////////////////////////////////////////
//
//
//////////////////////////////////////////////////////////////
LISFileClass::LISFileClass(void)
{
	this->strFileName = "";
	this->hFile = NULL;
	this->nFileSize = 0;

	this->lrArr = NULL;
	this->nLogicalRecordNum = 0;

	this->nLogicalFileNum = 0;
	this->pBytesBuf = NULL;

	this->progressBar = NULL;
}

LISFileClass::~LISFileClass(void)
{
	ReleaseResources();
}


int LISFileClass::GetNextPR(int nLRNum, int nCurIdx1, int nCurIdx2, int& nNextIdx1, int& nNextIdx2)
{
	if (nCurIdx2 < lrArr[nCurIdx1].nPhysicalRecordNum - 1)
    {
        nNextIdx1 = nCurIdx1;
        nNextIdx2 = nCurIdx2 + 1;
        return 1;
    }
    else
    {
        if ((nCurIdx1 >= nLRNum - 1) && (nCurIdx2 >= lrArr[nCurIdx1].nPhysicalRecordNum - 1))
            return 0;

        nNextIdx1 = nCurIdx1 + 1;
        nNextIdx2 = 0;
        return 1;
    }
	return 0;
}

int LISFileClass::GetPrevPR(int nCurIdx1, int nCurIdx2, int& nPrevIdx1, int& nPrevIdx2)
{
	if (nCurIdx2 > 0)
    {
        nPrevIdx1 = nCurIdx1;
        nPrevIdx2 = nCurIdx2 - 1;
        return 1;
    }
    else //nCurIdx2 == 0
    {
        if (nCurIdx1 == 0)
            return 0;

        nPrevIdx1 = nCurIdx1 - 1;
        nPrevIdx2 = lrArr[nCurIdx1 - 1].nPhysicalRecordNum - 1;
        return 1;
    }
	return 0;
}


void LISFileClass::ReleaseEFLRArr(bool bAll)
{
	JobIDPos.RemoveAll();
    WellsiteDataPos.RemoveAll();
    ToolStringInfoPos.RemoveAll();
    TableDumpPos.RemoveAll();
    DataFormatSpecPos.RemoveAll();
    FileHeaderPos.RemoveAll();
    FileTrailerPos.RemoveAll();

    if (bAll)
    {
        TapeHeaderPos.RemoveAll();
        TapeTrailerPos.RemoveAll();
        ReelHeaderPos.RemoveAll();
        ReelTrailerPos.RemoveAll();
    }

    CommentPos.RemoveAll();
}
void LISFileClass::ReleaseDATASETArr(void)
{
	for(int i = 0; i<DATASETArr.GetCount();i++)
	{
		if(DATASETArr[i].hFile != NULL)
		{
			fclose(DATASETArr[i].hFile);
			DATASETArr[i].hFile = NULL;
		}
	}

	DATASETArr.RemoveAll();
}

void LISFileClass::ReleaseResources(void)
{
	if(hFile != NULL)
	{
		fclose(hFile);
		hFile = NULL;
	}

	if(this->pBytesBuf != NULL)
	{
		delete[] this->pBytesBuf;
		this->pBytesBuf = NULL;
	}
	
	for(int i = 0; i<this->nLogicalRecordNum;i++)
	{
		if(this->lrArr[i].prArr != NULL)
		{
			delete[] this->lrArr[i].prArr;
			this->lrArr[i].prArr = NULL;
		}
	}
	delete[] this->lrArr;
	this->lrArr = NULL;
	
	//chansArr.RemoveAll();
	this->ReleaseChansArr();

	ReleaseDATASETArr();

	this->ReleaseEFLRArr(true);

	//stepArr.RemoveAll();

	for(int i = 0; i<this->nLogicalFileNum; i++)
		this->logicalFileArr[i].ReleaseResources();
}
void LISFileClass::ReleaseChansArr(void)
{
	for(int i = 0; i<chansArr.GetCount();i++)
		if(chansArr[i].fData != NULL)
		{
			delete[] chansArr[i].fData;
			chansArr[i].fData = NULL;
		}
	chansArr.RemoveAll();
}
double LISFileClass::GetStartDepth(void)
{
	double fDepth = -1;
    BYTE byteArr[100];
    int nReprCode;
    ReprCodeReturn ret;
    int nRealSize;

    if (this->entryBlock.nDepthRecordingMode == 0)//Depth per frame
    {
        nReprCode = chansArr[this->nDepthCurveIdx].nReprCode;
    }
    else //Depth per record
    {
        nReprCode = this->entryBlock.nDepthRepr;
    }

	fseek(hFile, lrArr[this->nFirstIFLR1].lAddress + 6 ,SEEK_SET);
	fread(byteArr, sizeof(BYTE), LISMisc::GetReprCodeSize(nReprCode),hFile);
    //hFile.BaseStream.Seek(lrArr[this.nFirstIFLR1].lAddress + 6, SeekOrigin.Begin);
    //hFile.Read(byteArr, 0, Misc.GetReprCodeSize(nReprCode));

	LISMisc::ReadReprCode(byteArr, LISMisc::GetReprCodeSize(nReprCode), nReprCode, ret, nRealSize);

    fDepth = ret.fValue;

    if (this->entryBlock.nDepthRecordingMode == 0)//Depth per frame
		fDepth = LISMisc::ConvertDepthValue(fDepth, this->chansArr[nDepthCurveIdx].strUnits, "m");
    else//Depth per record
		fDepth = LISMisc::ConvertDepthValue(fDepth, this->entryBlock.strDepthUnit, "m");

    return fDepth;
}

double LISFileClass::GetEndDepth(double fStep)
{
	double fDepth = -1;
    BYTE byteArr[100];
    int nReprCode;
    ReprCodeReturn ret;
    int nRealSize;

    int nExtraBytes = this->GetExtraBytesInLogRec(this->nEndIFLR1);

    if (this->entryBlock.nDepthRecordingMode == 0)//Depth per frame
    {
        nReprCode = chansArr[this->nDepthCurveIdx].nReprCode;
    }
    else //Depth per record
    {
        nReprCode = this->entryBlock.nDepthRepr;
		nExtraBytes += LISMisc::GetReprCodeSize(nReprCode);
    }

	fseek(hFile, lrArr[this->nEndIFLR1].lAddress + 6 ,SEEK_SET);
	fread(byteArr, sizeof(BYTE), LISMisc::GetReprCodeSize(nReprCode),hFile);
    //hFile.BaseStream.Seek(lrArr[this.nEndIFLR1].lAddress + 6, SeekOrigin.Begin);
    //hFile.Read(byteArr, 0, Misc.GetReprCodeSize(nReprCode));

	LISMisc::ReadReprCode(byteArr, LISMisc::GetReprCodeSize(nReprCode), nReprCode, ret, nRealSize);

    fDepth = ret.fValue;

    if (this->entryBlock.nDepthRecordingMode == 0)//Depth per frame
		fDepth = LISMisc::ConvertDepthValue(fDepth, this->chansArr[nDepthCurveIdx].strUnits, "m");
    else//Depth per record
		fDepth = LISMisc::ConvertDepthValue(fDepth, this->entryBlock.strDepthUnit, "m");

    int nFrameNum = ((int)lrArr[this->nEndIFLR1].lLen - nExtraBytes) / this->nFrameSizeInBytes;

    if (this->entryBlock.nDirection == 255)//Down
    {
        fDepth = fDepth + (nFrameNum - 1) * fStep;
    }
    else if (this->entryBlock.nDirection == 1)//up
    {
        fDepth = fDepth - (nFrameNum - 1) * fStep;
    }

    return fDepth;	
}

int LISFileClass::GetExtraBytesInLogRec(int nLRIdx)
{
	int n = 6;

    n += (this->lrArr[nLRIdx].nPhysicalRecordNum - 1) * 4;

    return n;
}
int LISFileClass::ReadLogRecBytes(int nLRIdx)
{
	int		nTotalSize = 0;
    int		nCurrentSize = 0;
    int		nIdx1, nIdx2;
	CPoint	pt;
	CString	str;

    nIdx1 = nLRIdx;
    
    bool bFileNumPresence;
    bool bRecordNumPresence;

	//Calculate TotalSize
    nTotalSize = (int)this->lrArr[nIdx1].prArr[0].lLen - 6;
    bFileNumPresence =  ((this->lrArr[nIdx1].prArr[0].attr1 & 0x4) > 0);
    bRecordNumPresence = ((this->lrArr[nIdx1].prArr[0].attr1 & 0x2) > 0);
    if (bFileNumPresence) nTotalSize -= 2;
    if (bRecordNumPresence) nTotalSize -= 2;

    for (int i = 1; i < this->lrArr[nIdx1].nPhysicalRecordNum; i++)
    {
        nTotalSize += (int)this->lrArr[nIdx1].prArr[i].lLen - 4;

        bFileNumPresence = ((this->lrArr[nIdx1].prArr[i].attr1 & 0x4) > 0);
        bRecordNumPresence = ((this->lrArr[nIdx1].prArr[i].attr1 & 0x2) > 0);
        if (bFileNumPresence) nTotalSize -= 2;
        if (bRecordNumPresence) nTotalSize -= 2;
    }
	////////////////////////////////////////////////////
	//Read ByteArr
    nCurrentSize = 0;
	fseek(hFile, this->lrArr[nIdx1].prArr[0].lAddress + 6, SEEK_SET);
	fread(this->pBytesBuf + nCurrentSize, sizeof(BYTE), (int)this->lrArr[nIdx1].prArr[0].lLen - 6, hFile);
    
	//for Debug
	int	nn = this->lrArr[nIdx1].prArr[0].lLen - 6;

    nCurrentSize = nCurrentSize + (int)this->lrArr[nIdx1].prArr[0].lLen - 6;
    
    bFileNumPresence = ((this->lrArr[nIdx1].prArr[0].attr1 & 0x4) > 0);
    bRecordNumPresence = ((this->lrArr[nIdx1].prArr[0].attr1 & 0x2) > 0);
    if (bFileNumPresence) nCurrentSize -= 2;
    if (bRecordNumPresence) nCurrentSize -= 2;

    for (int i = 1; i < this->lrArr[nIdx1].nPhysicalRecordNum; i++)
    {
		fseek(hFile, this->lrArr[nIdx1].prArr[i].lAddress + 4, SEEK_SET);
		fread(this->pBytesBuf + nCurrentSize, sizeof(BYTE), (int)this->lrArr[nIdx1].prArr[i].lLen - 4, hFile);
        
        nCurrentSize = nCurrentSize + (int)this->lrArr[nIdx1].prArr[i].lLen - 4;

        bFileNumPresence = ((this->lrArr[nIdx1].prArr[i].attr1 & 0x4) > 0);
        bRecordNumPresence = ((this->lrArr[nIdx1].prArr[i].attr1 & 0x2) > 0);
        if (bFileNumPresence) nCurrentSize -= 2;
        if (bRecordNumPresence) nCurrentSize -= 2;
    }

	return nTotalSize;
}

void LISFileClass::Parse(void)
{
	this->ReleaseResources();

	int				pos;
	CString			str;

	pos = this->strFileName.ReverseFind('\\');
	this->strDirName = this->strFileName.Left(pos);
	
	hFile = fopen(this->strFileName, "rb");
	
	fseek(hFile, 0L, SEEK_END);
	nFileSize = ftell(hFile);
	fseek(hFile, 0L, SEEK_SET);

	/////////////////////////////////////////////////////
	// File Type
	long			lAddr=0;
	long			lPrevAddr;
	long			lNextAddr;
	long			lRecLen;
	int				nNum;
	int				nBlankRecNum = 0;
	

	BYTE			group1[16];
	BYTE			group2[16];
	BYTE			group3[16];
	BYTE			group4[16];

	fseek(hFile, 0L, SEEK_SET);
	fread(group1, sizeof(BYTE), 4, hFile);
	
	if(LISMisc::Convert4Bytes2Long(group1) != 0)
		nFileType = FILE_TYPE_NTI;
	else
		nFileType = FILE_TYPE_LIS;

	
	/////////////////////////////////////////////////////
	BYTE	byteArr[2000];

	int		nContinuation;
	int		lrl;
	int		nType;
	int		idx;

	//Count the Logical Record Num
	this->nLogicalRecordNum = 0;
	fseek(hFile, 0L, SEEK_SET);

	lNextAddr = -1;
	lPrevAddr = -1;

    while (true)
    {
		if(nFileType == FILE_TYPE_LIS)
		{
			//Total 12 bytes: 
			fseek(hFile, 4, SEEK_CUR);
			fread(group2, sizeof(BYTE), 4, hFile);
			fread(group3, sizeof(BYTE), 4, hFile);

			lPrevAddr = LISMisc::Convert4Bytes2Long(group2);
			lNextAddr = LISMisc::Convert4Bytes2Long(group3);
		}
	
		fread(byteArr, sizeof(BYTE), 6, hFile);

		lrl = byteArr[0] * 256 + byteArr[1];
		nContinuation = byteArr[3];
        nContinuation = nContinuation & 0x3;
        nType = byteArr[4];

		if(nContinuation == 1)//Logical Record span multiple Physical Record
		{
			fseek(hFile, lrl-6, SEEK_CUR);
			while (nContinuation != 2)
            {
				if(nFileType == FILE_TYPE_LIS)
				{
					//Total 12 bytes: 
					fseek(hFile, 4, SEEK_CUR);
					fread(group2, sizeof(BYTE), 4, hFile);
					fread(group3, sizeof(BYTE), 4, hFile);

					lPrevAddr = LISMisc::Convert4Bytes2Long(group2);
					lNextAddr = LISMisc::Convert4Bytes2Long(group3);
				}

				fread(byteArr, sizeof(BYTE), 4, hFile);
		
				lrl = byteArr[0] * 256 + byteArr[1];
				nContinuation = byteArr[3];
				nContinuation = nContinuation & 0x3;

				fseek(hFile, lrl-4, SEEK_CUR);
			}
		}
		else
		{
			fseek(hFile, lrl-6, SEEK_CUR);
		}

		
		this->nLogicalRecordNum++;

		if(nFileType == FILE_TYPE_NTI)
			if(ftell(hFile)>= nFileSize-1) break;

		if(nFileType == FILE_TYPE_LIS)
			if(ftell(hFile)>= nFileSize-12) break;
	}

	this->lrArr = new LogicalRecord[this->nLogicalRecordNum];

	//str.Format("%d", this->nLogicalRecordNum);
	//AfxMessageBox(str);

	//Count the Physical Record Num in each Logical Record
	if(this->progressBar != NULL)
	{
		this->progressBar->SetRange32(0, this->nLogicalRecordNum*2);
		this->progressBar->SetStep(1);
		this->progressBar->SetPos(0);
	}

	fseek(hFile, 0L, SEEK_SET);
	idx = 0;
	while (true)
    {
		if(nFileType == FILE_TYPE_LIS)
		{
			//Total 12 bytes: 
			fseek(hFile, 4, SEEK_CUR);
			fread(group2, sizeof(BYTE), 4, hFile);
			fread(group3, sizeof(BYTE), 4, hFile);

			lPrevAddr = LISMisc::Convert4Bytes2Long(group2);
			lNextAddr = LISMisc::Convert4Bytes2Long(group3);
		}

		this->lrArr[idx].lAddress = ftell(hFile);

		fread(byteArr, sizeof(BYTE), 6, hFile);
		
		lrl = byteArr[0] * 256 + byteArr[1];
		this->lrArr[idx].lLen = lrl;

		nContinuation = byteArr[3];
        nContinuation = nContinuation & 0x3;
        this->lrArr[idx].nType = byteArr[4];

		this->lrArr[idx].nPhysicalRecordNum = 1;

		if(nContinuation == 1)//Logical Record span multiple Physical Record
		{
			fseek(hFile, lrl-6, SEEK_CUR);
			while (nContinuation != 2)
            {
				if(nFileType == FILE_TYPE_LIS)
				{
					//Total 12 bytes: 
					fseek(hFile, 4, SEEK_CUR);
					fread(group2, sizeof(BYTE), 4, hFile);
					fread(group3, sizeof(BYTE), 4, hFile);

					lPrevAddr = LISMisc::Convert4Bytes2Long(group2);
					lNextAddr = LISMisc::Convert4Bytes2Long(group3);
				}

				fread(byteArr, sizeof(BYTE), 4, hFile);
		
				lrl = byteArr[0] * 256 + byteArr[1];
				nContinuation = byteArr[3];
				nContinuation = nContinuation & 0x3;

				this->lrArr[idx].lLen += lrl;
				this->lrArr[idx].nPhysicalRecordNum++;

				fseek(hFile, lrl-4, SEEK_CUR);
			}
		}
		else
		{
			fseek(hFile, lrl-6, SEEK_CUR);
		}

		idx++;

		//if(ftell(hFile)>= nFileSize-1) break;
		if(nFileType == FILE_TYPE_NTI)
			if(ftell(hFile)>= nFileSize-1) break;

		if(nFileType == FILE_TYPE_LIS)
			if(ftell(hFile)>= nFileSize-12) break;

		if(this->progressBar != NULL)
			this->progressBar->StepIt();
	}

	//Create Physical Record Array in each Logical Record;
	for(int i = 0; i<this->nLogicalRecordNum; i++)
		this->lrArr[i].prArr = new PhysicalRecord[this->lrArr[i].nPhysicalRecordNum];

	fseek(hFile, 0L, SEEK_SET);
	idx = 0;
	while (true)
    {
		if(nFileType == FILE_TYPE_LIS)
		{
			//Total 12 bytes: 
			fseek(hFile, 4, SEEK_CUR);
			fread(group2, sizeof(BYTE), 4, hFile);
			fread(group3, sizeof(BYTE), 4, hFile);

			lPrevAddr = LISMisc::Convert4Bytes2Long(group2);
			lNextAddr = LISMisc::Convert4Bytes2Long(group3);
		}

		this->lrArr[idx].lAddress = ftell(hFile);

		fread(byteArr, sizeof(BYTE), 6, hFile);
		
		lrl = byteArr[0] * 256 + byteArr[1];
		nContinuation = byteArr[3];
        nContinuation = nContinuation & 0x3;
        
		int idx1 = 0;

		this->lrArr[idx].prArr[idx1].lAddress = this->lrArr[idx].lAddress;
		this->lrArr[idx].prArr[idx1].lLen = lrl;
		this->lrArr[idx].prArr[idx1].attr1 = byteArr[2];
		this->lrArr[idx].prArr[idx1].attr2 = byteArr[3];

		if(nContinuation == 1)//Logical Record span multiple Physical Record
		{
			fseek(hFile, lrl-6, SEEK_CUR);
			while (nContinuation != 2)
            {
				if(nFileType == FILE_TYPE_LIS)
				{
					//Total 12 bytes: 
					fseek(hFile, 4, SEEK_CUR);
					fread(group2, sizeof(BYTE), 4, hFile);
					fread(group3, sizeof(BYTE), 4, hFile);

					lPrevAddr = LISMisc::Convert4Bytes2Long(group2);
					lNextAddr = LISMisc::Convert4Bytes2Long(group3);
				}

				idx1++;
				this->lrArr[idx].prArr[idx1].lAddress = ftell(hFile);

				fread(byteArr, sizeof(BYTE), 4, hFile);
		
				lrl = byteArr[0] * 256 + byteArr[1];
				nContinuation = byteArr[3];
				nContinuation = nContinuation & 0x3;

				this->lrArr[idx].prArr[idx1].lLen = lrl;
				this->lrArr[idx].prArr[idx1].attr1 = byteArr[2];
				this->lrArr[idx].prArr[idx1].attr2 = byteArr[3];

				fseek(hFile, lrl-4, SEEK_CUR);
			}
		}
		else
		{
			fseek(hFile, lrl-6, SEEK_CUR);
		}

		idx++;

		if(nFileType == FILE_TYPE_NTI)
			if(ftell(hFile)>= nFileSize-1) break;

		if(nFileType == FILE_TYPE_LIS)
			if(ftell(hFile)>= nFileSize-12) break;

		if(this->progressBar != NULL)
			this->progressBar->StepIt();
	}
	
	if(this->progressBar != NULL)
		this->progressBar->SetPos(0);
	/////////////////////////////////////////////////////////////////////////////////////
	//
	//
	for (int i = 0; i < this->nLogicalRecordNum; i++)
    {
        if (lrArr[i].nType == LRTYPE_JOBID)
        {
            JobIDPos.Add(CPoint(i, 0));
        }
        else if (lrArr[i].nType == LRTYPE_WELLSITEDATA)
        {
            WellsiteDataPos.Add(CPoint(i, 0));
        }
        else if (lrArr[i].nType == LRTYPE_TOOLSTRINGINFO)
        {
            ToolStringInfoPos.Add(CPoint(i, 0));
        }
        else if (lrArr[i].nType == LRTYPE_TABLEDUMP)
        {
            TableDumpPos.Add(CPoint(i, 0));
        }
        else if (lrArr[i].nType == LRTYPE_DATAFORMATSPEC)
        {
            DataFormatSpecPos.Add(CPoint(i, 0));
        }
        else if (lrArr[i].nType == LRTYPE_FILEHEADER)
        {
            FileHeaderPos.Add(CPoint(i, 0));
        }
        else if (lrArr[i].nType == LRTYPE_FILETRAILER)
        {
            FileTrailerPos.Add(CPoint(i, 0));
        }
        else if (lrArr[i].nType == LRTYPE_TAPEHEADER)
        {
            TapeHeaderPos.Add(CPoint(i, 0));
        }
        else if (lrArr[i].nType == LRTYPE_TAPETRAILER)
        {
            TapeTrailerPos.Add(CPoint(i, 0));
        }
        else if (lrArr[i].nType == LRTYPE_REELHEADER)
        {
            ReelHeaderPos.Add(CPoint(i, 0));
        }
        else if (lrArr[i].nType == LRTYPE_REELTRAILER)
        {
            ReelTrailerPos.Add(CPoint(i, 0));
        }
        else if (lrArr[i].nType == LRTYPE_COMMENT)
        {
            CommentPos.Add(CPoint(i, 0));
        }     
    }
	///////////////////////////////////////////////////////////////////
	//
	//
	CreateLogicalFileArr();
	
	//Find the Default Logical file (the longest logical file)
	this->nCurLogicalFile = 0;
	int		lLen = this->lrArr[logicalFileArr[0].nEndIFLR1].lAddress - this->lrArr[logicalFileArr[0].nFirstIFLR1].lAddress;
	for(int i = 1; i<this->nLogicalFileNum; i++)
	{
		if((this->lrArr[logicalFileArr[i].nEndIFLR1].lAddress - 
			this->lrArr[logicalFileArr[i].nFirstIFLR1].lAddress) > lLen)
		{
			this->nCurLogicalFile = i;
			lLen = this->lrArr[logicalFileArr[i].nEndIFLR1].lAddress - 
					this->lrArr[logicalFileArr[i].nFirstIFLR1].lAddress;
		}
	}

	this->ParseLogicalFile(this->nCurLogicalFile);
}

void LISFileClass::CreateLogicalFileArr(void)
{
	int nLogRecNum = this->nLogicalRecordNum;

    int nFirstIFLR1;
    int nFirstIFLR2;
    int nEndIFLR1;
    int nEndIFLR2;

    int nCurLR = 0;

	this->nLogicalFileNum = 0;

    while (true)
    {
        //Skip 
        while ((nCurLR < nLogRecNum) && (lrArr[nCurLR].nType != LRTYPE_NORMALDATA))
            nCurLR++;
        if (nCurLR >= nLogRecNum) break;

        nFirstIFLR1 = nCurLR;
        nEndIFLR1 = nCurLR;

        while ((nCurLR < nLogRecNum) && (lrArr[nCurLR].nType == LRTYPE_NORMALDATA))
        {
            nEndIFLR1 = nCurLR;
            nCurLR++;
        }

		this->logicalFileArr[this->nLogicalFileNum].nFirstIFLR1 = nFirstIFLR1;
		this->logicalFileArr[this->nLogicalFileNum].nEndIFLR1 = nEndIFLR1;

		this->nLogicalFileNum++;

		if(this->nLogicalFileNum >= MAX_LOGICALFILENUM) break;

        if (nCurLR >= nLogRecNum) break;
    }

    int nStartIdx;
    int nEndIdx;
    //CPoint pt;
    int idx;

    for (idx = 0; idx < this->nLogicalFileNum; idx++)
    {
        if (idx == 0)
            nStartIdx = 0;
        else
            nStartIdx = logicalFileArr[idx - 1].nEndIFLR1 + 1;

        if (idx == this->nLogicalFileNum - 1)
            nEndIdx = this->nLogicalRecordNum - 1;
        else
            nEndIdx = logicalFileArr[idx + 1].nFirstIFLR1 - 1;

        for (int i = nStartIdx; i < logicalFileArr[idx].nFirstIFLR1; i++)
        {
            if (lrArr[i].nType == LRTYPE_JOBID)
            {
                //pt = new Point(i, 0);
                logicalFileArr[idx].JobIDPos.Add(CPoint(i, 0));
            }
            else if (lrArr[i].nType == LRTYPE_WELLSITEDATA)
            {
                //pt = new Point(i, 0);
                logicalFileArr[idx].WellsiteDataPos.Add(CPoint(i, 0));
            }
            else if (lrArr[i].nType == LRTYPE_TOOLSTRINGINFO)
            {
                //pt = new Point(i, 0);
                logicalFileArr[idx].ToolStringInfoPos.Add(CPoint(i, 0));
            }
            else if (lrArr[i].nType == LRTYPE_TABLEDUMP)
            {
                //pt = new Point(i, 0);
                logicalFileArr[idx].TableDumpPos.Add(CPoint(i, 0));
            }
            else if (lrArr[i].nType == LRTYPE_DATAFORMATSPEC)
            {
                //pt = new Point(i, 0);
                logicalFileArr[idx].DataFormatSpecPos.Add(CPoint(i, 0));
            }
            else if (lrArr[i].nType == LRTYPE_FILEHEADER)
            {
                //pt = new Point(i, 0);
                logicalFileArr[idx].FileHeaderPos.Add(CPoint(i, 0));
            }
            else if (lrArr[i].nType == LRTYPE_COMMENT)
            {
                //pt = new Point(i, 0);
                logicalFileArr[idx].CommentPos.Add(CPoint(i, 0));
            }
        }


        for (int i = logicalFileArr[idx].nEndIFLR1; i < nEndIdx; i++)
        {
            if (lrArr[i].nType == LRTYPE_FILETRAILER)
            {
                //pt = new Point(i, 0);
                logicalFileArr[idx].FileTrailerPos.Add(CPoint(i, 0));
            }
        }
    }
}


void LISFileClass::ParseLogicalFile(int nCurLF)
{
	 if (lrArr == NULL)
        return;

    //int nLogicalFileNum = logicalFileArr.Count;

    if (nCurLF < 0 || nCurLF >= this->nLogicalFileNum) return;
    /////////////////////////////////////////////////////////
    this->ReleaseEFLRArr(false);

    for (int i = 0; i < logicalFileArr[nCurLF].JobIDPos.GetCount(); i++)
        this->JobIDPos.Add(logicalFileArr[nCurLF].JobIDPos[i]);

    for (int i = 0; i < logicalFileArr[nCurLF].WellsiteDataPos.GetCount(); i++)
        this->WellsiteDataPos.Add(logicalFileArr[nCurLF].WellsiteDataPos[i]);

    for (int i = 0; i < logicalFileArr[nCurLF].ToolStringInfoPos.GetCount(); i++)
        this->ToolStringInfoPos.Add(logicalFileArr[nCurLF].ToolStringInfoPos[i]);

    for (int i = 0; i < logicalFileArr[nCurLF].TableDumpPos.GetCount(); i++)
        this->TableDumpPos.Add(logicalFileArr[nCurLF].TableDumpPos[i]);

    for (int i = 0; i < logicalFileArr[nCurLF].DataFormatSpecPos.GetCount(); i++)
        this->DataFormatSpecPos.Add(logicalFileArr[nCurLF].DataFormatSpecPos[i]);

    for (int i = 0; i < logicalFileArr[nCurLF].FileHeaderPos.GetCount(); i++)
        this->FileHeaderPos.Add(logicalFileArr[nCurLF].FileHeaderPos[i]);

    for (int i = 0; i < logicalFileArr[nCurLF].FileTrailerPos.GetCount(); i++)
        this->FileTrailerPos.Add(logicalFileArr[nCurLF].FileTrailerPos[i]);

    for (int i = 0; i < logicalFileArr[nCurLF].CommentPos.GetCount(); i++)
        this->CommentPos.Add(logicalFileArr[nCurLF].CommentPos[i]);

    ///////////////////////////////////////////////////////////////////
    this->nFirstIFLR1 = logicalFileArr[nCurLF].nFirstIFLR1;
    this->nEndIFLR1 = logicalFileArr[nCurLF].nEndIFLR1;
    
    /*this.ParseReelTape(this.ReelHeaderPos, ref this.reelHeader);
    this.ParseReelTape(this.ReelTrailerPos, ref this.reelTrailer);
    this.ParseReelTape(this.TapeHeaderPos, ref this.tapeHeader);
    this.ParseReelTape(this.TapeTrailerPos, ref this.tapeTrailer);

    this.ParseFile(this.FileHeaderPos, ref this.fileHeader);
    this.ParseFile(this.FileTrailerPos, ref this.fileTrailer);

    this.ParseWellsiteData();

    this.CreateWellsiteDataSet();*/

    this->ParseDataFormatSpecRecord();

    ////////////////////////////////////////////////////
    this->nDepthCurveIdx = -1;
    if (this->entryBlock.nDepthRecordingMode == 0)//Depth in each frame
    {
        for (int i = 0; i < this->chansArr.GetCount(); i++)
        {
			CString		str = this->chansArr[i].strMnemonic;
			str = str.MakeUpper();
            if (str == "DEPT" || str == "DEP")
            {
                nDepthCurveIdx = i;
                break;
            }
        }
		if(this->nDepthCurveIdx == -1) this->nDepthCurveIdx = 0;
    }

    this->nLogRecMaxSize = this->lrArr[nFirstIFLR1].lLen;
    for (int i = nFirstIFLR1; i <= nEndIFLR1; i++)
        if (this->lrArr[i].lLen > this->nLogRecMaxSize)
            this->nLogRecMaxSize = this->lrArr[i].lLen;
	if(this->pBytesBuf != NULL)
		delete[] this->pBytesBuf;
	this->pBytesBuf = new BYTE[this->nLogRecMaxSize];

    this->nFrameSizeInBytes = 0;//in bytes

    for (int i = 0; i < chansArr.GetCount(); i++)
        nFrameSizeInBytes += chansArr[i].nSize;

	fStep = LISMisc::ConvertDepthValue(this->entryBlock.fFrameSpacing, this->entryBlock.strFrameSpacingUnit, "m");
    fStartDepth = this->GetStartDepth();
    fEndDepth = this->GetEndDepth(fStep);
	//////////////////////////////////////////////////////////////////
	
    CreateDataSet();
}

void LISFileClass::ParseDataFormatSpecRecord(void)
{
	
	this->ReleaseChansArr();

    if (this->DataFormatSpecPos.GetCount() < 0) return;

    BYTE	*byteArr;
    int		nTotalSize = 0;
    int		nCurrentSize = 0;
    int		nIdx1, nIdx2;
	CPoint	pt;
	CString	str;

	pt = this->DataFormatSpecPos[0];
    nIdx1 = pt.x;
    nIdx2 = pt.y;

    bool bFileNumPresence;
    bool bRecordNumPresence;

	//Calculate TotalSize
    nTotalSize = (int)this->lrArr[nIdx1].prArr[0].lLen - 6;
    bFileNumPresence =  ((this->lrArr[nIdx1].prArr[0].attr1 & 0x4) > 0);
    bRecordNumPresence = ((this->lrArr[nIdx1].prArr[0].attr1 & 0x2) > 0);
    if (bFileNumPresence) nTotalSize -= 2;
    if (bRecordNumPresence) nTotalSize -= 2;

    for (int i = 1; i < this->lrArr[nIdx1].nPhysicalRecordNum; i++)
    {
        nTotalSize += (int)this->lrArr[nIdx1].prArr[i].lLen - 4;

        bFileNumPresence = ((this->lrArr[nIdx1].prArr[i].attr1 & 0x4) > 0);
        bRecordNumPresence = ((this->lrArr[nIdx1].prArr[i].attr1 & 0x2) > 0);
        if (bFileNumPresence) nTotalSize -= 2;
        if (bRecordNumPresence) nTotalSize -= 2;
    }
	////////////////////////////////////////////////////

    byteArr = new BYTE[nTotalSize + 100];

	//str.Format("%d", nTotalSize);
	//AfxMessageBox(str);
	////////////////////////////////////////////////////
	//Read ByteArr
    nCurrentSize = 0;
	fseek(hFile, this->lrArr[nIdx1].prArr[0].lAddress + 6, SEEK_SET);
	fread(byteArr + nCurrentSize, sizeof(BYTE), (int)this->lrArr[nIdx1].prArr[0].lLen - 6, hFile);
    //hFile.BaseStream.Seek(this.lrArr[nIdx1].prArr[0].lAddress + 6, SeekOrigin.Begin);
    //hFile.Read(byteArr, nCurrentSize, (int)this.lrArr[nIdx1].prArr[0].lLen - 6);

    nCurrentSize = nCurrentSize + (int)this->lrArr[nIdx1].prArr[0].lLen - 6;
    
    bFileNumPresence = ((this->lrArr[nIdx1].prArr[0].attr1 & 0x4) > 0);
    bRecordNumPresence = ((this->lrArr[nIdx1].prArr[0].attr1 & 0x2) > 0);
    if (bFileNumPresence) nCurrentSize -= 2;
    if (bRecordNumPresence) nCurrentSize -= 2;

    for (int i = 1; i < this->lrArr[nIdx1].nPhysicalRecordNum; i++)
    {
		fseek(hFile, this->lrArr[nIdx1].prArr[i].lAddress + 4, SEEK_SET);
		fread(byteArr + nCurrentSize, sizeof(BYTE), (int)this->lrArr[nIdx1].prArr[i].lLen - 4, hFile);
        //hFile.BaseStream.Seek(this.lrArr[nIdx1].prArr[i].lAddress + 4, SeekOrigin.Begin);
        //hFile.Read(byteArr, nCurrentSize, (int)this.lrArr[nIdx1].prArr[i].lLen - 4);
        nCurrentSize = nCurrentSize + (int)this->lrArr[nIdx1].prArr[i].lLen - 4;

        bFileNumPresence = ((this->lrArr[nIdx1].prArr[i].attr1 & 0x4) > 0);
        bRecordNumPresence = ((this->lrArr[nIdx1].prArr[i].attr1 & 0x2) > 0);
        if (bFileNumPresence) nCurrentSize -= 2;
        if (bRecordNumPresence) nCurrentSize -= 2;
    }
    ///////////////////////////////////////////////////////////
	BYTE			nEntryBlockType;
	BYTE			nSize;
    BYTE			nReprCode;
    BYTE			Entry[1000];
	int				nCurPos = 0;
    ReprCodeReturn	ret;
    int				nRealSize;
	///////////////////////////////////////////////////////////
	// Read Entry Block
	this->entryBlock.Init();

    nEntryBlockType = byteArr[nCurPos]; nCurPos++;
    nSize = byteArr[nCurPos]; nCurPos++;
    nReprCode = byteArr[nCurPos]; nCurPos++;
    for (int i = 0; i < nSize; i++)
        Entry[i] = byteArr[nCurPos++];

    while (nEntryBlockType != 0)
    {
        switch (nEntryBlockType)
        {
            case 1://DataRecordType
				LISMisc::ReadReprCode(Entry, nSize, nReprCode, ret, nRealSize);
                this->entryBlock.nDataRecordType = ret.nValue;
                break;
            case 2://DatumSpecBlockType
                LISMisc::ReadReprCode(Entry, nSize, nReprCode, ret, nRealSize);
                this->entryBlock.nDatumSpecBlockType = ret.nValue;
                break;
            case 3://nDataFrameSize
                LISMisc::ReadReprCode(Entry, nSize, nReprCode, ret, nRealSize);
                this->entryBlock.nDataFrameSize = ret.nValue;
                break;
            case 4://nDirection
                LISMisc::ReadReprCode(Entry, nSize, nReprCode, ret, nRealSize);
                this->entryBlock.nDirection = ret.nValue;
                break;
            case 5://nOpticalDepthUnit
                LISMisc::ReadReprCode(Entry, nSize, nReprCode, ret, nRealSize);
                this->entryBlock.nOpticalDepthUnit = ret.nValue;
                break;
            case 6://fDataRefPoint
                LISMisc::ReadReprCode(Entry, nSize, nReprCode, ret, nRealSize);
                this->entryBlock.fDataRefPoint = ret.fValue;
                break;
            case 7://strDataRefPointUnit
                LISMisc::ReadReprCode(Entry, nSize, nReprCode, ret, nRealSize);
                this->entryBlock.strDataRefPointUnit = ret.strValue;
                break;
            case 8://fFrameSpacing
                LISMisc::ReadReprCode(Entry, nSize, nReprCode, ret, nRealSize);
                this->entryBlock.fFrameSpacing = ret.fValue;
                break;
            case 9://strFrameSpacingUnit
                LISMisc::ReadReprCode(Entry, nSize, nReprCode, ret, nRealSize);
                this->entryBlock.strFrameSpacingUnit = ret.strValue;
                break;
            case 10://Currently undefined
                break;
            case 11://nMaxFramesPerRecord
                LISMisc::ReadReprCode(Entry, nSize, nReprCode, ret, nRealSize);
                this->entryBlock.nMaxFramesPerRecord = ret.nValue;
                break;
            case 12://fAbsentValue
                LISMisc::ReadReprCode(Entry, nSize, nReprCode, ret, nRealSize);
                this->entryBlock.fAbsentValue = ret.fValue;
                break;
            case 13://nDepthRecordingMode
                LISMisc::ReadReprCode(Entry, nSize, nReprCode, ret, nRealSize);
                this->entryBlock.nDepthRecordingMode = ret.nValue;
                break;
            case 14://strDepthUnit
                LISMisc::ReadReprCode(Entry, nSize, nReprCode, ret, nRealSize);
                this->entryBlock.strDepthUnit = ret.strValue;
                break;
            case 15://nDepthRepr
                LISMisc::ReadReprCode(Entry, nSize, nReprCode, ret, nRealSize);
                this->entryBlock.nDepthRepr = ret.nValue;
                break;
            case 16://nDatumSpecBlockSubType
                LISMisc::ReadReprCode(Entry, nSize, nReprCode, ret, nRealSize);
                this->entryBlock.nDatumSpecBlockSubType = ret.nValue;
                break;
        }
        ///////////////////////////////////////////////
        //                   Next
        nEntryBlockType = byteArr[nCurPos]; nCurPos++;
        nSize = byteArr[nCurPos]; nCurPos++;
        nReprCode = byteArr[nCurPos]; nCurPos++;
        for (int i = 0; i < nSize; i++)
            Entry[i] = byteArr[nCurPos++];
    }
            
	/////////////////////////////////////////////////////////
	DatumSpecBlock_t datumSpecBlk;

	int idx = 0;
	int offset = 0;
    while (nTotalSize-nCurPos >= 40)
    {
		datumSpecBlk.Init();

		LISMisc::ReadReprCode(byteArr, 4, REPRCODE_65, ret, nRealSize, nCurPos);
        datumSpecBlk.strMnemonic = ret.strValue;
        nCurPos += 4;

        LISMisc::ReadReprCode(byteArr, 6, REPRCODE_65, ret, nRealSize, nCurPos);
        datumSpecBlk.strServiceID = ret.strValue;
        nCurPos += 6;

        LISMisc::ReadReprCode(byteArr, 8, REPRCODE_65, ret, nRealSize, nCurPos);
        datumSpecBlk.strServiceOrderNb = ret.strValue;
        nCurPos += 8;

        LISMisc::ReadReprCode(byteArr, 4, REPRCODE_65, ret, nRealSize, nCurPos);
        datumSpecBlk.strUnits = ret.strValue;
        nCurPos += 4;

        nCurPos += 4; //Skip API Codes

        LISMisc::ReadReprCode(byteArr, 2, REPRCODE_79, ret, nRealSize, nCurPos);
        datumSpecBlk.nFileNb = ret.nValue;
        nCurPos += 2;

        LISMisc::ReadReprCode(byteArr, 2, REPRCODE_79, ret, nRealSize, nCurPos);
        datumSpecBlk.nSize = ret.nValue;
        nCurPos += 2;

        nCurPos += 3; //Skip Process Level;

        LISMisc::ReadReprCode(byteArr, 1, REPRCODE_66, ret, nRealSize, nCurPos);
        datumSpecBlk.nNbSamples = ret.nValue;
        nCurPos += 1;

        LISMisc::ReadReprCode(byteArr, 1, REPRCODE_66, ret, nRealSize, nCurPos);
        datumSpecBlk.nReprCode = ret.nValue;
        nCurPos += 1;

        nCurPos += 5;//Skip Process Indication

		//So luong du lieu tai 1 do sau
		datumSpecBlk.nDataItemNum = datumSpecBlk.nSize / LISMisc::GetReprCodeSize(datumSpecBlk.nReprCode)/datumSpecBlk.nNbSamples;
		datumSpecBlk.nOffsetInBytes = offset;
		
		datumSpecBlk.bFlwChan = false;

		if(datumSpecBlk.nDataItemNum >= 101)
		{
			datumSpecBlk.bFlwChan = true;
		}
		/*if(datumSpecBlk.nDataItemNum >= 150)
		{
			datumSpecBlk.bFlwChan = true;
		}
		else if(datumSpecBlk.nDataItemNum >= 100)
		{
			if(datumSpecBlk.strMnemonic.GetAt(0) == 'W' ||
				datumSpecBlk.strMnemonic.GetAt(0) == 'w')
				datumSpecBlk.bFlwChan = true;
		}*/

        chansArr.Add(datumSpecBlk);

		chansArr[idx].fData = new float[datumSpecBlk.nDataItemNum];

		offset = offset + datumSpecBlk.nSize;
		idx++;
    }

	/////////////////////////////////////////////////////////
	delete[] byteArr;
}

void LISFileClass::CreateDataSet(void)
{
	this->ReleaseDATASETArr();
	//stepArr.RemoveAll();

    if (this->chansArr.GetCount() <= 0) return;

	CArray<int> NbSamplesArr;
	CString		str, str1;

	for(int i = 0; i<chansArr.GetCount(); i++)
	{
		int nNbSamples = chansArr[i].nNbSamples;
		bool	bFound = false;

		for(int j = 0; j<NbSamplesArr.GetCount(); j++)
			if(NbSamplesArr[j] == nNbSamples)
			{
				bFound = true;
				break;
			}

		if(bFound == false)	
			NbSamplesArr.Add(nNbSamples);
	}
	
	Dataset_t dataset;

	for(int i = 0; i<NbSamplesArr.GetCount(); i++)
	{
		dataset.Init();

		str.Format("Dataset_%d.dat", i);
		dataset.strDATFileName = this->strDirName + "\\" + str;
		dataset.nNbSamples = NbSamplesArr[i];
		dataset.nTotalItemNum = 0;
		dataset.fStep = fStep / dataset.nNbSamples;
		
		DATASETArr.Add(dataset);
	}

	this->nMaxNbSamples = NbSamplesArr[0];
	for(int i = 0; i<NbSamplesArr.GetCount(); i++)
		if(NbSamplesArr[i] > this->nMaxNbSamples)
			this->nMaxNbSamples = NbSamplesArr[i];

	//Update chansArr
	int		IdxArr[100];
	int		PosArr[100];

	for(int i = 0; i<100; i++) 
	{
		IdxArr[i] = 0;
		PosArr[i] = 0;
	}
	

	//For debug;
	int		nChannelNum = chansArr.GetCount();
	int		nTotalItemNum = 0;

	for(int i = 0; i<chansArr.GetCount(); i++)
	{
		int nNbSamples = chansArr[i].nNbSamples;

		for(int j = 0; j<NbSamplesArr.GetCount(); j++)
			if(NbSamplesArr[j] == nNbSamples)
			{
				chansArr[i].nDatasetIdx = j;
				chansArr[i].nIndexInDataset = IdxArr[j];
				chansArr[i].nPosInDataset = PosArr[j];
				IdxArr[j]++;
				PosArr[j] += chansArr[i].nDataItemNum;
			}
		this->DATASETArr[chansArr[i].nDatasetIdx].nTotalItemNum += chansArr[i].nDataItemNum;
		nTotalItemNum += chansArr[i].nDataItemNum;
	}

	nTotalItemNum = nTotalItemNum;
}


void LISFileClass::CreateDATFiles(void)
{
	CString			str;
	int				nStartTime = GetTickCount();

	for(int i = 0; i<DATASETArr.GetCount(); i++)
	{
		DATASETArr[i].hFile = fopen(DATASETArr[i].strDATFileName, "wb");
	}

	///////////////////////////////////////////////////////////////////////
	int				nLogRecSize;
	int				nFrameNum;
	
	int				nCurPos;
	float			fCurDepth = 0;
	ReprCodeReturn	ret;
	int				nRealSize;
	int				nDepthReprCode;
	CString			strDepthUnits;
	float			fValue;
	bool			bDepthInFrame;
	int				nLoggingDir = 1;
	
	if(this->entryBlock.nDirection == 1)
		nLoggingDir = -1;

	if(this->entryBlock.nDepthRecordingMode == 0)//Depth in each frame
	{
		nDepthReprCode = chansArr[this->nDepthCurveIdx].nReprCode;
		strDepthUnits = chansArr[this->nDepthCurveIdx].strUnits;
		bDepthInFrame = true;
	}
	else
	{
		strDepthUnits = this->entryBlock.strDepthUnit;
		nDepthReprCode = this->entryBlock.nDepthRepr;
		bDepthInFrame = false;
	}

	if(this->progressBar != NULL)
	{
		this->progressBar->SetRange(0, this->nEndIFLR1- this->nFirstIFLR1);
		this->progressBar->SetStep(1);
		this->progressBar->SetPos(0);
	}

	for(int i = this->nFirstIFLR1; i<= this->nEndIFLR1; i++)
	{
		nLogRecSize = this->ReadLogRecBytes(i);

		if(this->entryBlock.nDepthRecordingMode == 0)//Depth in each frame
			nFrameNum = nLogRecSize/this->nFrameSizeInBytes;
		else // Depth on log rec
			nFrameNum = (nLogRecSize - LISMisc::GetReprCodeSize (this->entryBlock.nDepthRepr))/this->nFrameSizeInBytes;
		
		nCurPos = 0;

		if(this->entryBlock.nDepthRecordingMode == 1)//Depth appear only once in Log Rec;
		{
			LISMisc::ReadReprCode(this->pBytesBuf, LISMisc::GetReprCodeSize(nDepthReprCode), 
					nDepthReprCode, ret, nRealSize, nCurPos);
			//nCurPos += nRealSize;
			fCurDepth = ret.fValue;
			fCurDepth = LISMisc::ConvertDepthValue(fCurDepth, strDepthUnits, "m");
		}

		int		framePos;
		for(int frame = 0; frame<nFrameNum; frame++)
		{
			framePos = frame * this->nFrameSizeInBytes;
			if(bDepthInFrame == false) framePos = framePos + LISMisc::GetReprCodeSize(nDepthReprCode);

			if(bDepthInFrame == true)
			{
				nCurPos = framePos + chansArr[this->nDepthCurveIdx].nOffsetInBytes;
				LISMisc::ReadReprCode(this->pBytesBuf, LISMisc::GetReprCodeSize(nDepthReprCode), 
					nDepthReprCode, ret, nRealSize, nCurPos);
				fCurDepth = ret.fValue;
				fCurDepth = LISMisc::ConvertDepthValue(fCurDepth, strDepthUnits, "m");
			}

			for(int sample = 0; sample < this->nMaxNbSamples; sample++)
			{
				//Ghi do sau (Write Depth)
				for(int dataset = 0; dataset < DATASETArr.GetCount(); dataset++)
				{
					if(sample >= DATASETArr[dataset].nNbSamples) continue;

					float   fDepth;
					//float	fStep = DATASETArr[dataset].fStep;

					if(bDepthInFrame == false) ////Depth appear only once in Log Rec;
						fDepth = fCurDepth + frame * this->fStep * nLoggingDir + 
									sample * DATASETArr[dataset].fStep;
					else//Depth in frame
						//fDepth = fCurDepth + sample * DATASETArr[dataset].fStep;
						fDepth = fCurDepth + sample * DATASETArr[dataset].fStep * nLoggingDir;
					//str.Format("%8.3f ", fDepth);
					//fwrite(str, 1, str.GetLength(), DATASETArr[dataset].hFile);
					fwrite(&fDepth, sizeof(float), 1, DATASETArr[dataset].hFile);
				}

				//Ghi du lieu (Write Data)
				for(int chan = 0; chan <chansArr.GetCount(); chan++)
				{
					if(sample >= chansArr[chan].nNbSamples) continue;
					//if(chan == 1) continue;

					int firstItemPos = chansArr[chan].nOffsetInBytes + 
						sample * chansArr[chan].nDataItemNum * LISMisc::GetReprCodeSize(chansArr[chan].nReprCode);
					firstItemPos = firstItemPos + framePos;
					nCurPos = firstItemPos;

					for(int item = 0; item < chansArr[chan].nDataItemNum; item++)
					{
						LISMisc::ReadReprCode(this->pBytesBuf,
							LISMisc::GetReprCodeSize(chansArr[chan].nReprCode),
							chansArr[chan].nReprCode, ret, nRealSize, nCurPos);
						chansArr[chan].fData[item] = ret.fValue;
						nCurPos += nRealSize;
					}
					fwrite(chansArr[chan].fData, sizeof(float), chansArr[chan].nDataItemNum, 
								DATASETArr[chansArr[chan].nDatasetIdx].hFile);
				}
			}
		}
	
		if(this->progressBar != NULL)
		{
			this->progressBar->StepIt();
		}
	}
	if(this->progressBar != NULL)
	{
		this->progressBar->SetPos(0);
	}

	for(int i = 0; i<DATASETArr.GetCount(); i++)
	{
		fclose(DATASETArr[i].hFile);	
		DATASETArr[i].hFile = NULL;
	}

	///////////////////////////////////////////////////////////////////////
	// Trong truong hop huong do la UP can phai ghi file theo thu tu chieu sau tu tren xuong duoi

	if(this->entryBlock.nDirection == 1) //UP
	{
		FILE*	hTempFile;
		CString	strTempFileName;
		float	fDepth;
		float*	fData = new float[200000];

		for(int i = 0; i<DATASETArr.GetCount(); i++)
		{
			
			DATASETArr[i].hFile = fopen(DATASETArr[i].strDATFileName, "rb");

			strTempFileName = 	DATASETArr[i].strDATFileName + "temp";
			hTempFile = fopen(strTempFileName, "wb");

			fseek(DATASETArr[i].hFile, 0, SEEK_END);
			int nRecordNum = ftell(DATASETArr[i].hFile);
			nRecordNum = (float)nRecordNum/((DATASETArr[i].nTotalItemNum + 1)*sizeof(float));

			
			for(int j = nRecordNum-1; j>= 0; j--)
			{
				
				fseek(DATASETArr[i].hFile, (DATASETArr[i].nTotalItemNum + 1)*sizeof(float)*j, SEEK_SET);

				//Read Source file
				fread(&fDepth, sizeof(float), 1, DATASETArr[i].hFile);
				fread(fData, sizeof(float), DATASETArr[i].nTotalItemNum, DATASETArr[i].hFile);
				
				//Write destination file
				fwrite(&fDepth, sizeof(float), 1, hTempFile);
				fwrite(fData, sizeof(float), DATASETArr[i].nTotalItemNum, hTempFile);
			}
			
			fclose(hTempFile);

			fclose(DATASETArr[i].hFile);	
			DATASETArr[i].hFile = NULL;

			DeleteFile(DATASETArr[i].strDATFileName);
			MoveFile(strTempFileName, DATASETArr[i].strDATFileName);
		}

		delete[] fData;
	}
}



