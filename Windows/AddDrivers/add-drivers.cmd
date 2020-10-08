:: Avoid command output.
@echo off

:: Needed for "IsLarger" function.
:: Can be activated when calling it, but I don't care.
setlocal enableextensions
setlocal enabledelayedexpansion



:Variables
    :: Not needed but I feel safer.
    setlocal

    :: Exit with code 0
    set _OK=0

    :: Exit with code 1
    set _NOK=1

    :: QUOTED path to DISM. It's possible to specify path to ADK's DISM like:
    :: C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe
    :: More info about Sysnative: https://www.samlogic.net/articles/sysnative-folder-64-bit-windows.htm
    set DISM="C:\Windows\System32\Dism.exe"

    :: UNQUOTED path to MOUNTED MSDN Windows 10 ISO file (install.wim not install.esd or alternatives). I'll try to change this in the future.
    set ISO=E:

    :: UNQUOTED path to USB (or another directory) where to copy modified ISO files.
    set USB=F:

    :: Index (QUOTED or UNQUOTED) or name (QUOTED and this must be exactly the same, character by character) of the desired Windows 10 version.
    :: You should previously take inventory of your Windows 10 image to know the exact index or name with the following command:
    :: %DISM% /Get-ImageInfo /ImageFile:%ISO%\sources\install.wim
    set EDITION="Windows 10 Pro"

    :: UNQUOTED and must be "Name" or "Index" depending on the given EDITION variable.
    set ED_TYPE=Name

    :: Allowed max file size of install.esd (in bytes) - intended for devices using FAT32 file system to boot as a pure UEFI device (NTFS uses UEFI-CSM so not pure).
    :: 4,294,967,296 bytes equals to 4 GiB, the same as 4096 MiB.
    :: The reason I need two variables with the same value but different multiples is because CMD uses 32-bit signed integer, so 2,147,483,647 is the max value.
    :: With that said, it's pretty inaccurate to make truncations, and also impossible to divide and/or multiply by 2^10. It's also possible to use external
    :: scripts as with Visual Basic but I don't really care because this is a test and I'm gonna end up making a new script but in PowerShell as should be.
    :: UNQUOTED.
    set B_SIZE=4294967296
    set MiB_SIZE=4096

    :: Clean-Up after script execution. Greater than 0 means TRUE, otherwise FALSE.
    :: UNQUOTED.
    set /a CLEAN_UP=0

    :: Clean-Up target directory. Greater than 0 means TRUE, otherwise FALSE.
    :: WARNING! This will remove hidden directories/files too - incl. "System Volume Information" (if the given %USB% path is the root path of a device)
    :: which is has no consequences for a bootable USB device but yes for those which uses "Restore Points". The same applies for "$Recycle.Bin" folder and similar.
    :: UNQUOTED.
    set /a TARGET_CLEAN_UP=0



:Inizialization
    :: Like 'cd /d "%~dp0"' but being able to nest directories and pop-out to previous ones.
    pushd "%~dp0"

    :: Just to be sure "Drivers\list.txt" is present and all drivers are available (only INF file is checked, not content neither architecture).
    :: It's possible to skip this verification, but if it's not present, we'll have lost a lot of time mounting and unmounting the Windows image.
    if not exist "Drivers\list.txt" goto :ByeBye _NOK
    for /f "delims=" %%i in ( Drivers\list.txt ) do ( if not exist "Drivers\%%i" goto :ByeBye _NOK )
    call :FileCleanUp



