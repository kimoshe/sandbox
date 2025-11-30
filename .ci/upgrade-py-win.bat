@echo off
setlocal enabledelayedexpansion
::
:: Upgrade the Python version to PYUPGRADE_WIN_V whenever the environment variable exists
::   and the upgrade version is greater than current Python version. 
::

:: If there is no upgrade version then simply return
::if "%PYUPGRADE_WIN_V%"=="" (
::    goto End
::)

:: Check that python.exe exists, if not go straight to the upgrade. 
:: Note: goto used to avoid comments in nested brackets issues.  Better to have comments.
::if Not Exist "%PYTHON_PATH%\python.exe" (
::    echo ***DIAG*** Going straight to upgrade, python.exe does not exist
::    goto Upgrade
::)

:: Get the current Python version if python.exe exists
if exist %PREV_PYTHON_PATH%\python.exe
(
    for /f "tokens=2 delims= " %%a in ('%PREV_PYTHON_PATH%\python.exe -V 2^>^&1') do set "PREV_PYTHON_VER=%%a"
) else (
    echo **** ERROR: %PREV_PYTHON_PATH%\python.exe does not exist in the build environment
    exit /b 91
)

echo *** Current Python Version: %PREV_PYTHON_VER%  Upgrade to: %PYUPGRADE_WIN_V% requested

:: Split the version strings into components - major.minor.patch
for /f "tokens=1,2,3 delims=." %%a in ("%PREV_PYTHON_VER%") do (
    set "major_py=%%a"
    set "minor_py=%%b"
    set "patch_py=%%c"
)
for /f "tokens=1,2,3 delims=." %%a in ("%PYUPGRADE_WIN_V%") do (
    set "major_up=%%a"
    set "minor_up=%%b"
    set "patch_up=%%c"
)

:: Compare version numbers at each level
if %major_py% lss %major_up% (
    goto Upgrade
) else if %major_py% gtr %major_up% (
    goto NoUpgrade
)
if %minor_py% lss %minor_up% (
    goto Upgrade
) else if %minor_py% gtr %minor_up% (
    goto NoUpgrade
)
if %patch_py% lss %patch_up% (
    goto Upgrade
)
goto NoUpgrade

:Upgrade
echo ***** Upgrading Python from %PYTHON_V% to %PYUPGRADE_WIN_V%
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
echo **** ERROR: Python upgrade not happening from %PREV_PYTHON_VER% to %PYUPGRADE_WIN_V%
exit /b 92

:End
endlocal
