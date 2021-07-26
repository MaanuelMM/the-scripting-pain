@ECHO OFF

SET ReturnCode=0

reg Query "HKLM\Hardware\Description\System\CentralProcessor\0" | find /i "x86" > NUL && set OS=x86 || set OS=x64

CLS

echo Updating the ME Firmware...
echo.


IF %OS%==x86 GOTO 32bit

:64bit
"%~dp0FWUpdLcl64.exe" -F "%~dp0ME_11.8_Consumer_D0_H_Production.bin" -OEMID 00000000-0000-0000-0000-000000000000 -generic -allowsv -y
SET ReturnCode=%errorlevel%
GOTO RESTART

:32bit
"%~dp0FWUpdLcl.exe" -F "%~dp0ME_11.8_Consumer_D0_H_Production.bin" -OEMID 00000000-0000-0000-0000-000000000000 -generic -allowsv -y
SET ReturnCode=%errorlevel%
GOTO RESTART


:RESTART

IF [%1]==[] Shutdown.exe -r -t 10 && exit /b %ReturnCode%

exit /b %ReturnCode%

:END