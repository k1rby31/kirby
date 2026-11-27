@echo off
setlocal
cd /d "%~dp0"
call :check_files
if errorlevel 1 (
    if /i not "%~1"=="--check" pause
    exit /b 1
)
if /i "%~1"=="--check" (
    echo Launcher files are present.
    exit /b 0
)

rem ---- shrink the log text: DPIs scale console fonts up, the logs then wrap ----
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0debug\Console-Scale.ps1" >nul 2>&1

rem ---- admin required: the driver and the game both need it ----
net session >nul 2>&1
if not "%errorlevel%"=="0" (
    set "RR_LAUNCHER_PATH=%~f0"
    powershell -NoProfile -Command "Start-Process -FilePath $env:RR_LAUNCHER_PATH -Verb RunAs"
    exit /b
)

set "SYS=%SystemRoot%\System32"
set "VIEW=%~dp0debug\Show-Log.ps1"
call :log loader "ROB RUN internal loader"

if not exist "%~dp0RobRunInternal.dll" (
    call :log loader "RobRunInternal.dll is missing next to this file."
    pause >nul
    exit /b 1
)

%SYS%\tasklist.exe /fi "IMAGENAME eq ROB RUN.exe" | %SYS%\findstr.exe /i "ROB RUN.exe" >nul
if errorlevel 1 (
    call :log loader "ROB RUN.exe is not running. Start the game and wait for the lobby."
    pause >nul
    exit /b 1
)

call :log loader "Keep ROB RUN focused and the OBS Game Capture preview live while this runs."

call :log mapper "Mapping driver."
call :run_logged mapper "%~dp0builds\orelia-mapper.exe" "%~dp0builds\orelia-ioctl.sys"

call :log injector "Loading RobRunInternal.dll."
call :run_logged injector "%~dp0builds\ioctl-injector.exe" "%~dp0RobRunInternal.dll"

%SYS%\ping.exe -n 9 127.0.0.1 >nul

powershell -NoProfile -ExecutionPolicy Bypass -File "%VIEW%"
pause >nul
exit /b

:log
powershell -NoProfile -ExecutionPolicy Bypass -File "%VIEW%" -Channel "%~1" -Message "%~2"
exit /b

:run_logged
set "TOOL_OUTPUT=%TEMP%\amphetamine-%~1-%RANDOM%-%RANDOM%.log"
"%~2" "%~3" <nul >"%TOOL_OUTPUT%" 2>&1
set "TOOL_EXIT=%errorlevel%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%VIEW%" -Channel "%~1" -ReadInput <"%TOOL_OUTPUT%"
del "%TOOL_OUTPUT%" >nul 2>&1
call :log "%~1" "Exit code %TOOL_EXIT%"
exit /b %TOOL_EXIT%

:check_files
for %%F in ("RobRunInternal.dll" "builds\ioctl-injector.exe" "builds\orelia-mapper.exe" "builds\orelia-ioctl.sys" "debug\Show-Log.ps1") do (
    if not exist "%~dp0%%~F" (
        echo Missing file: "%~dp0%%~F"
        exit /b 1
    )
)
exit /b 0
