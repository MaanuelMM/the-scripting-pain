<#
  Update Windows 10 media with Dynamic Update Powershell script.
  
  Latest and untouched version available on the Microsoft Docs website:
  https://docs.microsoft.com/en-us/windows/deployment/update/media-dynamic-update
  
  Modified by me to meet my requirements.
#>

#Requires -RunAsAdministrator
#Requires -Module Dism

Set-Location -Path $PSScriptRoot

function Get-TS { return "{0:HH:mm:ss}" -f [DateTime]::Now }

Write-Output "$(Get-TS): Starting media refresh"

# Declare install.wim index to be refreshed
$WIM_INDEX       = 1

# Declare Dynamic Update packages
$LCU_PATH        = ".\mediaRefresh\packages\LCU"
$SSU_PATH        = ".\mediaRefresh\packages\SSU_DU"
$SETUP_DU_PATH   = ".\mediaRefresh\packages\Setup_DU"
$SAFE_OS_DU_PATH = ".\mediaRefresh\packages\SafeOS_DU"
$DOTNET_CU_PATH  = ".\mediaRefresh\packages\DotNet_CU"
$FLASH_CU_PATH   = ".\mediaRefresh\packages\Flash_CU"

# Declare folders for mounted images and temp files
$MEDIA_OLD_PATH  = ".\mediaRefresh\oldMedia"
$MEDIA_NEW_PATH  = ".\mediaRefresh\newMedia"
$WORKING_PATH    = ".\mediaRefresh\temp"
$MAIN_OS_MOUNT   = ".\mediaRefresh\temp\MainOSMount"
$WINRE_MOUNT     = ".\mediaRefresh\temp\WinREMount"
$WINPE_MOUNT     = ".\mediaRefresh\temp\WinPEMount"

# Create folders for mounting images and storing temporary files
New-Item -ItemType directory -Path $WORKING_PATH -ErrorAction stop | Out-Null
New-Item -ItemType directory -Path $MAIN_OS_MOUNT -ErrorAction stop | Out-Null
New-Item -ItemType directory -Path $WINRE_MOUNT -ErrorAction stop | Out-Null
New-Item -ItemType directory -Path $WINPE_MOUNT -ErrorAction stop | Out-Null

# Keep the original media, make a copy of it for the new, updated media.
Write-Output "$(Get-TS): Copying original media to new media path"
Copy-Item -Path $MEDIA_OLD_PATH"\*" -Destination $MEDIA_NEW_PATH -Force -Recurse -ErrorAction stop | Out-Null
Get-ChildItem -Path $MEDIA_NEW_PATH -Recurse | Where-Object { -not $_.PSIsContainer -and $_.IsReadOnly } | ForEach-Object { $_.IsReadOnly = $false }

# Mount the main operating system, used throughout the script
Write-Output "$(Get-TS): Mounting main OS"
Mount-WindowsImage -ImagePath $MEDIA_NEW_PATH"\sources\install.wim" -Index $WIM_INDEX -Path $MAIN_OS_MOUNT -ErrorAction stop | Out-Null

#
# Update Windows Recovery Environment (WinRE)
#
Copy-Item -Path $MAIN_OS_MOUNT"\windows\system32\recovery\winre.wim" -Destination $WORKING_PATH"\winre.wim" -Force -Recurse -ErrorAction stop | Out-Null
Write-Output "$(Get-TS): Mounting WinRE"
Mount-WindowsImage -ImagePath $WORKING_PATH"\winre.wim" -Index 1 -Path $WINRE_MOUNT -ErrorAction stop | Out-Null

Get-ChildItem $SSU_PATH -File | Sort-Object -Property Name | ForEach-Object {
    # Add servicing stack update
    Write-Output "$(Get-TS): Adding package $_"
    Add-WindowsPackage -Path $WINRE_MOUNT -PackagePath $_.FullName -ErrorAction stop | Out-Null
}

Get-ChildItem $SAFE_OS_DU_PATH -File | Sort-Object -Property Name | ForEach-Object {
    # Add Safe OS
    Write-Output "$(Get-TS): Adding package $_"
    Add-WindowsPackage -Path $WINRE_MOUNT -PackagePath $_.FullName -ErrorAction stop | Out-Null
}

# Perform image cleanup
Write-Output "$(Get-TS): Performing image cleanup on WinRE"
DISM /image:$WINRE_MOUNT /cleanup-image /StartComponentCleanup | Out-Null

