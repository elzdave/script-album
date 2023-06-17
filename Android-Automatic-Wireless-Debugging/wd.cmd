rem Android ADB Wireless Debugging helper for Windows
rem (c) 2018-2023. David Eleazar

@echo off
color 0b
cd platform-tools
title Android Wireless Debugging Helper
adb kill-server
cls
echo Connect your phone using USB!
echo Now waiting . . .
adb wait-for-device>nul
mkdir tmp
attrib +S +H tmp /S /D
adb devices | find "device" > tmp\devices.txt
for /F "usebackq skip=1 delims=	tokens=1" %%A in (tmp\devices.txt) do set dev=%%A
if not "%dev%"=="" (
  color 0e
  echo.
  echo Device found!
  echo Device : %dev%
  adb shell ifconfig wlan0 | find "inet addr" > tmp\ip.txt
  for /F "tokens=3 delims=: " %%B in (tmp\ip.txt) do set ip=%%B
) else (
  color 0c
  echo.
  echo Device not found !
  echo Press any key to exit . . .
  pause>nul
  exit /B
)
rmdir tmp /S /Q
set /a port=(%random%*19999/32767)+1000
adb tcpip %port%
adb connect %ip%:%port%
echo Now eject the USB cable from device
echo.
echo You can now start debug your Android device wirelessly.
echo Please kill the ADB server after your work has been done.
echo.
echo Press any key to kill server . . .
pause>nul
adb kill-server
