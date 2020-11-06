#Requires -RunAsAdministrator

Set-Location -Path $PSScriptRoot

function Get-TS { return "{0:HH:mm:ss}" -f [DateTime]::Now }

Write-Output "$(Get-TS): Starting media refresh"

# Declare language for showcasing adding optional localized components
$LANG  = "ja-jp"
$LANG_FONT_CAPABILITY = "jpan"

# Declare media for FOD and LPs
$FOD_ISO_PATH    = ".\mediaRefresh\packages\FOD-PACKAGES_OEM_PT1_amd64fre_MULTI.iso"
$LP_ISO_PATH     = ".\mediaRefresh\packages\CLIENTLANGPACKDVD_OEM_MULTI.iso"

# Declare Dynamic Update packages
$LCU_PATH        = ".\mediaRefresh\packages\LCU.msu"
$SSU_PATH        = ".\mediaRefresh\packages\SSU_DU.msu"
$SETUP_DU_PATH   = ".\mediaRefresh\packages\Setup_DU.cab"
$SAFE_OS_DU_PATH = ".\mediaRefresh\packages\SafeOS_DU.cab"
$DOTNET_CU_PATH  = ".\mediaRefresh\packages\DotNet_CU.msu"

# Declare folders for mounted images and temp files
$MEDIA_OLD_PATH  = ".\mediaRefresh\oldMedia"
$MEDIA_NEW_PATH  = ".\mediaRefresh\newMedia"
$WORKING_PATH    = ".\mediaRefresh\temp"
$MAIN_OS_MOUNT   = ".\mediaRefresh\temp\MainOSMount"
$WINRE_MOUNT     = ".\mediaRefresh\temp\WinREMount"
$WINPE_MOUNT     = ".\mediaRefresh\temp\WinPEMount"

# Mount the language pack ISO
Write-Output "$(Get-TS): Mounting LP ISO"
$LP_ISO_DRIVE_LETTER = (Mount-DiskImage -ImagePath $LP_ISO_PATH -ErrorAction stop | Get-Volume).DriveLetter

# Declare language related cabs
$WINPE_OC_PATH              = "$LP_ISO_DRIVE_LETTER`:\Windows Preinstallation Environment\x64\WinPE_OCs"
$WINPE_OC_LANG_PATH         = "$WINPE_OC_PATH\$LANG"
$WINPE_OC_LANG_CABS         = Get-ChildItem $WINPE_OC_LANG_PATH -Name
$WINPE_OC_LP_PATH           = "$WINPE_OC_LANG_PATH\lp.cab"
$WINPE_FONT_SUPPORT_PATH    = "$WINPE_OC_PATH\WinPE-FontSupport-$LANG.cab"
$WINPE_SPEECH_TTS_PATH      = "$WINPE_OC_PATH\WinPE-Speech-TTS.cab"
$WINPE_SPEECH_TTS_LANG_PATH = "$WINPE_OC_PATH\WinPE-Speech-TTS-$LANG.cab"
$OS_LP_PATH                 = "$LP_ISO_DRIVE_LETTER`:\x64\langpacks\Microsoft-Windows-Client-Language-Pack_x64_$LANG.cab"

# Mount the Features on Demand ISO
Write-Output "$(Get-TS): Mounting FOD ISO"
$FOD_ISO_DRIVE_LETTER = (Mount-DiskImage -ImagePath $FOD_ISO_PATH -ErrorAction stop | Get-Volume).DriveLetter
$FOD_PATH = $FOD_ISO_DRIVE_LETTER + ":\"

# Create folders for mounting images and storing temporary files
New-Item -ItemType directory -Path $WORKING_PATH -ErrorAction Stop | Out-Null
New-Item -ItemType directory -Path $MAIN_OS_MOUNT -ErrorAction stop | Out-Null
New-Item -ItemType directory -Path $WINRE_MOUNT -ErrorAction stop | Out-Null
New-Item -ItemType directory -Path $WINPE_MOUNT -ErrorAction stop | Out-Null

