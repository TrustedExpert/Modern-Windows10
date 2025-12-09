@echo off
setlocal EnableDelayedExpansion

:: Set paths
set "hosts_file=%SystemRoot%\System32\drivers\etc\hosts"
set "input_file=hosts.txt"

:: Check if hosts.txt exists
if not exist "%input_file%" (
    echo Error: %input_file% not found in current directory
    pause
    exit /b
)

:: Read each line from hosts.txt
for /f "tokens=*" %%a in (%input_file%) do (
    :: Skip empty lines and comments
    echo %%a | findstr /v "^\s*$ ^#" >nul
    if !errorlevel! equ 0 (
        :: Check if line exists in hosts file
        findstr /i /c:"%%a" "%hosts_file%" >nul
        if !errorlevel! neq 0 (
            :: Append line to hosts file
            echo Appending: %%a
            echo %%a>>"%hosts_file%"
        )
    )
)

echo Done.
exit