:Main
    :: Copy install.wim to local directory.
    echo.
    echo copy "%ISO%\sources\install.wim" .
    copy "%ISO%\sources\install.wim" . || goto :ByeBye _NOK

    :: Directory in which we'll be working in.
    mkdir offline >nul 2>&1 || goto :ByeBye _NOK
    echo.
    echo Dism /Mount-Image /ImageFile:install.wim /%ED_TYPE%:%EDITION% /MountDir:offline /CheckIntegrity
    %DISM% /Mount-Image /ImageFile:install.wim /%ED_TYPE%:%EDITION% /MountDir:offline /CheckIntegrity /English || goto :UnmountAndByeBye _NOK

    :: Enable .NET Framework 2.0 and 3.5 to avoid possible errors due to drivers that may depend on them (mainly older ones).
    :: Check if "dir" finds "netfx3" base package (not language package). It's expected to be the same architecture (don't be a fool).
    dir /a:-d /b "%ISO%\sources\sxs\microsoft-windows-netfx3-ondemand-package~31bf3856ad364e35~*~~.cab" >nul 2>&1
    :: !ERRORLEVEL! is 0 when matching, otherwise 1.
    if !ERRORLEVEL! equ 0 (
        echo.
        echo Dism /Image:offline /Enable-Feature /FeatureName:NetFx3 /All /LimitAccess /Source:"%ISO%\sources\sxs"
        %DISM% /Image:offline /Enable-Feature /FeatureName:NetFx3 /All /LimitAccess /Source:"%ISO%\sources\sxs" /English || goto :UnmountAndByeBye _NOK
    ) else (
        :: I don't like doing it online (Windows Update/WSUS) with an offline image, but ok, let's have a fallback.
        :: REMEMBER: this isn't a MSDN Windows 10 ISO file.
        echo.
        echo Dism /Image:offline /Enable-Feature /FeatureName:NetFx3 /All
        %DISM% /Image:offline /Enable-Feature /FeatureName:NetFx3 /All /English || goto :UnmountAndByeBye _NOK
    )

    :: For loop to add drivers from "Drivers\list.txt".
    :: Drivers must be placed inside "%~dp0\Drivers" folder and INF paths must be relative to that folder (e.g. "Intel_VGA\iigd_dch.inf").
    for /f "delims=" %%i in ( Drivers\list.txt ) do (
        echo.
        echo Dism /Image:offline /Add-Driver /Driver:"Drivers\%%i"
        %DISM% /Image:offline /Add-Driver /Driver:"Drivers\%%i" /English || goto :UnmountAndByeBye _NOK
    )

    :: List all 3rd-party drivers installed to be checked by the user.
    echo.
    echo Dism /Image:offline /Get-Drivers ^> drivers-list.txt
    %DISM% /Image:offline /Get-Drivers /English >drivers-list.txt 2>&1 || goto :UnmountAndByeBye _NOK

    :: Unmount & export as an ESD file to significantly reduce file size (less than 4 GiB is expected).
    echo.
    echo Dism /Unmount-Image /MountDir:offline /Commit /CheckIntegrity
    %DISM% /Unmount-Image /MountDir:offline /Commit /CheckIntegrity /English || goto :UnmountAndByeBye _NOK
    echo.
    echo Dism /Export-Image /SourceImageFile:install.wim /Source%ED_TYPE%:%EDITION% /DestinationImageFile:install.esd /Compress:recovery /CheckIntegrity
    %DISM% /Export-Image /SourceImageFile:install.wim /Source%ED_TYPE%:%EDITION% /DestinationImageFile:install.esd /Compress:recovery /CheckIntegrity /English || goto :ByeBye _NOK

    :: Clean-Up target directory, if desired.
    if %TARGET_CLEAN_UP% gtr 0 ( call :TargetCleanUp )

    :: Copy all ISO files except "install.wim" to then copy generated "install.esd" if possible.
    :: In robocopy is possible to set file size limit but it isn't because it's not expected files bigger than file system limit.
    :: /is /it /im are intended to copy files in destiniation even if are present (modified or not). We also exclude hidden files and known system directories.
    :: Failed copies aren't retried and also a log is dumped to current working directory in "robocopy-log.txt".
    echo.
    echo robocopy "%ISO%" "%USB%" /e /is /it /im /xf "install.wim" /xd "System Volume Information" "$*" ".*" /xa:h /mir /w:0 /r:0 /np /tee /unilog:"robocopy-log.txt"
    robocopy "%ISO%" "%USB%" /e /is /it /im /xf "install.wim" /xd "System Volume Information" "$*" ".*" /xa:h /mir /w:0 /r:0 /np /tee /unilog:"robocopy-log.txt"
    if !ERRORLEVEL! geq 8 goto :ByeBye _NOK
    :: If using MOUNTED and UNTOUCHED MSDN Windows 10 ISO, it's enough by using robocopy with the following parameters (but let's use the previous one as a fallback):
    :: ;:robocopy "%ISO%" "%USB%" /e /is /it /im /xf "install.wim" /w:0 /r:0 /np /tee /unilog:"robocopy-log.txt" (ERRORLEVEL condition must be executed too).
    :: The only drawback I found (apart from system folders) is if "install.wim" is present on destination, even with /mir option, it's not deleted on destination.
    :: This is something shouldn't happen because destination should be clean, but because it's an option, let's check if it's present, and if so, delete it.
    if exist "%USB%\sources\install.wim" ( del /f /q "%USB%\sources\install.wim" >nul 2>&1 || goto :ByeBye _NOK )
    :: This is an alternative with xcopy, however, exclude doesn't support quotes (""), so if a path has spaces, it's non-viable unless you specify short-path.
    :: The good thing about xcopy is it excludes hidden and system files/directories by default, something that it's not possible with robocopy (I don't understand why).
    :: ;:xcopy "%ISO%" "%USB%" /i /s /e /exclude:%ISO%\sources\install.wim /y

    :: Check for file size and then split image if needed.
    for %%f in ( install.esd ) do ( set _file_size=%%~zf || goto :ByeBye _NOK )
    call :IsLarger _file_size B_SIZE _result

    if "!_result!" == "true" (
        echo.
        echo Dism /Export-Image /SourceImageFile:install.wim /Source%ED_TYPE%:%EDITION% /DestinationImageFile:exported.wim /Compress:max /CheckIntegrity
        %DISM% /Export-Image /SourceImageFile:install.wim /Source%ED_TYPE%:%EDITION% /DestinationImageFile:exported.wim /Compress:max /CheckIntegrity /English || goto :ByeBye _NOK
        echo.
        echo Dism /Split-Image /ImageFile:exported.wim /SWMFile:install.swm /FileSize:%MiB_SIZE% /CheckIntegrity
        %DISM% /Split-Image /ImageFile:exported.wim /SWMFile:install.swm /FileSize:%MiB_SIZE% /CheckIntegrity /English || goto :ByeBye _NOK
        echo.
        echo copy install*.swm "%USB%\sources\."
        copy install*.swm "%USB%\sources\." || goto :ByeBye _NOK
    ) else (
        echo.
        echo copy install.esd "%USB%\sources\."
        copy install.esd "%USB%\sources\." || goto :ByeBye _NOK
    )

    goto :ByeBye _OK



