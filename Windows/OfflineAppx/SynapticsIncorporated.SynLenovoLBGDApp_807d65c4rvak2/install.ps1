<#
    Install script for Synaptics MetroApp to use with Synaptics declarative driver.
    Authors:      MaanuelMM
    Created:      2022/09/23
    Last update:  2022/09/24
#>

# Should be: 'C:\Drivers\Synaptics_Touchpad'
$CurrentPath = Split-Path ($MyInvocation.MyCommand.Path) # $PSScriptRoot 

# Synaptics TouchPad version (must be modified depending on app/driver version)
$SynTPVer = "v19005.10153.0.0"
# MetroApp file path (may no need to be modified)
$AppxPath = "$CurrentPath\Install\SynLenovoLBGDApp_${SynTPVer}_x64.appx"
# Temporal directory path (shouldn't be modified)
$TempPath = "$CurrentPath\Temp"
# Certificate file path (shouldn't be modified)
$CertPath = "$TempPath\SynLenovoLBGDApp.cer"

# Temporal directory creation
If ($TempPath) { Remove-Item -Path $TempPath -Recurse -Force -ErrorAction Stop | Out-Null }
New-Item -ItemType Directory -Path $TempPath -ErrorAction Stop | Out-Null

# Extracting and exporting signer certificate from $AppxPath into $CertPath
Get-AuthenticodeSignature $AppxPath -ErrorAction Stop | Select-Object -ExpandProperty SignerCertificate -ErrorAction Stop | Export-Certificate -Type CERT -FilePath $CertPath -ErrorAction Stop | Out-Null
# Importing certificate into \LocalMachine\TrustedPeople Cert Store
Import-Certificate -FilePath $CertPath -CertStoreLocation Cert:\LocalMachine\TrustedPeople -ErrorAction Stop | Out-Null

# Provisioning MetroApp into online Windows image (skipping license)
Add-ProvisionedAppPackage -Online -PackagePath $AppxPath -SkipLicense -Regions all -ErrorAction Stop | Out-Null

# Clean-up temporal directory
Remove-Item -Path $TempPath -Recurse -Force -ErrorAction Stop | Out-Null