#Requires -RunAsAdministrator
#Requires -Module Dism

Set-Location -Path $PSScriptRoot

function Get-TS { return "{0:HH:mm:ss}" -f [DateTime]::Now }

function Invoke-SilentWebRequest([string]$Uri, [string]$OutFile) {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $Uri -OutFile $OutFile
    $ProgressPreference = 'Continue'
}

function Invoke-Oscdimg([string]$OscdimgPath, [string]$Architecture, [string]$SourceRoot, [string]$TargetFile) {
    $command = '"' + $OscdimgPath + '" -bootdata:'
    
    if ($Architecture -eq "ARM64") { $command += '1#pEF,e,b"' + $SourceRoot + '\efi\Microsoft\boot\efisys.bin"' }
    else { $command += '2#p0,e,b"' + $SourceRoot + '\boot\etfsboot.com"#pEF,e,b"' + $SourceRoot + '\efi\Microsoft\boot\efisys.bin"' }

    $command += ' -o -h -m -u2 -udfver102 -lESD-ISO ' + $SourceRoot + ' ' + $TargetFile

    Invoke-Expression "cmd.exe /c $command"
}

Write-Output "$(Get-TS): Starting ESD to ISO creation tool"

$WORKING_PATH   = ".\temp"

$ADK_PATH       = "C:\Program Files (x86)\Windows Kits\10"
$HOST_ARCH      = $env:PROCESSOR_ARCHITECTURE.ToLower()
$OSCDIMG_PATH   = Join-Path $ADK_PATH -ChildPath "\Assessment and Deployment Kit\Deployment Tools\" | Join-Path -ChildPath $HOST_ARCH | Join-Path -ChildPath "\Oscdimg\oscdimg.exe"

$LANG_CODE      = "es-es"
$EDITION        = "Professional"
$ARCHITECTURE   = "ARM64"

# Windows 10   -> 0
# Windows 11   -> 1
$PRODUCT        = 1

$PRODUCTS_LIST  = @(
    "https://go.microsoft.com/fwlink/?LinkId=841361",
    "https://go.microsoft.com/fwlink/?LinkId=2156292"
)

if (Test-Path $OSCDIMG_PATH) {
    
    if (Test-Path $WORKING_PATH) { Remove-Item -Path $WORKING_PATH -Recurse -Force -ErrorAction Stop | Out-Null }
    New-Item -ItemType directory -Path $WORKING_PATH -ErrorAction stop | Out-Null

    Write-Output "$(Get-TS): Downloading products.cab"
    $products_cab_path = Join-Path $WORKING_PATH "products.cab"
    Invoke-SilentWebRequest -Uri $PRODUCTS_LIST[$PRODUCT] -OutFile $products_cab_path

    Write-Output "$(Get-TS): Expanding products.cab into products.xml"
    $products_xml_path = Join-Path $WORKING_PATH "products.xml"
    expand.exe $products_cab_path -F:products.xml $products_xml_path | Out-Null

    [xml]$xml = Get-Content $products_xml_path

    $file = $xml.MCT.Catalogs.Catalog.PublishedMedia.Files.ChildNodes | Where-Object {
        $_.LanguageCode -eq $LANG_CODE -and $_.Edition -eq $EDITION -and $_.Architecture -eq $ARCHITECTURE
    } | Select-Object -First 1  # the selection of the first occurrence should not be necessary because there should only be one occurrence, but who knows

    if ($file) {
        
        Write-Output "$(Get-TS): Match found for language `"$($LANG_CODE)`", edition `"$($EDITION)`" and architecture `"$($ARCHITECTURE)`""

        $filename = Split-Path $file.FilePath -Leaf
        $file_path = Join-Path $WORKING_PATH $filename

        Write-Output "$(Get-TS): Downloading $($filename)"
        Invoke-SilentWebRequest -Uri $file.FilePath -OutFile $file_path
        
        Write-Output "$(Get-TS): Comparing SHA1 hash from downloaded ESD file with products.xml"
        $filehash_xml = $file.Sha1
        $filehash_esd = (Get-FileHash -Path $file_path -Algorithm SHA1).Hash
        
        if ($filehash_xml.ToLower() -eq $filehash_esd.ToLower()) {
            
            Write-Output "$(Get-TS): SHA1 hash from downloaded ESD file matches with products.xml"

            $setup_media = Join-Path $WORKING_PATH "\ISOFOLDER"
            New-Item -ItemType directory -Path $setup_media -ErrorAction stop | Out-Null

            $boot_wim = Join-Path $setup_media "\sources\boot.wim"
            $install_esd = Join-Path $setup_media "\sources\install.esd"
            
            $images = Get-WindowsImage -ImagePath $file_path
            
            foreach ( $image in $images ) {
                if ( $image.ImageIndex -eq 1 ) {
                    Write-Output "$(Get-TS): Expanding $($image.ImageName) into $($setup_media)"
                    Expand-WindowsImage -ImagePath $file_path -Index $image.ImageIndex -ApplyPath $setup_media -CheckIntegrity -ErrorAction Stop | Out-Null
                }
                elseif ( $image.ImageIndex -eq 2 -or $image.ImageIndex -eq 3 ) {
                    Write-Output "$(Get-TS): Exporting $($image.ImageName) into $($boot_wim)"
                    Export-WindowsImage -SourceImagePath $file_path -SourceIndex $image.ImageIndex -DestinationImagePath $boot_wim -CompressionType max -CheckIntegrity -ErrorAction Stop | Out-Null
                }
                else {
                    Write-Output "$(Get-TS): Exporting $($image.ImageName) into $($install_esd)"
                    $dism_export = 'Dism.exe /Export-Image /SourceImageFile:"' + $file_path + '" /SourceIndex:' + $image.ImageIndex + ' /DestinationImageFile:"' + $install_esd + '" /Compress:recovery /CheckIntegrity'
                    Invoke-Expression "cmd /c $dism_export" | Out-Null
                }
            }
            
            Write-Output "$(Get-TS): Generating ISO file"
            $iso_name = (Get-Item $file_path).BaseName + ".iso"
            Invoke-Oscdimg -OscdimgPath $OSCDIMG_PATH -Architecture $ARCHITECTURE -SourceRoot $setup_media -TargetFile $iso_name
            
            Write-Output "$(Get-TS): ISO file generated correctly. Cleaning-up and exiting..."
            Remove-Item -Path $WORKING_PATH -Recurse -Force -ErrorAction Stop | Out-Null
            Exit 0
        }

        else {
            Write-Output "$(Get-TS): SHA1 hash from downloaded ESD file does not match with products.xml. Cleaning-up and exiting..."
            Remove-Item -Path $WORKING_PATH -Recurse -Force -ErrorAction Stop | Out-Null
            Exit 1
        }

    }

    else {
        Write-Output "$(Get-TS): No matches found for language `"$($LANG_CODE)`", edition `"$($EDITION)`" and architecture `"$($ARCHITECTURE)`". Cleaning-up and exiting..."
        Remove-Item -Path $WORKING_PATH -Recurse -Force -ErrorAction Stop | Out-Null
        Exit 1
    }

}

else {
    Write-Output "$(Get-TS): Oscdimg.exe given path does not exist. Exiting..."
    Exit 1
}