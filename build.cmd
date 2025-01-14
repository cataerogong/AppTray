@echo off
setlocal
set compiler=D:\Programs\AutoIt\Aut2Exe\Aut2exe_x64.exe
%compiler% /in AppTray.au3 /out AppTray.exe /icon AppTray.ico /nopack /x64
