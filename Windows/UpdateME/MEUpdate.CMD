@ECHO OFF

CLS

echo Updating the ME Firmware...
echo.

IF "%PROCESSOR_ARCHITECTURE%"=="x86" GOTO 32bit

:64bit
%~dp0FWUpdLcl64.exe -F %~dp0ME_11.8_Consumer_D0_H_Production.bin -OEMID 00000000-0000-0000-0000-000000000000 -generic -allowsv
GOTO RESTART

:32bit
%~dp0FWUpdLcl.exe -F %~dp0ME_11.8_Consumer_D0_H_Production.bin -OEMID 00000000-0000-0000-0000-000000000000 -generic -allowsv
GOTO RESTART

:RESTART
del %~dp0NULL
Shutdown.exe -r -t 10

:END