# Keep the original media, make a copy of it for the new, updated media.
Write-Output "$(Get-TS): Copying original media to new media path"
Copy-Item -Path $MEDIA_OLD_PATH"\*" -Destination $MEDIA_NEW_PATH -Force -Recurse -ErrorAction stop | Out-Null
Get-ChildItem -Path $MEDIA_NEW_PATH -Recurse | Where-Object { -not $_.PSIsContainer -and $_.IsReadOnly } | ForEach-Object { $_.IsReadOnly = $false }

# Mount the main operating system, used throughout the script
Write-Output "$(Get-TS): Mounting main OS"
Mount-WindowsImage -ImagePath $MEDIA_NEW_PATH"\sources\install.wim" -Index 1 -Path $MAIN_OS_MOUNT -ErrorAction stop| Out-Null  

#
# update Windows Recovery Environment (WinRE)
#
Copy-Item -Path $MAIN_OS_MOUNT"\windows\system32\recovery\winre.wim" -Destination $WORKING_PATH"\winre.wim" -Force -Recurse -ErrorAction stop | Out-Null
Write-Output "$(Get-TS): Mounting WinRE"
Mount-WindowsImage -ImagePath $WORKING_PATH"\winre.wim" -Index 1 -Path $WINRE_MOUNT -ErrorAction stop | Out-Null

# Add servicing stack update
Write-Output "$(Get-TS): Adding package $SSU_PATH"
Add-WindowsPackage -Path $WINRE_MOUNT -PackagePath $SSU_PATH -ErrorAction stop | Out-Null  

#
# Optional: Add the language to recovery environment
#
# Install lp.cab cab
Write-Output "$(Get-TS): Adding package $WINPE_OC_LP_PATH"
Add-WindowsPackage -Path $WINRE_MOUNT -PackagePath $WINPE_OC_LP_PATH -ErrorAction stop | Out-Null  

# Install language cabs for each optional package installed
$WINRE_INSTALLED_OC = Get-WindowsPackage -Path $WINRE_MOUNT
Foreach ($PACKAGE in $WINRE_INSTALLED_OC) {

    if ( ($PACKAGE.PackageState -eq "Installed") `
            -and ($PACKAGE.PackageName.startsWith("WinPE-")) `
            -and ($PACKAGE.ReleaseType -eq "FeaturePack") ) {

        $INDEX = $PACKAGE.PackageName.IndexOf("-Package")
        if ($INDEX -ge 0) {
            $OC_CAB = $PACKAGE.PackageName.Substring(0, $INDEX) + "_" + $LANG + ".cab"
            if ($WINPE_OC_LANG_CABS.Contains($OC_CAB)) {
                $OC_CAB_PATH = Join-Path $WINPE_OC_LANG_PATH $OC_CAB
                Write-Output "$(Get-TS): Adding package $OC_CAB_PATH"
                Add-WindowsPackage -Path $WINRE_MOUNT -PackagePath $OC_CAB_PATH -ErrorAction stop | Out-Null  
            }
        }
    }
}

# Add font support for the new language
if ( (Test-Path -Path $WINPE_FONT_SUPPORT_PATH) ) {
    Write-Output "$(Get-TS): Adding package $WINPE_FONT_SUPPORT_PATH"
    Add-WindowsPackage -Path $WINRE_MOUNT -PackagePath $WINPE_FONT_SUPPORT_PATH -ErrorAction stop | Out-Null
}

# Add TTS support for the new language
if (Test-Path -Path $WINPE_SPEECH_TTS_PATH) {
    if ( (Test-Path -Path $WINPE_SPEECH_TTS_LANG_PATH) ) {

        Write-Output "$(Get-TS): Adding package $WINPE_SPEECH_TTS_PATH"
        Add-WindowsPackage -Path $WINRE_MOUNT -PackagePath $WINPE_SPEECH_TTS_PATH -ErrorAction stop | Out-Null

        Write-Output "$(Get-TS): Adding package $WINPE_SPEECH_TTS_LANG_PATH"
        Add-WindowsPackage -Path $WINRE_MOUNT -PackagePath $WINPE_SPEECH_TTS_LANG_PATH -ErrorAction stop | Out-Null
    }
}

