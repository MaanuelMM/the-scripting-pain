<#
  Script to pre-install drivers in an offline Windows image.
  Based on my original CMD script but redone with a more reliable PowerShell runtime and commands in mind.
#>

#Requires -RunAsAdministrator
#Requires -Module Dism

Set-Location -Path $PSScriptRoot

function Get-TS { return "{0:HH:mm:ss}" -f [DateTime]::Now }

Write-Output "$(Get-TS): Starting drivers pre-installation"

# Declare install.wim index to pre-install drivers
$WIM_INDEX          = 1

# Declare folders for mounted images and temp files
$MEDIA_OLD_PATH     = "E:"
$MEDIA_NEW_PATH     = "F:"
$WORKING_PATH       = ".\temp"
$MEDIA_SETUP        = ".\temp\MediaSetup"
$WINOS_MOUNT        = ".\temp\WinOSMount"
$WINRE_MOUNT        = ".\temp\WinREMount"
$WINPE_MOUNT        = ".\temp\WinPEMount"

# Declare need to enable NetFx3 feature
$ENABLE_NETFX3      = $True

# Declare drivers list and images to be pre-installed
$SCCM_BASE_PATH     = ".\Drivers\"
$SCCM_WINOS         = $True
$SCCM_WINOS_LIST    = @('Lenovo_ACPI\AcpiVpc.inf', 'Intel_GPIO2\iaLPSS2_GPIO2_SKL.inf', 'Intel_ME\HECI_REL\win10\heci.inf', 'Intel_ME\DAL_DCH_REL\DAL.inf', 'Intel_ME\ICLS_DCH\iclsClient.inf', 'Intel_Chipset\KabylakeSystem.inf', 'Intel_Chipset\SkylakeSystem.inf', 'Intel_Chipset\SunrisePoint-HSystem.inf', 'Intel_Chipset\SunrisePoint-HSystemThermal.inf', 'Intel_RST\AHCI\iaAHCIC.inf', 'Samsung_NVMe\secnvme.inf', 'Realtek_Audio\HDXLVE.inf', 'Realtek_PCIe_GbE\rt640x64.inf', 'Realtek_USB_GbE\rtux64w10sta.inf', 'Intel_WiFi\Netwtw08.inf', 'Intel_Bluetooth\ibtusb.inf', 'Intel_VGA\iigd_dch.inf', 'Nvidia_VGA\nvlti.inf', 'Synaptics_Touchpad\SynPD.inf', 'BayHubTech_SDCardReader\bhtpcrdr.inf', 'Realtek_EasyCamera\RtLeShA.inf')
$SCCM_WINPE         = $False
$SCCM_WINPE_LIST    = @()
$SCCM_WINRE         = $False
$SCCM_WINRE_LIST    = @()

# Check if at least one SCCM is flagged as True
If ( -Not ($SCCM_WINOS -Or $SCCM_WINPE -Or $SCCM_WINRE ) ) {
  Write-Output "$(Get-TS): No image selected. Exiting..."
  Exit 1
}

# Create folders for mounting images and storing temporary files
New-Item -ItemType directory -Path $WORKING_PATH -ErrorAction stop | Out-Null
New-Item -ItemType directory -Path $MEDIA_SETUP -ErrorAction stop | Out-Null
If ($SCCM_WINOS) { New-Item -ItemType directory -Path $WINOS_MOUNT -ErrorAction stop | Out-Null }
If ($SCCM_WINPE) { New-Item -ItemType directory -Path $WINPE_MOUNT -ErrorAction stop | Out-Null }
If ($SCCM_WINRE) { New-Item -ItemType directory -Path $WINRE_MOUNT -ErrorAction stop | Out-Null }

# Copy Windows Media Setup from original media to temporary directory to work with
Write-Output "$(Get-TS): Copying original media setup to temporary directory"
Copy-Item -Path $MEDIA_OLD_PATH"\*" -Destination $MEDIA_SETUP -Force -Recurse -ErrorAction stop | Out-Null
# Get-ChildItem -Path $MEDIA_SETUP -Recurse | Where-Object { -Not $_.PSIsContainer -And $_.IsReadOnly } | ForEach-Object { $_.IsReadOnly = $False }

