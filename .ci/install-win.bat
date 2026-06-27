@echo off
:: ABOUT
:: Install script for Artisan Windows CI builds
::
:: LICENSE
:: This program or module is free software: you can redistribute it and/or
:: modify it under the terms of the GNU General Public License as published
:: by the Free Software Foundation, either version 2 of the License, or
:: version 3 of the License, or (at your option) any later versison. It is
:: provided for educational purposes and is distributed in the hope that
:: it will be useful, but WITHOUT ANY WARRANTY; without even the implied
:: warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See
:: the GNU General Public License for more details.
::
:: AUTHOR
:: Dave Baxter, Marko Luther 2023


:: the current directory on entry to this script must be the folder above src

setlocal enabledelayedexpansion
if /i "%APPVEYOR%" NEQ "True" (
    echo This file is for use on Appveyor CI only.
    exit /b 1
)
set ARTISAN_SPEC=win
:: ----------------------------------------------------------------------

ver
echo Python Version:
python -V

::
:: get pip up to date
::
::python -m pip install --upgrade pip

:: install wheel
python -m pip install wheel

::
:: install Artisan required libraries from pip
::
python -m pip install -r src\requirements.txt | findstr /v /b "Ignoring"

:: Check that libusb-1.0.dll was installed.  Was missing once on CI with Win11.
if not exist %PYTHON_PATH%\Lib\site-packages\libusb_package\libusb-1.0.dll (
    echo *** ERROR - libusb-1.0.dll is missing from the libusb-package installation
    exit /b 95
)

::
:: appveyor_build_worker_image: Visual Studio 2026 does not supply a working lrelease.exe in Qt/6.11
:: until that is fixed install lrelease from https://github.com/thurask/Qt-Linguist.
:: this version (6.10) is more current than the one supplied by qt6-applications on pypi (v6.5)
:: as of this writing
echo ***** Start Install QTLinguist/lrelease.exe
curl -L -O https://github.com/thurask/Qt-Linguist/releases/download/latest/linguist_%QT_LINGUIST_VER%.zip
if not exist linguist_%QT_LINGUIST_VER%.zip (echo ** Download failed.  Probably need to update the qt-linguist version in requirements.txt & exit /b 98)

dir

7z x linguist_%QT_LINGUIST_VER%.zip -o.\QtLinguist\
if not exist QtLinguist/lrelease.exe (exit /b 99)
echo ***** Finished install QTLinguist/lrelease

::
:: custom build the pyinstaller bootloader or install a prebuilt
::
if /i "%BUILD_PYINSTALLER%"=="True" (
    echo ***** Start build pyinstaller v%PYINSTALLER_VER%
    rem
    rem download pyinstaller source
    echo ***** curl pyinstaller v%PYINSTALLER_VER%
    curl -L -O https://github.com/pyinstaller/pyinstaller/archive/refs/tags/v%PYINSTALLER_VER%.zip
    if not exist v%PYINSTALLER_VER%.zip (exit /b 100)
    7z x v%PYINSTALLER_VER%.zip
    del v%PYINSTALLER_VER%.zip
    if ERRORLEVEL 1 (exit /b 110)
    if not exist pyinstaller-%PYINSTALLER_VER%/bootloader/ (exit /b 120)
    cd pyinstaller-%PYINSTALLER_VER%/bootloader
    rem
    rem build the bootloader and wheel
    echo ***** Running WAF
    python ./waf all --msvc_targets=x64
    cd ..
    echo ***** Start build pyinstaller v%PYINSTALLER_VER% wheel
    rem redirect standard output to lower the noise in the logs
    python -m build --wheel > NUL
    if not exist dist/pyinstaller-%PYINSTALLER_VER%-py3-none-any.whl (exit /b 130)
    echo ***** Finished build pyinstaller v%PYINSTALLER_VER% wheel
    rem
    rem install pyinstaller
    echo ***** Start install pyinstaller v%PYINSTALLER_VER%
    python -m pip install -q dist/pyinstaller-%PYINSTALLER_VER%-py3-none-any.whl
    cd ..
) else (
     python -m pip install -q pyinstaller==%PYINSTALLER_VER%
)
echo ***** Finished install pyinstaller v%PYINSTALLER_VER%

