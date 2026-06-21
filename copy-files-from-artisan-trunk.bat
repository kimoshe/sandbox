:: File to copy back recent changes from artisan trunk to sandbox

:: Changes for PyQt6 and libusb-package
copy /Y \users\dave\documents\github\artisan\.appveyor.yml \users\dave\documents\github\sandbox
copy /Y \users\dave\documents\github\artisan\.ci\install-win.bat \users\dave\documents\github\sandbox\.ci
copy /Y \users\dave\documents\github\artisan\src\build_derived-win.bat \users\dave\documents\github\sandbox\src
copy /Y \users\dave\documents\github\artisan\src\requirements.txt \users\dave\documents\github\sandbox\src

:: Other files
copy /Y \users\dave\documents\github\artisan\src\requirements-dev.txt \users\dave\documents\github\sandbox\src

:: Changes for BBP
rem copy /Y \users\dave\documents\github\artisan\src\artisanlib\main.py \users\dave\documents\github\sandbox\src\artisanlib
rem copy /Y \users\dave\documents\github\artisan\src\artisanlib\canvas.py \users\dave\documents\github\sandbox\src\artisanlib
