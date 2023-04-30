<#
  Script to pre-install drivers and Appx(s) in an offline Windows image.
  Based on my original CMD script but redone with a more reliable PowerShell runtime and commands (and cmdlets) in mind.
#>

#Requires -RunAsAdministrator
#Requires -Module Dism

Set-Location -Path $PSScriptRoot

function Get-TS { return "{0:HH:mm:ss}" -f [DateTime]::Now }

function Install-ProvisionedPackages([string] $MountPath, [string] $AppxType, [string[]] $JsonManifestPaths, [string] $BasePath = $PSScriptRoot) {
  foreach ($JsonManifestPath in $JsonManifestPaths) {
    $FullJsonManifestPath = Join-Path $BasePath $JsonManifestPath
    $JsonRawString = Get-Content $FullJsonManifestPath -Raw
    $Manifest = ConvertFrom-Json $JsonRawString

    $JsonManifestParentPath = Split-Path $FullJsonManifestPath -Parent

    $AppxPath = Join-Path $JsonManifestParentPath $Manifest.appx
    $LicensePath = Join-Path $JsonManifestParentPath $Manifest.license

    $Command = 'Add-AppxProvisionedPackage -Path "' + $MountPath + '" -PackagePath "' + $AppxPath + '"'
    if ( $Manifest.dependencies ) {
      $DependenciesPaths = ($Manifest.dependencies | ForEach-Object { '"' + $(Join-Path $JsonManifestParentPath $_) + '"' }) -join ','
      $Command += ' -DependencyPackagePath ' +  $DependenciesPaths
    }
    $Command += ' -LicensePath "' + $LicensePath + '" -Regions "all" -ErrorAction stop'

    Write-Output "$(Get-TS): Adding $AppxType package: $($Manifest.name)"
    Invoke-Expression $Command | Out-Null
  }
}

Write-Output "$(Get-TS): Starting media refresh tool (Windows offline image modification)"

# Declare install.wim index to modify
$WIM_INDEX          = 6

# Declare if modified WinOS install image should be ESD (if not, WIM with max compression)
# If final ESD or WIM image is greater than 4 GB, an splitted SWM image will be generated
$WINOS_ESD          = $False

# Declare folders for mounted images and temp files
$MEDIA_OLD_PATH     = "D:"
$MEDIA_NEW_PATH     = "E:"
$WORKING_PATH       = ".\temp"
$MEDIA_SETUP        = Join-Path $WORKING_PATH "MediaSetup"
$WINPE_MOUNT        = Join-Path $WORKING_PATH "WinPEMount"
$WINRE_MOUNT        = Join-Path $WORKING_PATH "WinREMount"
$WINOS_MOUNT        = Join-Path $WORKING_PATH "WinOSMount"

# Declare need to enable NetFx3 feature
$ENABLE_NETFX3      = $True

