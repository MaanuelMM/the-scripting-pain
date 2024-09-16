# Based on original script written by the "Microsoft Secure Boot Team" (https://www.powershellgallery.com/packages/SplitDbxContent/1.0)
# Optimized by me based on "cjee21" script (https://github.com/cjee21/Check-UEFISecureBootVariables/blob/main/Get-UEFIDatabaseSignatures.ps1)

function Split-DbxAuthInfo {

<#
.DESCRIPTION
 Splits a DBX update package into the new DBX variable contents and the signature authorizing the change.
 To apply an update using the output files of this script, try:
 Set-SecureBootUefi -Name dbx -ContentFilePath .\content.bin -SignedFilePath .\signature.p7 -Time 2010-03-06T19:17:21Z -AppendWrite'
.EXAMPLE
Split-DbxAuthInfo DbxUpdate_x64.bin
#>

    # Get file from script input
    $Bytes = Get-Content -Encoding Byte $args[0]

    # Identify file signature
    if (($Bytes[40] -ne 0x30) -or ($Bytes[41] -ne 0x82 )) {
        Write-Error "Cannot find signature!" -ErrorAction Stop
    }

    # Signature is known to be ASN size plus header of 4 bytes
    $sig_length = $Bytes[42] * 256 + $Bytes[43] + 4
    if ($sig_length -gt ($Bytes.Length + 40)) {
        Write-Error "Signature longer than file size!" -ErrorAction Stop
    }

    # Build and write signature output file
    Set-Content -Encoding Byte -Path ".\signature.p7" -Value ([Byte[]] $Bytes[40..($sig_length + 40 - 1)]) -ErrorAction Stop
    Write-Output "Successfully created output file .\signature.p7"

    # Build and write variable content output file
    Set-Content -Encoding Byte -Path ".\content.bin" -Value ([Byte[]] $Bytes[($sig_length + 40)..($Bytes.Length - 1)]) -ErrorAction Stop
    Write-Output "Successfully created output file .\content.bin"
    
}
