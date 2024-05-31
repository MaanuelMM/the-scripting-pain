/*++

INTEL CONFIDENTIAL
Copyright 2007-2015 Intel Corporation All Rights Reserved.

The source code contained or described herein and all documents
related to the source code ("Material") are owned by Intel Corporation
or its suppliers or licensors. Title to the Material remains with
Intel Corporation or its suppliers and licensors. The Material
contains trade secrets and proprietary and confidential information of
Intel or its suppliers and licensors. The Material is protected by
worldwide copyright and trade secret laws and treaty provisions. No
part of the Material may be used, copied, reproduced, modified,
published, uploaded, posted, transmitted, distributed, or disclosed in
any way without Intel's prior express written permission.

No license under any patent, copyright, trade secret or other
intellectual property right is granted to or conferred upon you by
disclosure or delivery of the Materials, either expressly, by
implication, inducement, estoppel or otherwise. Any license under such
intellectual property rights must be express and approved by Intel in
writing.

File Name:
   FWUpdateLib.h

Abstract:
   Handles full and partial firmware updates via HECI.

Author:
Inies Chemmannoor

--*/

#ifndef __FW_UPDATE_LIB_H__
#define __FW_UPDATE_LIB_H__

#define INVALID_DATA_FORMAT_VERSION 0
#define INVALID_PARTITION_START     0
#define INVALID_MANIFEST_DATA       1
#define NO_FPT_IMAGE                2
#define MANIFEST_BUFFER             0x1000
#define FPT_PARTITION_NAME_FPT      0x54504624

extern UINT32 g_fwuError;

typedef struct _UPDATE_FLAGS_LIB
{
   UINT32 RestorePoint      :1;       // If set indicate restore point
   UINT32 RestartOperation  :1;       // If set indicate restart operation, like lost hard drive etc...
   UINT32 UserRollback      :1;       // indicates user has initiated a rollback
   UINT32 Reserve           :29;      //
} UPDATE_FLAGS_LIB;

// Used by the tool to perform FULL FW update
typedef enum _UPDATE_TYPE
{
   DOWNGRADE_SUCCESS = 0,
   DOWNGRADE_FAILURE,
   SAMEVERSION_SUCCESS,
   SAMEVERSION_FAILURE,
   UPGRADE_SUCCESS,
   UPGRADE_PROMPT
} UPDATE_TYPE;

// Image type to validate the binary sent to update
// For Full Update - only FULL image type is valid
// For Partial Update - only FULL and PARTIAL image type is valid
// FULL Image => Image with Flash Partition Table, FTPR, and NFTPR
// PARTIAL Image => Image with no Flash Partition Table or FTPR or NFTPR,
//                        only WCOD or LOCL
typedef enum _IMAGE_TYPE
{
   FULL = 0,
   PARTIAL,
   RESTORE,
   INVALID
} IMAGE_TYPE;

typedef enum _SKU_TYPE
{
   SKU_1_5_MB = 0,
   SKU_5_MB,
   SKU_RESERVED,
   SKU_INVALID
} SKU_TYPE;

typedef enum _PCH_SKU
{
   PCH_SKU_H = 0,
   PCH_SKU_LP,
   PCH_SKU_INVALID
} PCH_SKU;

typedef enum _FWUPD_POWER_SOURCE
{
    FWUPD_POWER_SOURCE_AC  = 1,  ///< AC Power source
    FWUPD_POWER_SOURCE_DC  = 2,  ///< DC Power source
    FWUPD_POWER_SOURCE_UNKOWN    ///< Unable to determine power source
} FWUPD_POWER_SOURCE;

//Used by the tool to retrieve FW version information
typedef struct {
    UINT16 Major;
    UINT16 Minor;
    UINT16 Hotfix;
    UINT16 Build;
} VersionLib;

// Should be used by both tool and UNS to retrieve the Updated UPV version
typedef struct _IPU_UPDATED_INFO
{
    UINT32 UpdatedUpvVer; //Version from the update image file that is for updating IPU
    UINT32 Reserved[4];
} IPU_UPDATED_INFO;

