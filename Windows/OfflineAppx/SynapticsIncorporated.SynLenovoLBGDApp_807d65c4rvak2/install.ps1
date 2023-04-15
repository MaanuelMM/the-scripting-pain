<#
    Install script for Synaptics MetroApp to use with Synaptics declarative driver.
    Authors:      MaanuelMM
    Created:      2022/09/23
    Last update:  2023/04/15
#>
#Requires -RunAsAdministrator
#Requires -Module Dism

Set-Location -Path $PSScriptRoot

# Synaptics TouchPad version (must be modified depending on app/driver version)
$SynTPVer = "v19005.10153.0.0"
# MetroApp file path (may no need to be modified)
$AppxPath = ".\Install\SynLenovoLBGDApp_${SynTPVer}_x64.appx"

# Extracting and exporting signer certificate from $AppxPath into $Cert variable
# Note that a file can have several signatures and this solution is intended for files with only one signature
$Cert = (Get-AuthenticodeSignature $AppxPath -ErrorAction Stop).SignerCertificate

# Creating new CertStore object to open TrustedPeople certificate store in the LocalMachine location
$CertStore = Get-Item Cert:\LocalMachine\TrustedPeople

# Opening with R/W permissions, adding certificate into \LocalMachine\TrustedPeople Cert Store and closing the object
$CertStore.Open("ReadWrite")
$CertStore.Add($Cert)
$CertStore.Close()

# Provisioning MetroApp into online Windows image (skipping license)
Add-ProvisionedAppPackage -Online -PackagePath $AppxPath -SkipLicense -Regions all -ErrorAction Stop | Out-Null