# Dismount
Dismount-WindowsImage -Path $WINRE_MOUNT -Save -ErrorAction stop | Out-Null

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

    # Update WinPE
    Write-Output "$(Get-TS): Mounting WinPE"
    Mount-WindowsImage -ImagePath $MEDIA_NEW_PATH"\sources\boot.wim" -Index $IMAGE.ImageIndex -Path $WINPE_MOUNT -ErrorAction stop | Out-Null

    Get-ChildItem $SSU_PATH -File | Sort-Object -Property Name | ForEach-Object {
        # Add SSU
        Write-Output "$(Get-TS): Adding package $_"
        Add-WindowsPackage -Path $WINPE_MOUNT -PackagePath $_.FullName -ErrorAction stop | Out-Null
    }

    Get-ChildItem $LCU_PATH -File | Sort-Object -Property Name | ForEach-Object {
        # Add latest cumulative update
        Write-Output "$(Get-TS): Adding package $_"
        Add-WindowsPackage -Path $WINPE_MOUNT -PackagePath $_.FullName -ErrorAction stop | Out-Null
    }
    
    # Perform image cleanup
    Write-Output "$(Get-TS): Performing image cleanup on WinPE"
    DISM /image:$WINPE_MOUNT /cleanup-image /StartComponentCleanup | Out-Null

    # Dismount
    Dismount-WindowsImage -Path $WINPE_MOUNT -Save -ErrorAction stop | Out-Null

    # Export WinPE
    Write-Output "$(Get-TS): Exporting image to $WORKING_PATH\boot2.wim"
    Export-WindowsImage -SourceImagePath $MEDIA_NEW_PATH"\sources\boot.wim" -SourceIndex $IMAGE.ImageIndex -DestinationImagePath $WORKING_PATH"\boot2.wim" -ErrorAction stop | Out-Null

}

Move-Item -Path $WORKING_PATH"\boot2.wim" -Destination $MEDIA_NEW_PATH"\sources\boot.wim" -Force -ErrorAction stop | Out-Null

#
# Update Main OS
#

# Add .NET 3.5 optional component
Write-Output "$(Get-TS): Adding NetFX3~~~~"
Add-WindowsCapability -Name "NetFX3~~~~" -Path $MAIN_OS_MOUNT -Source $MEDIA_NEW_PATH"\sources\sxs" -ErrorAction stop | Out-Null

Get-ChildItem $SSU_PATH -File | Sort-Object -Property Name | ForEach-Object {
    # Add servicing stack update
    Write-Output "$(Get-TS): Adding package $_"
    Add-WindowsPackage -Path $MAIN_OS_MOUNT -PackagePath $_.FullName -ErrorAction stop | Out-Null
}

Get-ChildItem $LCU_PATH -File | Sort-Object -Property Name | ForEach-Object {
    # Add latest cumulative update
    Write-Output "$(Get-TS): Adding package $_"
    Add-WindowsPackage -Path $MAIN_OS_MOUNT -PackagePath $_.FullName -ErrorAction stop | Out-Null
}

Get-ChildItem $DOTNET_CU_PATH -File | Sort-Object -Property Name | ForEach-Object {
    # Add .NET cumulative update
    Write-Output "$(Get-TS): Adding package $_"
    Add-WindowsPackage -Path $MAIN_OS_MOUNT -PackagePath $_.FullName -ErrorAction stop | Out-Null
}

Get-ChildItem $FLASH_CU_PATH -File | Sort-Object -Property Name | ForEach-Object {
    # Add Flash Player cumulative update
    Write-Output "$(Get-TS): Adding package $_"
    Add-WindowsPackage -Path $MAIN_OS_MOUNT -PackagePath $_.FullName -ErrorAction stop | Out-Null
}

# Copy our updated recovery image from earlier into the main OS
# Note: If I were updating more than 1 edition, I'd want to copy the same recovery image file
# into each edition to enable single instancing
Copy-Item -Path $WORKING_PATH"\winre.wim" -Destination $MAIN_OS_MOUNT"\windows\system32\recovery\winre.wim" -Force -Recurse -ErrorAction stop | Out-Null

# Perform image cleanup
Write-Output "$(Get-TS): Performing image cleanup on main OS"
DISM /image:$MAIN_OS_MOUNT /cleanup-image /StartComponentCleanup | Out-Null

# Dismount
Dismount-WindowsImage -Path $MAIN_OS_MOUNT -Save -ErrorAction stop | Out-Null

# Export
Write-Output "$(Get-TS): Exporting image to $WORKING_PATH\install2.wim"
Export-WindowsImage -SourceImagePath $MEDIA_NEW_PATH"\sources\install.wim" -SourceIndex 1 -DestinationImagePath $WORKING_PATH"\install2.wim" -ErrorAction stop | Out-Null
Move-Item -Path $WORKING_PATH"\install2.wim" -Destination $MEDIA_NEW_PATH"\sources\install.wim" -Force -ErrorAction stop | Out-Null

#
# Update remaining files on media
#

Get-ChildItem $SETUP_DU_PATH -File | Sort-Object -Property Name | ForEach-Object {
    # Add Setup DU by copy the files from the package into the newMedia
    Write-Output "$(Get-TS): Adding package $_"
    cmd.exe /c $env:SystemRoot\System32\expand.exe $_.FullName -F:* $MEDIA_NEW_PATH"\sources" | Out-Null
}

#
# Perform final cleanup
#

# Remove our working folder
Remove-Item -Path $WORKING_PATH -Recurse -Force -ErrorAction stop | Out-Null

Write-Output "$(Get-TS): Media refresh completed!"