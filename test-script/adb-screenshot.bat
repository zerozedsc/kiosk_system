@echo off
setlocal

REM Get current date and time for filename
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "YYYY=%dt:~0,4%"
set "MM=%dt:~4,2%"
set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%"
set "Min=%dt:~10,2%"
set "Sec=%dt:~12,2%"
set "timestamp=%YYYY%%MM%%DD%_%HH%%Min%%Sec%"

REM Get the directory where the batch file is located
set "currentDir=%~dp0"
REM Remove trailing backslash
set "currentDir=%currentDir:~0,-1%"

echo Taking screenshot...
REM Take a screenshot and save it on the device
adb shell screencap -p /sdcard/screenshot.png

echo Pulling screenshot to: %currentDir%
REM Pull the screenshot to the current directory with timestamp
adb pull /sdcard/screenshot.png "%currentDir%\screenshot_%timestamp%.png"

echo Cleaning up...
REM Delete the screenshot from the device
adb shell rm /sdcard/screenshot.png

echo Screenshot saved as: screenshot_%timestamp%.png
pause