# Add Safe OS
Write-Output "$(Get-TS): Adding package $SAFE_OS_DU_PATH"
Add-WindowsPackage -Path $WINRE_MOUNT -PackagePath $SAFE_OS_DU_PATH -ErrorAction stop | Out-Null

# Perform image cleanup
Write-Output "$(Get-TS): Performing image cleanup on WinRE"
DISM /image:$WINRE_MOUNT /cleanup-image /StartComponentCleanup | Out-Null

# Dismount
Dismount-WindowsImage -Path $WINRE_MOUNT  -Save -ErrorAction stop | Out-Null

# Export
Write-Output "$(Get-TS): Exporting image to $WORKING_PATH\winre2.wim"
Export-WindowsImage -SourceImagePath $WORKING_PATH"\winre.wim" -SourceIndex 1 -DestinationImagePath $WORKING_PATH"\winre2.wim" -ErrorAction stop | Out-Null
Move-Item -Path $WORKING_PATH"\winre2.wim" -Destination $WORKING_PATH"\winre.wim" -Force -ErrorAction stop | Out-Null

#
# update Windows Preinstallation Environment (WinPE)
#

# Get the list of images contained within WinPE
$WINPE_IMAGES = Get-WindowsImage -ImagePath $MEDIA_NEW_PATH"\sources\boot.wim"

Foreach ($IMAGE in $WINPE_IMAGES) {

    # update WinPE
    Write-Output "$(Get-TS): Mounting WinPE"
    Mount-WindowsImage -ImagePath $MEDIA_NEW_PATH"\sources\boot.wim" -Index $IMAGE.ImageIndex -Path $WINPE_MOUNT -ErrorAction stop | Out-Null  

    # Add SSU
    Write-Output "$(Get-TS): Adding package $SSU_PATH"
    Add-WindowsPackage -Path $WINPE_MOUNT -PackagePath $SSU_PATH -ErrorAction stop | Out-Null

    # Install lp.cab cab
    Write-Output "$(Get-TS): Adding package $WINPE_OC_LP_PATH"
    Add-WindowsPackage -Path $WINPE_MOUNT -PackagePath $WINPE_OC_LP_PATH -ErrorAction stop | Out-Null  

    # Install language cabs for each optional package installed
    $WINPE_INSTALLED_OC = Get-WindowsPackage -Path $WINPE_MOUNT
    Foreach ($PACKAGE in $WINPE_INSTALLED_OC) {

        if ( ($PACKAGE.PackageState -eq "Installed") `
                -and ($PACKAGE.PackageName.startsWith("WinPE-")) `
                -and ($PACKAGE.ReleaseType -eq "FeaturePack") ) {

            $INDEX = $PACKAGE.PackageName.IndexOf("-Package")
            if ($INDEX -ge 0) {

                $OC_CAB = $PACKAGE.PackageName.Substring(0, $INDEX) + "_" + $LANG + ".cab"
                if ($WINPE_OC_LANG_CABS.Contains($OC_CAB)) {
                    $OC_CAB_PATH = Join-Path $WINPE_OC_LANG_PATH $OC_CAB
                    Write-Output "$(Get-TS): Adding package $OC_CAB_PATH"
                    Add-WindowsPackage -Path $WINPE_MOUNT -PackagePath $OC_CAB_PATH -ErrorAction stop | Out-Null  
                }
            }
        }
    }

    # Add font support for the new language
    if ( (Test-Path -Path $WINPE_FONT_SUPPORT_PATH) ) {
        Write-Output "$(Get-TS): Adding package $WINPE_FONT_SUPPORT_PATH"
        Add-WindowsPackage -Path $WINPE_MOUNT -PackagePath $WINPE_FONT_SUPPORT_PATH -ErrorAction stop | Out-Null
    }

    # Add TTS support for the new language
    if (Test-Path -Path $WINPE_SPEECH_TTS_PATH) {
        if ( (Test-Path -Path $WINPE_SPEECH_TTS_LANG_PATH) ) {

            Write-Output "$(Get-TS): Adding package $WINPE_SPEECH_TTS_PATH"
            Add-WindowsPackage -Path $WINPE_MOUNT -PackagePath $WINPE_SPEECH_TTS_PATH -ErrorAction stop | Out-Null

            Write-Output "$(Get-TS): Adding package $WINPE_SPEECH_TTS_LANG_PATH"
            Add-WindowsPackage -Path $WINPE_MOUNT -PackagePath $WINPE_SPEECH_TTS_LANG_PATH -ErrorAction stop | Out-Null
        }
    }

    # Generates a new Lang.ini file which is used to define the language packs inside the image
    if ( (Test-Path -Path $WINPE_MOUNT"\sources\lang.ini") ) {
        Write-Output "$(Get-TS): Updating lang.ini"
        DISM /image:$WINPE_MOUNT /Gen-LangINI /distribution:$WINPE_MOUNT | Out-Null
    }

    # Add latest cumulative update
    Write-Output "$(Get-TS): Adding package $LCU_PATH"
    Add-WindowsPackage -Path $WINPE_MOUNT -PackagePath $LCU_PATH -ErrorAction stop | Out-Null  

    # Perform image cleanup
    Write-Output "$(Get-TS): Performing image cleanup on WinPE"
    DISM /image:$WINPE_MOUNT /cleanup-image /StartComponentCleanup | Out-Null

    # Dismount
    Dismount-WindowsImage -Path $WINPE_MOUNT -Save -ErrorAction stop | Out-Null

    #Export WinPE
    Write-Output "$(Get-TS): Exporting image to $WORKING_PATH\boot2.wim"
    Export-WindowsImage -SourceImagePath $MEDIA_NEW_PATH"\sources\boot.wim" -SourceIndex $IMAGE.ImageIndex -DestinationImagePath $WORKING_PATH"\boot2.wim" -ErrorAction stop | Out-Null

}