#########
# WinPE #
#########
If ($SCCM_WINPE) {
  Write-Output "$(Get-TS): Mounting Windows Preinstallation Environment (WinPE)"
  $WINPE_IMAGES = Get-WindowsImage -ImagePath $MEDIA_SETUP"\sources\boot.wim"

  Foreach ($IMAGE in $WINPE_IMAGES) {
    Write-Output "$(Get-TS): Mounting WinPE with Index: $($IMAGE.ImageIndex)"
    Mount-WindowsImage -ImagePath $MEDIA_SETUP"\sources\boot.wim" -Index $IMAGE.ImageIndex -Path $WINPE_MOUNT -CheckIntegrity -ErrorAction stop | Out-Null
    
    Foreach ($DRIVER in $SCCM_WINPE_LIST) {
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
If ( $SCCM_WINOS -Or $SCCM_WINRE ) {
  Write-Output "$(Get-TS): Mounting Windows Operating System (WinOS) with Index: $WIM_INDEX"
  Mount-WindowsImage -ImagePath $MEDIA_SETUP"\sources\install.wim" -Index $WIM_INDEX -Path $WINOS_MOUNT -ErrorAction stop | Out-Null

  If ( $SCCM_WINRE ) {
    Write-Output "$(Get-TS): Mounting Windows Recovery Environment (WinRE)"
    Mount-WindowsImage -ImagePath $WINOS_MOUNT"\windows\system32\recovery\winre.wim" -Index 1 -Path $WINRE_MOUNT -CheckIntegrity -ErrorAction stop | Out-Null

    Foreach ($DRIVER in $SCCM_WINRE_LIST) {
      Write-Output "$(Get-TS): Adding driver: $DRIVER"
      Add-WindowsDriver -Path $WINRE_MOUNT -Driver $SCCM_BASE_PATH$DRIVER -ErrorAction stop | Out-Null
    }

    Dismount-WindowsImage -Path $WINRE_MOUNT -Save -CheckIntegrity -ErrorAction stop | Out-Null

    Write-Output "$(Get-TS): Exporting image to $WORKING_PATH\winre.wim"
    Export-WindowsImage -CompressionType max -SourceImagePath $WINOS_MOUNT"\windows\system32\recovery\winre.wim" -SourceIndex 1 -DestinationImagePath $WORKING_PATH"\winre.wim" -CheckIntegrity -ErrorAction stop | Out-Null

    Move-Item -Path $WORKING_PATH"\winre.wim" -Destination $WINOS_MOUNT"\windows\system32\recovery\winre.wim" -Force -ErrorAction stop | Out-Null
  }

  If ( $SCCM_WINOS ) {
    If ( $ENABLE_NETFX3 ) {
      Write-Output "$(Get-TS): Adding NetFx3~~~~"
      Add-WindowsCapability -Name "NetFx3~~~~" -Path $WINOS_MOUNT -Source $MEDIA_SETUP"\sources\sxs" -ErrorAction stop | Out-Null
    }

    Foreach ($DRIVER in $SCCM_WINOS_LIST) {
      Write-Output "$(Get-TS): Adding driver: $DRIVER"
      Add-WindowsDriver -Path $WINOS_MOUNT -Driver $SCCM_BASE_PATH$DRIVER -ErrorAction stop | Out-Null
    }
  }
  
  Dismount-WindowsImage -Path $WINOS_MOUNT -Save -CheckIntegrity -ErrorAction stop | Out-Null

  Write-Output "$(Get-TS): Exporting image to $MEDIA_SETUP\sources\install.esd with recovery compression"
  Export-WindowsImage -CompressionType recovery -SourceImagePath $MEDIA_SETUP"\sources\install.wim" -SourceIndex $WIM_INDEX -DestinationImagePath $MEDIA_SETUP"\sources\install.esd" -CheckIntegrity -ErrorAction stop | Out-Null
  
  If ( [int]((Get-File $MEDIA_SETUP"\sources\install.esd").length) -gt 4GB ) {
    Write-Output "$(Get-TS): Generated ESD file is bigger than 4GB, so splitted image is required"

    Remove-Item -Path $MEDIA_SETUP"\sources\install.esd" -Force -ErrorAction stop | Out-Null
    
    Write-Output "$(Get-TS): Exporting image to $WORKING_PATH\install.wim with maximum compression"
    Export-WindowsImage -CompressionType max -SourceImagePath $MEDIA_SETUP"\sources\install.wim" -SourceIndex $WIM_INDEX -DestinationImagePath $WORKING_PATH"\install.wim" -CheckIntegrity -ErrorAction stop | Out-Null
    
    Write-Output "$(Get-TS): Splitting image to $MEDIA_SETUP\sources\install.swm in 4GB chunks"
    Split-WindowsImage -ImagePath $WORKING_PATH"\install.wim" -SplitImagePath $MEDIA_SETUP"\sources\install.swm" -FileSize 4096 -CheckIntegrity -ErrorAction stop | Out-Null
    
    Remove-Item -Path $WORKING_PATH"\install.wim" -Force -ErrorAction stop | Out-Null
  }

  Remove-Item -Path $MEDIA_SETUP"\sources\install.wim" -Force -ErrorAction stop | Out-Null
}

Write-Output "$(Get-TS): Copying modified media setup to new directory"
Copy-Item -Path $MEDIA_SETUP"\*" -Destination $MEDIA_NEW_PATH -Force -Recurse -ErrorAction stop | Out-Null

Write-Output "$(Get-TS): Cleaning-up temporary directory"
Remove-Item -Path $WORKING_PATH -Recurse -Force -ErrorAction stop | Out-Null

Write-Output "$(Get-TS): Media refresh with pre-installed drivers completed!"
