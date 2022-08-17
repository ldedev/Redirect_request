@echo off

if not exist bin\debug (
    md bin\debug
)

taskkill /f /im "srv-redirect.exe" /t

if exist bin\debug\srv-redirect.exe (
    del bin\debug\srv-redirect.exe
)

cls
ping /n 2 127.0.0.1 >nul

v watch -o bin\debug\srv-redirect.exe crun "%~dp0"