@echo off
echo Running GLPSOL ...
@REM call glpsol -m aps.mod -d aps.dat --mipgap 0.01 --cuts --scale --adv
call glpsol -m aps.mod -d LS.dat -d LS_distdur.dat --mipgap 0.01 --cuts --scale --adv