Move-Item -Path $WORKING_PATH"\boot2.wim" -Destination $MEDIA_NEW_PATH"\sources\boot.wim" -Force -ErrorAction stop | Out-Null

#
# update Main OS
#

# Add servicing stack update
Write-Output "$(Get-TS): Adding package $SSU_PATH"
Add-WindowsPackage -Path $MAIN_OS_MOUNT -PackagePath $SSU_PATH -ErrorAction stop | Out-Null

# Optional: Add language to main OS
Write-Output "$(Get-TS): Adding package $OS_LP_PATH"
Add-WindowsPackage -Path $MAIN_OS_MOUNT -PackagePath $OS_LP_PATH -ErrorAction stop | Out-Null  

# Optional: Add a Features on Demand to the image
Write-Output "$(Get-TS): Adding language FOD: Language.Fonts.Jpan~~~und-JPAN~0.0.1.0"
Add-WindowsCapability -Name "Language.Fonts.$LANG_FONT_CAPABILITY~~~und-$LANG_FONT_CAPABILITY~0.0.1.0" -Path $MAIN_OS_MOUNT -Source $FOD_PATH -ErrorAction stop | Out-Null

Write-Output "$(Get-TS): Adding language FOD: Language.Basic~~~$LANG~0.0.1.0"
Add-WindowsCapability -Name "Language.Basic~~~$LANG~0.0.1.0" -Path $MAIN_OS_MOUNT -Source $FOD_PATH -ErrorAction stop | Out-Null

Write-Output "$(Get-TS): Adding language FOD: Language.OCR~~~$LANG~0.0.1.0"
Add-WindowsCapability -Name "Language.OCR~~~$LANG~0.0.1.0" -Path $MAIN_OS_MOUNT -Source $FOD_PATH -ErrorAction stop | Out-Null