# Declare drivers list and images to be pre-installed
$SCCM_BASE_PATH     = ".\SCCM\"
$SCCM_WINPE         = $True
$SCCM_WINPE_LIST    = @(
  'AMD_Chipset\GPIO2\W11x64\amdgpio2.inf',
  'AMD_Chipset\I2C\W11x64\amdi2c.inf'
)
$SCCM_WINRE         = $True
$SCCM_WINRE_LIST    = @(
  'AMD_Chipset\GPIO2\W11x64\amdgpio2.inf',
  'AMD_Chipset\I2C\W11x64\amdi2c.inf'
)
$SCCM_WINOS         = $True
$SCCM_WINOS_LIST    = @(
  'Lenovo_ACPI\AcpiVpc.inf',
  'Lenovo_ITS\LNBITS.inf',
  'Lenovo_Fn_Keyboard\LenovoFnAndFunctionKeys.inf',
  'AMD_Chipset\GPIO2\W11x64\amdgpio2.inf',
  'AMD_Chipset\I2C\W11x64\amdi2c.inf',
  'AMD_Chipset\SMBus\W11x64\SMBUSamd.inf',
  'AMD_Chipset\PSP\W11x64\amdpsp.inf',
  'AMD_iGPU\Packages\Drivers\Display\WT6A_INF\U0374525.inf',
  'AMD_iGPU\Packages\Drivers\Display\WT6A_INF\UWPPair\UWPPair.inf',
  'AMD_iGPU\Packages\Drivers\Audio\HDMI\WT64A\AtihdWT6.inf',
  'AMD_iGPU\Packages\Drivers\Audio\ACPBus\WT64A\amdacpbus.inf',
  'Realtek_Audio\Dolby\ext_lenovo_AIO_rtk_20h1_21h2_v6.1119.359.1\dax3_ext_rtk.inf',
  'Realtek_Audio\Realtek\ExtRtk_9268.1\HDX_LenovoExt_DOLBY_Wrap_FORTE.inf',
  'Realtek_Audio\Realtek\Codec_9268.1\HDXACPLV.inf',
  'Realtek_Audio\Realtek\RealtekAPO_986\RealtekAPO.inf',
  'Realtek_Audio\Realtek\RealtekHSA_259\RealtekHSA.inf',
  'Realtek_Audio\Realtek\RealtekService_457\RealtekService.inf',
  'Realtek_Audio\Dolby\swc_factory\swc_aposvc_19h1_20h1_21h2_b14976_v3.30203.232.0\dax3_swc_aposvc.inf',
  'Realtek_Audio\Dolby\swc_factory\swc_hsa_rs5_19h1_20h1_21h2_b14302_v3.30201.210.0\dax3_swc_hsa.inf',
  'Realtek_Audio\Forte\Lenovo\OemXAudioExtFM_L.inf',
  'Realtek_Audio\Forte\FMHSAEXT_L\FMHSAExt_L.inf',
  'Realtek_Audio\Forte\FMHSA\FMHSA.inf',
  'Realtek_Audio\Forte\FMAPO\FMAPO.inf',
  'Realtek_WLAN\netrtwlane.inf',
  'Realtek_Bluetooth\Rtkfilter.inf',
  'Realtek_USB_GbE\rtu53cx22x64sta.inf',
  'BayHubTech_SDCardReader\bhtsddr.inf',
  'Azurewave_Camera\snDMFT.inf'
)

# Declare drivers' apps manifests list to be pre-installed
$HSA_BASE_PATH      = ".\HSA\"
$HSA_WINOS          = $True
$HSA_WINOS_LIST     = @(
  'AMDUI\manifest.json',
  'RealtekUI\manifest.json',
  'DolbyUI\manifest.json',
  'FortemediaUI\manifest.json'
)

# Declare MSStore apps manifests list to be pre-installed
$APPX_BASE_PATH     = ".\MSStore\"
$APPX_WINOS         = $True
$APPX_WINOS_LIST    = @(
  'LenovoVantage\manifest.json',
  'LenovoUtility\manifest.json'
)

# Optimize HSA and MSStore apps replacing identical files with hardlinks
$OPTIMIZE_APPX      = $True


# Check if at least one option is flagged as True
If ( -Not ( $ENABLE_NETFX3 -Or $SCCM_WINOS -Or $SCCM_WINPE -Or $SCCM_WINRE -Or $HSA_WINOS -Or $APPX_WINOS ) ) {
  Write-Output "$(Get-TS): No option selected. Exiting..."
  Exit 1
}

# Create folders for mounting images and storing temporary files
New-Item -ItemType directory -Path $WORKING_PATH -ErrorAction stop | Out-Null
New-Item -ItemType directory -Path $MEDIA_SETUP -ErrorAction stop | Out-Null
If ( $SCCM_WINPE ) { New-Item -ItemType directory -Path $WINPE_MOUNT -ErrorAction stop | Out-Null }
If ( $SCCM_WINRE ) { New-Item -ItemType directory -Path $WINRE_MOUNT -ErrorAction stop | Out-Null }
If ( $ENABLE_NETFX3 -Or $SCCM_WINRE -Or $SCCM_WINOS -Or $HSA_WINOS -Or $APPX_WINOS ) { New-Item -ItemType directory -Path $WINOS_MOUNT -ErrorAction stop | Out-Null }

# Copy Windows Media Setup from original media to temporary directory to work with
Write-Output "$(Get-TS): Copying original media setup to temporary directory"
# Robocopy.exe $MEDIA_OLD_PATH $MEDIA_SETUP /e /j /r:2 /w:5 | Out-Null
Copy-Item -Path $MEDIA_OLD_PATH"\*" -Destination $MEDIA_SETUP -Force -Recurse -ErrorAction stop | Out-Null
Get-ChildItem -Path $MEDIA_SETUP -Recurse | Where-Object { -Not $_.PSIsContainer -And $_.IsReadOnly } | ForEach-Object { $_.IsReadOnly = $False }

