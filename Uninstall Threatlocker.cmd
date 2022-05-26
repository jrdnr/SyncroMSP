@ECHO OFF

IF EXIST "%PROGRAMFILES(X86)%" (GOTO 64BIT) ELSE (GOTO 32BIT)
:64BIT
%@Try%
curl "https://api.threatlocker.com/updates/installers/threatlockerstubx64.exe" -o "C:\ThreatLockerStub.exe"
%@EndTry%
:@Catch
bitsadmin /transfer mydownloadjob /download /priority normal "https://api.threatlocker.com/updates/installers/threatlockerstubx64.exe" "c:\ThreatLockerStub.exe"
:@EndCatch
GOTO UNINSTALL

:32BIT
%@Try%
curl "https://api.threatlocker.com/updates/installers/threatlockerstubx86.exe" -o "C:\ThreatLockerStub.exe"
%@EndTry%
:@Catch
bitsadmin /transfer mydownloadjob /download /priority normal "https://api.threatlocker.com/updates/installers/threatlockerstubx86.exe" "c:\ThreatLockerStub.exe"
:@EndCatch
GOTO UNINSTALL

:UNINSTALL
C:\ThreatLockerStub.exe uninstall
GOTO VERIFYINSTALL

:VERIFYINSTALL
FOR /F "tokens=3 delims=: " %%F IN ('sc query "ThreatLockerService" ^| findstr "        STATE"') DO (
    IF /I "%%F" neq "RUNNING" (
		GOTO SUCCESS
	) ELSE (
		GOTO FAILED
	)
)

:SUCCESS
echo "ThreatLocker uninstalled successfully"
IF EXIST "C:\ThreatLockerStub.exe" (DEL "C:\ThreatLockerStub.exe")
EXIT /b 0

:FAILED
echo "ThreatLocker failed to uninstall"
IF EXIST "C:\ThreatLockerStub.exe" (DEL "C:\ThreatLockerStub.exe")
EXIT /b 1