::
:: download and install required libraries not available on pip
::
echo curl vc_redist.x64.exe
curl -L -O %VC_REDIST%
if not exist vc_redist.x64.exe (exit /b 140)


rem ----------------remove this-------------------------------
REM ============================================================================
REM Qt-Linguist Downloader
REM Downloads linguist_X.X.X.zip from the correct GitHub release
REM Uses GitHub API and curl to find and download the file
REM ============================================================================

REM Configuration
set GITHUB_API=https://api.github.com/repos/thurask/Qt-Linguist/releases

:: Move this to the top
REM Check if QT_LINGUIST_VER environment variable is set
if not defined QT_LINGUIST_VER (
    echo Error: QT_LINGUIST_VER environment variable is not set
    exit /b 1
)

set VERSION=%QT_LINGUIST_VER%
set FILENAME=linguist_%VERSION%.zip
set TEMP_JSON=%TEMP%\qt_linguist_releases.json
set DOWNLOAD_URL=

echo Searching for release containing %FILENAME%...

REM Query GitHub API to get all releases
curl -s "%GITHUB_API%" > "%TEMP_JSON%"

if errorlevel 1 (
    echo Error: Failed to access GitHub API. Please check your internet connection.
    del "%TEMP_JSON%" 2>nul
    exit /b 1
)

REM Check if JSON file was created and is not empty
if not exist "%TEMP_JSON%" (
    echo Error: GitHub API response file not created
    exit /b 1
)

for /f %%A in ('type "%TEMP_JSON%" ^| find /c "browser_download_url"') do (
    if %%A equ 0 (
        echo Error: Could not parse GitHub API response
        del "%TEMP_JSON%" 2>nul
        exit /b 1
    )
)

REM Create a temporary PowerShell script to properly parse JSON
set PS_SCRIPT=%TEMP%\parse_url.ps1

(
    echo $json = Get-Content '%TEMP_JSON%' -Raw
    echo $version = '%VERSION%'
    echo $filename = 'linguist_' + $version + '.zip'
    echo $data = ConvertFrom-Json $json
    echo foreach ($release in $data^) {
    echo     foreach ($asset in $release.assets^) {
    echo         if ($asset.name -eq $filename^) {
    echo             Write-Host $asset.browser_download_url
    echo             exit 0
    echo         }
    echo     }
    echo }
    echo Write-Host 'NOT_FOUND'
) > "%PS_SCRIPT%"

REM Execute PowerShell to parse JSON and get download URL
for /f "delims=" %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"') do (
    set DOWNLOAD_URL=%%A
)

REM Clean up temporary files
del "%TEMP_JSON%" 2>nul
del "%PS_SCRIPT%" 2>nul

REM Check if download URL was found
if "%DOWNLOAD_URL%"=="NOT_FOUND" (
    echo Error: Could not find %FILENAME% in any GitHub release
    exit /b 1
)

if "%DOWNLOAD_URL%"=="" (
    echo Error: Could not parse GitHub API response
    exit /b 1
)

REM Download the file
echo Found release. Downloading from:
echo %DOWNLOAD_URL%
echo.
echo Downloading %FILENAME%...

curl -L -o "%FILENAME%" "%DOWNLOAD_URL%"

if errorlevel 1 (
    echo Error: Download failed
    exit /b 1
)

if not exist "%FILENAME%" (
    echo Error: Download completed but file was not created
    exit /b 1
)

echo Download completed successfully: %FILENAME%
exit /b 0
rem ----------------remove this-------------------------------

::
:: show set of libraries are installed
::
echo **** pip freeze ****
python -m pip freeze
