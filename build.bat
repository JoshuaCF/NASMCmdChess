@ECHO OFF

SET "objs="

FOR /F "tokens=*" %%a IN (files.txt) DO CALL :make %%a
GOTO skip

:make
nasm -f win32 -gcv8 -i src/ src/%1.asm
SET "objs=%objs%src/%1.obj "
EXIT /B 0

:skip

gcc -m32 -ggdb %objs% -o bin/main.exe
gcc -ggdb -O0 -c src/structs.c -o bin/structs.o

FOR /F "tokens=*" %%a IN (files.txt) DO DEL "src\%%a.obj"

PAUSE