#ifdef __cplusplus
    extern "C" {
#endif

//API used only by the tool

#ifdef EFIX64
UINT32 InitializeEFIUpdate();
UINT32 InitializeEFIUpdateNoConsole();
#endif

#if defined(EFIX64) || defined(_DOS) || defined(_RELEASE_LIB) || defined(__linux__)
#define TCHAR char
#endif

UINT32 GetInterfaces(UINT16 *interfaces);

UINT32 GetLastStatus(UINT32 *lastStatus);

UINT32 GetLastUpdateResetType(UINT32 *lastResetType);

int SaveRestorePoint(const char * ImageFileLib);

int GetFwVersion(
    char*    imageFileLib,
    UINT16 *major,
    UINT16 *minor,
    UINT16 *hotfix, 
    UINT16 *build);

UINT32 FwUpdateFull(
    char*            _imageFileLib, 
    char*            _pwd,
    int              _forceResetLib,
    UINT32     UpdateEnvironment, 
    _UUID            OemID,
    UPDATE_FLAGS_LIB update_flags,
    void(*func)(float,float));

UINT32 CheckPolicy(
    char*        ImageFileLib, 
    int          AllowSV, 
    UPDATE_TYPE* Upd_Type,
    VersionLib*  ver);

UINT32 CheckPolicyBuffer(
    char*        buffer, 
    int          bufferLength, 
    int          AllowSV, 
    UPDATE_TYPE* Upd_Type,
    VersionLib*  ver);

BOOL VerifyOemId(_UUID id);

UINT32 IsRestorePointImage(
    char*         ImageFileLib, 
    UINT32* IsRestoreImage);

/**++
********************************************************************************
*
** FUNCTION:
**   GetPchSKU
**
** DESCRIPTION:
**   This function retrieve the platform SKU.
**
** ARGUMENTS:
**    sku    - UINT32 from the user to be populated by the function
**    sku can get 3 possible values:
**      0    H
**      1    LP
**      2    Unknown SKU
** Returns 0 on success

**
********************************************************************************
--*/
UINT32 GetPchSKU(UINT32 *sku);

/**++
********************************************************************************
*
** FUNCTION:
**   GetOemID
**
** DESCRIPTION:
**   This function retrieve the Return FW OEM ID.
**
** ARGUMENTS:
**    pOemIdStr - Pointer to the char array that will contain the string
** Returns 0 on success
**
********************************************************************************
--*/
UINT32 GetOemID (char *pOemIdStr, UINT32 bufferSize);

/**++
********************************************************************************
*
** FUNCTION:
**   GetFwType
**
** DESCRIPTION:
**   This function retrieve the FW type
**
** ARGUMENTS:
**    fwType - UINT32 from the user to be populated by the function
**    fwType can get 4 possible values:
**      0    for 1.5M SKU image (consumer)
**      1    for 5M SKU image (corporate)
**      2    reserved
**      3    Unknown SKU
** Returns 0 on success
**
********************************************************************************
--*/
UINT32 GetFwType(UINT32 *FwType);

//APIs used by both tool and UNS
UINT32 GetIpuPartitionAttributes(
    FWU_GET_IPU_PT_ATTRB_MSG_REPLY *FwuGetIpuAttrbMsgInfo);

UINT32 GetExtendedIpuPartitionAttributes(
    FWU_GET_IPU_PT_ATTRB_MSG_REPLY* FwuGetIpuAttrbMsgInfo,
    UINT32 updateOp);

UINT32 GetFwUpdateInfoStatus(
    FWU_INFO_FLAGS *StatusFlags);

UINT32 FwUpdatePartial(
    TCHAR*             ImageFileName, 
    UINT32      PartitionID,
    UINT32      Flags, 
    IPU_UPDATED_INFO* IpuUpdatedInfo,
    char*             _pwd,
    UINT32      UpdateEnvironment, 
    _UUID             OemID,
    UPDATE_FLAGS_LIB  update_flags,
    void(*func)(float, float));

UINT32 FwUpdateCheckPowerSource(
    FWUPD_POWER_SOURCE* PowerState);

UINT32 FWUpdate_QueryStatus_Get_Response(
    UINT32* UpdateStatus,
    UINT32 *TotalStages,
    UINT32* PercentWritten,
    UINT32* LastUpdateStatus,
    UINT32* LastResetType);

UINT32 FwUpdateRestore(
    char*            ImageFile, 
    char*            _pwd,
    int              _forceResetLib,
    UINT32     UpdateEnvironment, 
    _UUID            OemID,
    UPDATE_FLAGS_LIB update_flags,
    void(*func)(float, float));

UINT32 FwUpdateFullBuffer(
    char*            buffer, 
    UINT32     bufferLength, 
    char*            _pwd,
    int              _forceResetLib,
    UINT32     UpdateEnvironment,    
    _UUID            OemID,
    UPDATE_FLAGS_LIB update_flags,
    void(*func)(float,float));

UINT32 FwUpdatePartialBuffer(
    char*             buffer,
    UINT32      bufferLength, 
    UINT32      PartitionID,
    UINT32      Flags, 
    IPU_UPDATED_INFO *IpuUpdatedInfo,
    char*             _pwd,
    UINT32      UpdateEnvironment, 
    _UUID             OemID,
    UPDATE_FLAGS_LIB  update_flags,
    void(*func)(float, float));

UINT32 FwUpdateRestoreBuffer(
    char*      buffer, 
    UINT32     bufferLength, 
    char*      _pwd,
    INT32      _forceResetLib,
    UINT32     UpdateEnvironment, 
    _UUID            OemID,
    UPDATE_FLAGS_LIB update_flags,
    void(*func)(float,float));
	
int GetPartVersion(UINT32 partID, UINT16 *major, UINT16 *minor, UINT16 *hotfix, UINT16 *build);


#ifdef __cplusplus
    }
#endif

#endif