#########
# WinPE #
#########
If ( $SCCM_WINPE ) {
  Write-Output "$(Get-TS): Mounting Windows Preinstallation Environment (WinPE)"
  $WINPE_IMAGES = Get-WindowsImage -ImagePath $MEDIA_SETUP"\sources\boot.wim"

  Foreach ( $IMAGE in $WINPE_IMAGES ) {
    Write-Output "$(Get-TS): Mounting WinPE with Index: $($IMAGE.ImageIndex)"
    Mount-WindowsImage -ImagePath $MEDIA_SETUP"\sources\boot.wim" -Index $IMAGE.ImageIndex -Path $WINPE_MOUNT -CheckIntegrity -ErrorAction stop | Out-Null
    
    Foreach ( $DRIVER in $SCCM_WINPE_LIST ) {
      Write-Output "$(Get-TS): Adding driver: $DRIVER"
      Add-WindowsDriver -Path $WINPE_MOUNT -Driver $SCCM_BASE_PATH$DRIVER -ErrorAction stop | Out-Null
    }

    Dismount-WindowsImage -Path $WINPE_MOUNT -Save -CheckIntegrity -ErrorAction stop | Out-Null

    Write-Output "$(Get-TS): Exporting image to $WORKING_PATH\boot.wim"
    Export-WindowsImage -CompressionType max -SourceImagePath $MEDIA_SETUP"\sources\boot.wim" -SourceIndex $IMAGE.ImageIndex -DestinationImagePath $WORKING_PATH"\boot.wim" -CheckIntegrity -ErrorAction stop | Out-Null
  }

  Move-Item -Path $WORKING_PATH"\boot.wim" -Destination $MEDIA_SETUP"\sources\boot.wim" -Force -ErrorAction stop | Out-Null
}