:IsLarger
    ::DETERMINE IF FIRST VAR IS LARGER THAN SECOND
    ::NUMBERS OF UP TO ~4000 DIGITS CAN BE COMPARED, NO MORE THAN ~8100 DIGITS COMBINED
    ::SYNTAX: CALL ISLARGER _VAR1 _VAR2 _VAR3
    ::hieyeque1@gmail.com - drop me a note telling me
    ::if this has helped you.  Sometimes I don't know if anyone uses my stuff
    ::Its free for the world to use.
    ::I retain the rights to it though, you may not copyright this
    ::to prevent others from using it, you may however copyright works
    ::as a whole that use this code.
    ::Just don't try to stop others from using this through some legal means.
    ::CopyRight Brian Williams 5/18/2009
    :: _VAR1 = VARIABLE AGAINST WHICH WE SHALL COMPARE
    :: _VAR2 = VARIABLE TO BE COMPARED
    :: _VAR3 = VARIABLE WITH TRUE/FALSE RETURNED
    set _num1=!%1!
    set _num2=!%2!
    set _result=%3
    for /l %%a in (1,1,2) do (
        for /l %%b in (0,1,9) do (
            set _num%%a=!_num%%a:%%b=%%b !
        )
    )
    for %%a in (!_num1!) do set /a _num1cnt+=1 & set _!_num1cnt!_num1=%%a
    for %%a in (!_num2!) do set /a _num2cnt+=1 & set _!_num2cnt!_num2=%%a
    if !_num1cnt! neq !_num2cnt! (
        if !_num1cnt! gtr !_num2cnt! (
            set !_result!=true
            goto :eof
        ) else (
            set !_result!=false
            goto :eof
        )
    )
    for /l %%a in (1,1,!_num1cnt!) do (
        if !_%%a_num1! neq !_%%a_num2! (
            if !_%%a_num1! gtr !_%%a_num2! (
                set !_result!=true
                goto :eof
            ) else (
                set !_result!=false
                goto :eof
            )
        )
    )
    set !_result!=equal
    goto :eof



:FileCleanUp
    echo.
    echo Working directory clean-up in progress...
    del /f /q exported.wim >nul 2>&1
    del /f /q install*.swm >nul 2>&1
    del /f /q install.wim >nul 2>&1
    del /f /q install.esd >nul 2>&1
    del /f /s /q offline >nul 2>&1
    rmdir /s /q offline >nul 2>&1
    if exist "exported.wim" goto :DeeperByeBye _NOK
    if exist "install.wim" goto :DeeperByeBye _NOK
    if exist "install.wim" goto :DeeperByeBye _NOK
    if exist "install.esd" goto :DeeperByeBye _NOK
    if exist "offline" goto :DeeperByeBye _NOK
    echo.
    echo Working directory clean-up successfully completed.
    goto :eof



:TargetCleanUp
    echo.
    echo Destination clean-up in progress...
    del /f /s /q "%USB%" >nul 2>&1
    rmdir /s /q "%USB%" >nul 2>&1
    :: If file(s) were successfully listed: %ERRORLEVEL% = 0. But we need no files listed (remember, we're deleting), so ByeBye.
    dir /a /b "%USB%" >nul 2>&1 && goto :ByeBye _NOK
    echo.
    echo Destination clean-up successfully completed.
    goto :eof



:UnmountAndByeBye
    echo Dism /Unmount-Image /MountDir:offline /Discard
    %DISM% /Unmount-Image /MountDir:offline /Discard /English
    goto :ByeBye !%1!



:ByeBye
    if %CLEAN_UP% gtr 0 call :FileCleanUp
    goto :DeeperByeBye !%1!



:DeeperByeBye
    popd
    endlocal
    echo Exit with code !%1!
    pause
    exit /b !%1!