Write-Output "$(Get-TS): Adding language FOD: Language.Handwriting~~~$LANG~0.0.1.0"
Add-WindowsCapability -Name "Language.Handwriting~~~$LANG~0.0.1.0" -Path $MAIN_OS_MOUNT -Source $FOD_PATH -ErrorAction stop | Out-Null

Write-Output "$(Get-TS): Adding language FOD: Language.TextToSpeech~~~$LANG~0.0.1.0"
Add-WindowsCapability -Name "Language.TextToSpeech~~~$LANG~0.0.1.0" -Path $MAIN_OS_MOUNT -Source $FOD_PATH -ErrorAction stop | Out-Null

Write-Output "$(Get-TS): Adding language FOD:Language.Speech~~~$LANG~0.0.1.0"
Add-WindowsCapability -Name "Language.Speech~~~$LANG~0.0.1.0" -Path $MAIN_OS_MOUNT -Source $FOD_PATH -ErrorAction stop | Out-Null

# Note: If I wanted to enable additional Features on Demand, I'd add these here.

# Add latest cumulative update
Write-Output "$(Get-TS): Adding package $LCU_PATH"
Add-WindowsPackage -Path $MAIN_OS_MOUNT -PackagePath $LCU_PATH -ErrorAction stop | Out-Null

# Copy our updated recovery image from earlier into the main OS
# Note: If I were updating more than 1 edition, I'd want to copy the same recovery image file
# into each edition to enable single instancing
Copy-Item -Path $WORKING_PATH"\winre.wim" -Destination $MAIN_OS_MOUNT"\windows\system32\recovery\winre.wim" -Force -Recurse -ErrorAction stop | Out-Null

# Perform image cleanup
Write-Output "$(Get-TS): Performing image cleanup on main OS"
DISM /image:$MAIN_OS_MOUNT /cleanup-image /StartComponentCleanup | Out-Null

#
# Note: If I wanted to enable additional Optional Components, I'd add these here.
# In addition, we'll add .NET 3.5 here as well. Both .NET and Optional Components might require
# the image to be booted, and thus if we tried to cleanup after installation, it would fail.
#

Write-Output "$(Get-TS): Adding NetFX3~~~~"
Add-WindowsCapability -Name "NetFX3~~~~" -Path $MAIN_OS_MOUNT -Source $FOD_PATH -ErrorAction stop | Out-Null

# Add .NET Cumulative Update
Write-Output "$(Get-TS): Adding package $DOTNET_CU_PATH"
Add-WindowsPackage -Path $MAIN_OS_MOUNT -PackagePath $DOTNET_CU_PATH -ErrorAction stop | Out-Null

# Dismount
Dismount-WindowsImage -Path $MAIN_OS_MOUNT -Save -ErrorAction stop | Out-Null

# Export
Write-Output "$(Get-TS): Exporting image to $WORKING_PATH\install2.wim"
Export-WindowsImage -SourceImagePath $MEDIA_NEW_PATH"\sources\install.wim" -SourceIndex 1 -DestinationImagePath $WORKING_PATH"\install2.wim" -ErrorAction stop | Out-Null
Move-Item -Path $WORKING_PATH"\install2.wim" -Destination $MEDIA_NEW_PATH"\sources\install.wim" -Force -ErrorAction stop | Out-Null

#
# update remaining files on media
#

# Add Setup DU by copy the files from the package into the newMedia
Write-Output "$(Get-TS): Adding package $SETUP_DU_PATH"
cmd.exe /c $env:SystemRoot\System32\expand.exe $SETUP_DU_PATH -F:* $MEDIA_NEW_PATH"\sources" | Out-Null

#
# Perform final cleanup
#

# Remove our working folder
Remove-Item -Path $WORKING_PATH -Recurse -Force -ErrorAction stop | Out-Null

# Dismount ISO images
Write-Output "$(Get-TS): Dismounting ISO images"
Dismount-DiskImage -ImagePath $LP_ISO_PATH -ErrorAction stop | Out-Null
Dismount-DiskImage -ImagePath $FOD_ISO_PATH -ErrorAction stop | Out-Null

Write-Output "$(Get-TS): Media refresh completed!"