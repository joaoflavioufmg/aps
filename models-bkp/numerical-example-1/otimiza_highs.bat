REM glpsol -m aps.mod -d aps.dat -d 31.dat --wlp aps.lp --check
REM highs --model_file .\aps.lp --options_file aps.opt 
REM glpsol -m aps.mod -d aps.dat -d 31.dat -r aps.sol

@echo off
echo Running GLPSOL to generate LP...
call glpsol -m aps.mod -d aps.dat --wlp aps.lp --check

echo Running HiGHS solver...
call highs --model_file .\aps.lp --options_file aps.opt

echo Running GLPSOL again to generate solution...
call glpsol -m aps.mod -d aps.dat -r aps.sol

echo Done.
pause
