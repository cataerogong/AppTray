@echo off
setlocal
call build.cmd
for /f "tokens=4 delims=;'= " %%a in ('findstr /R /C:"[ ]*Global[ ]*Const[ ]*$APP_VERSION[ ]*=.*" /X AppTray.au3') do set "__version__=%%~a"
echo.
echo release version: %__version__%
echo.
zip AppTray-%__version__%-win-x64.zip AppTray.exe LICENSE Readme.MD AppTray.example.ini