#################
# WinOS & WinRE #
#################
If ( $ENABLE_NETFX3 -Or $SCCM_WINRE -Or $SCCM_WINOS -Or $HSA_WINOS -Or $APPX_WINOS ) {
  Write-Output "$(Get-TS): Mounting Windows Operating System (WinOS) with Index: $WIM_INDEX"
  Mount-WindowsImage -ImagePath $MEDIA_SETUP"\sources\install.wim" -Index $WIM_INDEX -Path $WINOS_MOUNT -ErrorAction stop | Out-Null

  If ( $SCCM_WINRE ) {
    Write-Output "$(Get-TS): Mounting Windows Recovery Environment (WinRE)"
    Mount-WindowsImage -ImagePath $WINOS_MOUNT"\windows\system32\recovery\winre.wim" -Index 1 -Path $WINRE_MOUNT -CheckIntegrity -ErrorAction stop | Out-Null

    Foreach ( $DRIVER in $SCCM_WINRE_LIST ) {
      Write-Output "$(Get-TS): Adding driver: $DRIVER"
      Add-WindowsDriver -Path $WINRE_MOUNT -Driver $SCCM_BASE_PATH$DRIVER -ErrorAction stop | Out-Null
    }

    Dismount-WindowsImage -Path $WINRE_MOUNT -Save -CheckIntegrity -ErrorAction stop | Out-Null

    Write-Output "$(Get-TS): Exporting image to $WORKING_PATH\winre.wim"
    Export-WindowsImage -CompressionType max -SourceImagePath $WINOS_MOUNT"\windows\system32\recovery\winre.wim" -SourceIndex 1 -DestinationImagePath $WORKING_PATH"\winre.wim" -CheckIntegrity -ErrorAction stop | Out-Null

    Move-Item -Path $WORKING_PATH"\winre.wim" -Destination $WINOS_MOUNT"\windows\system32\recovery\winre.wim" -Force -ErrorAction stop | Out-Null
  }

  If ( $ENABLE_NETFX3 ) {
    Write-Output "$(Get-TS): Adding feature: NetFx3~~~~"
    Add-WindowsCapability -Name "NetFx3~~~~" -Path $WINOS_MOUNT -Source $MEDIA_SETUP"\sources\sxs" -ErrorAction stop | Out-Null
  }

  If ( $SCCM_WINOS ) {
    Foreach ( $DRIVER in $SCCM_WINOS_LIST ) {
      Write-Output "$(Get-TS): Adding driver: $DRIVER"
      Add-WindowsDriver -Path $WINOS_MOUNT -Driver $SCCM_BASE_PATH$DRIVER -ErrorAction stop | Out-Null
    }
  }

  If ( $HSA_WINOS -Or $APPX_WINOS ) {      
    If ( $HSA_WINOS ) { Install-ProvisionedPackages $WINOS_MOUNT 'HSA' $HSA_WINOS_LIST $HSA_BASE_PATH }
    If ( $APPX_WINOS ) { Install-ProvisionedPackages $WINOS_MOUNT 'MSStore' $APPX_WINOS_LIST $APPX_BASE_PATH }

    If ( $OPTIMIZE_APPX ) {
    Write-Output "$(Get-TS): Optimizing provisioned Appx packages"
    Optimize-AppXProvisionedPackages -Path $WINOS_MOUNT -ErrorAction stop | Out-Null
    }
  }
  
  Dismount-WindowsImage -Path $WINOS_MOUNT -Save -CheckIntegrity -ErrorAction stop | Out-Null

  If ( $WINOS_ESD ) {
    Write-Output "$(Get-TS): Exporting image to $MEDIA_SETUP\sources\install.esd with recovery compression"
    # Export-WindowsImage -CompressionType recovery -SourceImagePath $MEDIA_SETUP"\sources\install.wim" -SourceIndex $WIM_INDEX -DestinationImagePath $MEDIA_SETUP"\sources\install.esd" -CheckIntegrity -ErrorAction stop | Out-Null
    DISM.exe /Export-Image /SourceImageFile:$MEDIA_SETUP"\sources\install.wim" /SourceIndex:$WIM_INDEX /DestinationImageFile:$MEDIA_SETUP"\sources\install.esd" /Compress:recovery /CheckIntegrity | Out-Null

    If ( (Get-Item $MEDIA_SETUP"\sources\install.esd").length -gt 4GB ) {
      Write-Output "$(Get-TS): Generated ESD file is bigger than 4GB, so splitted image is required for native EFI boot"

      Remove-Item -Path $MEDIA_SETUP"\sources\install.esd" -Force -ErrorAction stop | Out-Null
      $WINOS_ESD = $False
    
    } Else {
      Remove-Item -Path $MEDIA_SETUP"\sources\install.wim" -Force -ErrorAction stop | Out-Null
    }
  }
  
  If ( -Not $WINOS_ESD ) {
    Write-Output "$(Get-TS): Exporting image to $WORKING_PATH\install.wim with maximum compression"
    Export-WindowsImage -CompressionType max -SourceImagePath $MEDIA_SETUP"\sources\install.wim" -SourceIndex $WIM_INDEX -DestinationImagePath $WORKING_PATH"\install.wim" -CheckIntegrity -ErrorAction stop | Out-Null

    Move-Item -Path $WORKING_PATH"\install.wim" -Destination $MEDIA_SETUP"\sources\install.wim" -Force -ErrorAction stop | Out-Null

    If ( (Get-Item $MEDIA_SETUP"\sources\install.wim").length -gt 4GB ) {
      Write-Output "$(Get-TS): Generated WIM file is bigger than 4GB, so splitted image is required for native EFI boot"

      Write-Output "$(Get-TS): Splitting image to $MEDIA_SETUP\sources\install.swm in 4GB chunks"
      Split-WindowsImage -ImagePath $MEDIA_SETUP"\sources\install.wim" -SplitImagePath $MEDIA_SETUP"\sources\install.swm" -FileSize 4000 -CheckIntegrity -ErrorAction stop | Out-Null

      Remove-Item -Path $MEDIA_SETUP"\sources\install.wim" -Force -ErrorAction stop | Out-Null  
    }
  
  }
}

Write-Output "$(Get-TS): Copying modified media setup to new directory"
# Robocopy.exe $MEDIA_SETUP $MEDIA_NEW_PATH /e /j /r:2 /w:5 | Out-Null
Copy-Item -Path $MEDIA_SETUP"\*" -Destination $MEDIA_NEW_PATH -Force -Recurse -ErrorAction stop | Out-Null

Write-Output "$(Get-TS): Cleaning-up temporary directory"
Remove-Item -Path $WORKING_PATH -Recurse -Force -ErrorAction stop | Out-Null

Write-Output "$(Get-TS): Media refresh with pre-installed drivers and Appx(s) completed!"
