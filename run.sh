#!/bin/sh
name=QuickBelt_1.0.0
./zip.sh
mv ${name}.zip 'C:\Users\mp\AppData\Roaming\Factorio\mods'
cmd /c 'C:\Program Files\Factorio\bin\x64\factorio.exe'
