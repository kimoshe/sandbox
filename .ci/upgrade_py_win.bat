@echo off
setlocal enabledelayedexpansion

::
:: Upgrade the Python version to PYUPGRADE_WIN_V whenever the environment variable exists
::   and the upgrade version is greater than current Python version. 
::
if "%PYUPGRADE_WIN_V%"=="" (
    echo PYUPGRADE_WIN_V is not set. Skipping upgrade.
    goto End
)

:: Check that python.exe exists, if not go straight to the upgrade. 
:: Note: goto used to avoid comments in nested brackets issues.  Better to have comments.
if Not Exist "%PYTHON_PATH%\python.exe" (
    goto Upgrade
)

:: Get the current Python version if python.exe exists
for /f "tokens=2 delims= " %%a in ('%PyTHON_path%\python.exe -V 2^>^&1') do set "PYTHON_VERSION=%%a"

set "version1=%PYTHON_VERSION%"
set "version2=%PYUPGRADE_WIN_V%"

echo *** Current Python Version: %version1%  Upgrade to: %version2%

:: Split the version strings into components
for /f "tokens=1,2,3 delims=." %%a in ("%PYTHON_VERSION%") do (
    set "major_py=%%a"
    set "minor_py=%%b"
    set "patch_py=%%c"
)

for /f "tokens=1,2,3 delims=." %%a in ("%PYUPGRADE_WIN_V%") do (
    set "major_up=%%a"
    set "minor_up=%%b"
    set "patch_up=%%c"
)

:: Compare major version
echo Major Version: %major_py%  %major_up%
if %major_py% lss %major_up% (
    echo Upgrade Needed Major
    goto Upgrade
) else if %major_py% gtr %major_up% (
    echo No Upgrade Needed Major
    goto NoUpgrade
)

:: Compare minor version
echo Minor Version: %minor_py%  %minor_up%
if %minor_py% lss %minor_up% (
    echo Upgrade Needed Minor
    goto Upgrade
) else if %minor_py% gtr %minor_up% (
    echo No Upgrade Needed Minor
    goto NoUpgrade
)

:: Compare patch version
echo Patch Version: %patch_py%  %patch_up%
if %patch_py% lss %patch_up% (
    echo Upgrade Needed Patch
    goto Upgrade
) else (
    echo No Upgrade Needed Patch
    goto NoUpgrade
)

:Upgrade
    echo ***** Upgrading to %PYUPGRADE_WIN_V%
    echo *** Downloading Python install exe
    curl -L -O https://www.python.org/ftp/python/%PYUPGRADE_WIN_V%/python-%PYUPGRADE_WIN_V%-amd64.exe
    if not exist python-%PYUPGRADE_WIN_V%-amd64.exe (exit /b 80)
    echo *** Installing Python %PYUPGRADE_WIN_V%
    python-%PYUPGRADE_WIN_V%-amd64.exe /quiet PrependPath=1
    if not exist %PYTHON_PATH%\python.exe (exit /b 90)
    echo ***** Upgrade Complete
    echo Python Version Now:
    python -V

goto End

:NoUpgrade
echo No upgrade needed based on current version.

:End
endlocal
