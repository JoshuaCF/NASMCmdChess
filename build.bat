@ECHO OFF

SET "objs="

FOR /F "tokens=*" %%a IN (files.txt) DO CALL :make %%a
GOTO skip

:make
nasm -f win32 -gcv8 -i src/ src/%1.asm
SET "objs=%objs%src/%1.obj "
EXIT /B 0

:skip

gcc -m32 -g %objs% -o bin/main.exe

FOR /F "tokens=*" %%a IN (files.txt) DO DEL "src\%%a.obj"

PAUSE