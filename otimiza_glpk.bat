@echo off
echo Running GLPSOL ...
REM call glpsol -m aps.mod -d aps.dat -d 31.dat --mipgap 0.001 --cuts
@REM call glpsol -m aps.mod -d aps.dat --mipgap 0.05 --cuts
@REM call glpsol -m aps.mod -d aps.dat --mipgap 0.01 --cuts --scale --adv --check
call glpsol -m aps.mod -d aps.dat --mipgap 0.01 --cuts --scale --adv 