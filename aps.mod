#############################################################################
# Project CNPq: Increasing PHC with team sizing
# Author: João Flávio de Freitas Almeida <joao.flavio@dep.ufmg.br>
# LEPOINT: Laboratório de Estudos em Planejamento de Operações Integradas
# Departmento de Engenharia de Produção
# Universidade Federal de Minas Gerais - Escola de Engenharia
#############################################################################
# Health Care Facility Location Problem with Team Reallocation
# >> Teams with excess capacity can be reassigned to locations with deficits
# >> Minimizes team displacement distance and need for new teams
#############################################################################
# glpsol -m aps.mod -d aps.dat -d city.dat --mipgap 0.01 --cuts --check --wlp aps.lp
# glpsol -m aps.mod -d aps.dat --mipgap 0.01 --cuts --check --wlp aps.lp
# highs --model_file .\aps.lp --aps options.opt 
# glpsol -m aps.mod -d aps.dat -d city.dat -r aps.sol

# https://ergo-code.github.io/HiGHS/dev/options/definitions/
# https://github.com/JuliaBinaryWrappers/HiGHSstatic_jll.jl/releases

# #----------------------------------------------------------------------------------------------------------------------------------------------#
# param now:= gmtime() -3*3600;
# param time, symbolic, := time2str(now, "%d de %b de 20%y as %T");
# #----------------------------------------------------------------------------------------------------------------------------------------------#

set I; # The set of demand points.

set K; # Health care levels (PHC, SHC, THC)

param Dmax{K}; # Maximal distance (or travel time)

set E{K}; # Health care team from level k 

set EL{K}; # EXISTING health care units on three levels

set CL{K}; # CANDIDATE health care LOCATIONS on three levels

set L{k in K} := EL[k] union CL[k]; 

################################################
# BUDGET PARAMETER
param BUDGET >= 0; # Overall budget constraint ($/month)
################################################

param CE1{c1 in E[1]}; # Team cost K1 ($/month)
param CE2{c2 in E[2]}; # Team cost K2 ($/month)
param CE3{c3 in E[3]}; # Team cost K3 ($/month)

# Team relocation cost (per professional per distance unit)
param RC1{E[1]} default 0.1; # Relocation cost for PHC team ($/prof/min)
param RC2{E[2]} default 0.1; # Relocation cost for SHC team ($/prof/min)
param RC3{E[3]} default 0.1; # Relocation cost for THC team ($/prof/min)


# param D1{I,L[1]}:=round(Uniform(5,15));    # The travel time between i and level-1 PCF.   (min)
# param D2{L[1],L[2]}:=round(Uniform(10,30)); # The travel time between candidate L1 and L2. (min)
# param D3{L[2],L[3]}:=round(Uniform(20,40)); # The travel time between candidate L2 and L3. (min)
# param D0_1{I,L[1]};    # The travel time between i and level-1 PCF.   (min)
# param D0_2{I,L[2]};    # The travel time between i and level-2 SCF.   (min)
# param D0_3{I,L[3]};    # The travel time between i and level-3 TCF.   (min)
# param D1_2{L[1],L[2]}; # The travel time between candidate L1 and L2. (min)
# param D2_3{L[2],L[3]}; # The travel time between candidate L2 and L3. (min)
# param D1_3{L[1],L[3]}; # The travel time between candidate L1 and L3. (min)
param D0_1{I,L[1]}:= 1;    # The travel time between i and level-1 PCF.   (min)
param D0_2{I,L[2]}:= 2;    # The travel time between i and level-2 SCF.   (min)
param D0_3{I,L[3]}:= 3;    # The travel time between i and level-3 TCF.   (min)
param D1_2{L[1],L[2]}:= 2; # The travel time between candidate L1 and L2. (min)
param D2_3{L[2],L[3]}:= 2; # The travel time between candidate L2 and L3. (min)
param D1_3{L[1],L[3]}:= 3; # The travel time between candidate L1 and L3. (min)

param D1_0{j1 in L[1], i in I} := D0_1[i,j1];    # The travel time between i and level-1 PCF.   (min)
param D2_0{j2 in L[2], i in I} := D0_2[i,j2];    # The travel time between i and level-2 SCF.   (min)
param D3_0{j3 in L[3], i in I} := D0_3[i,j3];    # The travel time between i and level-3 TCF.   (min)
param D2_1{j2 in L[2], j1 in L[1]} := D1_2[j1,j2]; # The travel time between candidate L1 and L2. (min)
param D3_2{j3 in L[3], j2 in L[2]} := D2_3[j2,j3]; # The travel time between candidate L2 and L3. (min)
param D3_1{j3 in L[3], j1 in L[1]} := D1_3[j1,j3]; # The travel time between candidate L1 and L3. (min)

# Distance matrix between same-level facilities (for team transfer)
param DL1{EL[1], L[1]} default 0.1; # Distance between L1 facilities (min)
param DL2{EL[2], L[2]} default 0.2; # Distance between L2 facilities (min)
param DL3{EL[3], L[3]} default 0.3; # Distance between L3 facilities (min)


set Link1 dimen 2:= setof{i in I, j1 in L[1]: D0_1[i,j1] <= Dmax[1]}(i,j1);
set H1:= setof{i in I,j1 in L[1]: D0_1[i,j1] <= Dmax[1]} j1;
set Link2 dimen 2:= setof{j1 in L[1], j2 in L[2]: D1_2[j1,j2] <= Dmax[2]}(j1,j2);
set H2:= setof{j1 in L[1], j2 in L[2]: D1_2[j1,j2] <= Dmax[2]} j2;
set Link3 dimen 2:= setof{j2 in L[2], j3 in L[3]: D2_3[j2,j3] <= Dmax[3]}(j2,j3);
set H3:= setof{j2 in L[2], j3 in L[3]: D2_3[j2,j3] <= Dmax[3]} j3;

set L1:= L[1] inter H1;
set L2:= L[2] inter H2;
set L3:= L[3] inter H3;

# display L1;
# display L2;
# display L3;

################################################
# param TC1{I,L[1]}; # Travel cost/pat  from demand point i to L1   ($/min)
# param TC2{L[1],L[2]}; # Travel cost/pat  from L1 to L2            ($/min)
# param TC3{L[2],L[3]}; # Travel cost/pat  from L2 to L3            ($/min)

param CKM:= 1;  # Custo por km
param TC0_1{i in I,j1 in L[1]}:= D0_1[i,j1]*CKM; # Travel cost/pat  from demand point i to L1   ($/min)
param TC0_2{i in I,j2 in L[2]}:= D0_2[i,j2]*CKM; # Travel cost/pat  from demand point i to L1   ($/min)
param TC0_3{i in I,j3 in L[3]}:= D0_3[i,j3]*CKM; # Travel cost/pat  from demand point i to L1   ($/min)
param TC1_2{j1 in L[1], j2 in L[2]}:= D1_2[j1,j2]*CKM; # Travel cost/pat  from L1 to L2            ($/min)
param TC1_3{j1 in L[1], j3 in L[3]}:= D1_3[j1,j3]*CKM; # Travel cost/pat  from L1 to L2            ($/min)
param TC2_3{j2 in L[2], j3 in L[3]}:= D2_3[j2,j3]*CKM; # Travel cost/pat  from L2 to L3            ($/min)


param VC1{L[1]}; # Variable cost of PHC j / pop h ($/pop)
param VC2{L[2]}; # Variable cost of SHC j / pop h ($/pop)
param VC3{L[3]}; # Variable cost of THC j / pop h ($/pop)

param FC1{L[1]}; # Fixed cost per period for operating PHC j    ($/month)
param FC2{L[2]}; # Fixed cost per period for operating SHC j    ($/month)
param FC3{L[3]}; # Fixed cost per period for operating THC j    ($/month)

# ############## Amortização anual para Investimento em nova UBS ############## 
param R:=0.15;   # Taxa de desconto anual
param N:=20;     # Vida útil (anos)
param I_L1:= 1000; # Investimento (custo de implantação) na nova UBS: Obra, reforma e equipamentos
param I_L2:= 2000; # Investimento (custo de implantação) na nova UBS: Obra, reforma e equipamentos
param I_L3:= 3000; # Investimento (custo de implantação) na nova UBS: Obra, reforma e equipamentos
# Annualized Investment for operating NEW PHC j    ($/year)
param IA1{CL[1]} := round(I_L1*(R*(1+R)^N)/((1+R)^N-1),0); 
# display IA1;
# Annualized Investment for operating NEW SHC j    ($/year)
param IA2{CL[2]}:= round(I_L2*(R*(1+R)^N)/((1+R)^N-1),0); 
# display IA2;
# Annualized Investment for operating NEW THC j    ($/year)
param IA3{CL[3]}:= round(I_L3*(R*(1+R)^N)/((1+R)^N-1),0); 
# display IA3;
# ############################################################################### 

param W{I}; # The population size at demand point i (pop)
param IVS{I}; # Índice de Vulnerabildade em Saude at demand point i (pop)


# COUNT how many IVS[i] <= IVS[j] for each j
# param COUNT_IVS{j in I} := sum{i in I} (IVS[i] <= IVS[j]);
param COUNT_IVS{j in I} := sum{i in I} (if IVS[i] <= IVS[j] then 1 else 0);

# Select thresholds as the smallest IVS[j] reaching each rank
# ranks for 33%, 66%, 100%
param LOW_IVS := min{j in I : COUNT_IVS[j] >= ceil(card(I) * 0.33) } IVS[j];
param MED_IVS := min{j in I : COUNT_IVS[j] >= ceil(card(I) * 0.66) } IVS[j];
param HIG_IVS := min{j in I : COUNT_IVS[j] >= card(I) } IVS[j];

# (prof/pop)
param PROF_POP{i in I} := 
    if IVS[i] <= LOW_IVS then 1/2500
        else if IVS[i] <= MED_IVS then 1/3000
        else if IVS[i] <= HIG_IVS then 1/3500
        else "ERROR";
    # if IVS[i] <= LOW_IVS then W[i]/2500
    # else if IVS[i] <= MED_IVS then W[i]/3000
    # else if IVS[i] <= HIG_IVS then W[i]/3500
    # else "ERROR";

# # display results
display LOW_IVS, MED_IVS, HIG_IVS;
# display {i in I} i, IVS[i], W[i], PROF_POP[i];

param PROP{e1 in E[1]} :=
    if e1 = "eSF" then 1
    else if e1 = "eSB" then 1
    else if e1 = "eMU" then 1/9
    else 0;

# Ministry of Health parameter for requirements PHC (prof/pop)
param MS0_1{i in I, e1 in E[1]} := PROP[e1] * PROF_POP[i];
# display MS0_1;

# param MS1{e1 in E[1]}:= if e1 = 'eSF' then 2e-2 else
#                         if e1 = 'eSB' then 2e-2 else
#                         if e1 = 'eMU' then 2e-2/9; 

# (prof/patient)
param PROF_PAT := 1/3000;
param MS1{e1 in E[1]} := PROP[e1] * PROF_PAT;
param MS2{E[2]}; # Ministry of Health parameter for requirements SHC (prof/pop)
param MS3{E[3]}; # Ministry of Health parameter for requirements THC (prof/pop)

param CNES1{E[1],EL[1]}; # Health professional teams PHC at location L1 (prof)
param CNES2{E[2],EL[2]}; # Health professional teams PHC at location L2 (prof)
param CNES3{E[3],EL[3]}; # Health professional teams PHC at location L3 (prof)

# Service operating capacity at IHC j
param C1{L[1]}; # The capacity of a level-1 PCF in K. (pop)
param C2{L[2]}; # The capacity of a level-2 PCF in J.   (pop)
param C3{L[3]}; # The capacity of a level-3 PCF in J.   (pop)

param U{K}; # The number of UNITS level-k to be established. (unit)

# param O1{L[1]}; # The proportion of patients in a L-1 to a L-2 PCF. (%)
# param O2{L[2]}; # The proportion of patients in a L-2 to a L-3 SCF. (%)

# Primary care facility (PCF)
param O1_0{L[1]}; # The proportion of patients in a L-1 to a home i PCF. (%)
param O1_2{L[1]}; # The proportion of patients in a L-1 to a L-2 PCF. (%)
param O1_3{L[1]}; # The proportion of patients in a L-1 to a L-3 PCF. (%)
# Secondary care facility (SCF)
param O2_0{L[2]}; # The proportion of patients in a L-2 to a home i SCF. (%)
param O2_1{L[2]}; # The proportion of patients in a L-2 to a L-1 SCF. (%)
param O2_3{L[2]}; # The proportion of patients in a L-2 to a L-3 SCF. (%)
# Tertiary care facility (TCF)
param O3_0{L[3]}; # The proportion of patients in a L-3 to home i TCF. (%)
param O3_1{L[3]}; # The proportion of patients in a L-3 to a L-1 TCF. (%)
param O3_2{L[3]}; # The proportion of patients in a L-3 to a L-2 TCF. (%)

check {j1 in L[1]}: O1_0[j1] + O1_2[j1] + O1_3[j1] <= 1;
check {j1 in L[1]}: O1_0[j1] + O1_2[j1] + O1_3[j1] >= 0.9;
check {j2 in L[2]}: O2_0[j2] + O2_1[j2] + O2_3[j2] <= 1;
check {j2 in L[2]}: O2_0[j2] + O2_1[j2] + O2_3[j2] >= 0.9;
check {j3 in L[3]}: O3_0[j3] + O3_1[j3] + O3_2[j3] <= 1;
check {j3 in L[3]}: O3_0[j3] + O3_1[j3] + O3_2[j3] >= 0.9;

# Percentual maximo de Atendimentos Telemedicina de casa > PHC, SHC, THC
param MAX_TELE_PHC, <= 1.0;
param MAX_TELE_SHC, <= 1.0;
param MAX_TELE_THC, <= 1.0;

# Percentual maximo de deslocamentos Casa > PHC, SHC, THC 
param MAX_HOME_PHC, <= 1.0;
param MAX_HOME_SHC, <= 1.0;
param MAX_HOME_THC, <= 1.0;

################################################
# BUDGET PREPROCESSING
param MinCostPerNewPHC := if card(CL[1] inter L1) > 0 then
    min{j1 in CL[1] inter L1}(FC1[j1]+IA1[j1] + sum{c1 in E[1]}CE1[c1]) else 0;
param MinCostPerNewSHC := if card(CL[2] inter L2) > 0 then
    min{j2 in CL[2] inter L2}(FC2[j2]+IA2[j2] + sum{c2 in E[2]}CE2[c2]) else 0;
param MinCostPerNewTHC := if card(CL[3] inter L3) > 0 then
    min{j3 in CL[3] inter L3}(FC3[j3]+IA3[j3] + sum{c3 in E[3]}CE3[c3]) else 0;

param ExistingCost := 
    sum{j1 in EL[1] inter L1}FC1[j1] + 
    sum{j2 in EL[2] inter L2}FC2[j2] + 
    sum{j3 in EL[3] inter L3}FC3[j3];

param AvailableBudget := max(0, BUDGET - ExistingCost);

param MaxNewPHC := if card(CL[1] inter L1) > 0 and MinCostPerNewPHC > 0 then 
                   min(U[1], floor(AvailableBudget / MinCostPerNewPHC)) else 0;
param MaxNewSHC := if card(CL[2] inter L2) > 0 and MinCostPerNewSHC > 0 then 
                   min(U[2], floor(AvailableBudget / MinCostPerNewSHC)) else 0;
param MaxNewTHC := if card(CL[3] inter L3) > 0 and MinCostPerNewTHC > 0 then 
                   min(U[3], floor(AvailableBudget / MinCostPerNewTHC)) else 0;

printf: "\n========================================\n";
printf: "BUDGET PREPROCESSING\n";
printf: "========================================\n";
printf: "Overall Budget:\t\t$%10.2f\n", BUDGET;
printf: "Existing Cost:\t\t$%10.2f\n", ExistingCost;
printf: "Available Budget:\t$%10.2f\n", AvailableBudget;
printf: "========================================\n";
printf: "Min Cost per New Facility:\n";
printf: "  PHC:\t\t\t$%10.2f\n", MinCostPerNewPHC;
printf: "  SHC:\t\t\t$%10.2f\n", MinCostPerNewSHC;
printf: "  THC:\t\t\t$%10.2f\n", MinCostPerNewTHC;
printf: "========================================\n";
printf: "Budget-Adjusted Max New Units:\n";
printf: "  PHC:\t\t\t%d (original: %d)\n", MaxNewPHC, U[1];
printf: "  SHC:\t\t\t%d (original: %d)\n", MaxNewSHC, U[2];
printf: "  THC:\t\t\t%d (original: %d)\n", MaxNewTHC, U[3];
printf: "========================================\n\n";

#################################################
# DECISION VARIABLES
#################################################

# Patient allocation
# var y{i in I, j1 in L1}, >=0, binary; # 1, if Pop is ASSIGNED to L-1 PCF
var y0_1{i in I, j1 in L1}, >=0, <=1; # % Pop is ASSIGNED to L-1 PCF
var y0_2{i in I, j2 in L2}, >=0, <=1; # % Pop is ASSIGNED to L-2 SCF
var y0_3{i in I, j3 in L3}, >=0, <=1; # $ Pop is ASSIGNED to L-3 TCF
var y1{j1 in L1}, >=0, binary; # 1, if a L-1 PCF is used
var y2{j2 in L2}, >=0, binary; # 1, if a L-2 SCF is used
var y3{j3 in L3}, >=0, binary; # 1, if a L-3 TCF is used

# Patient flows “fluxo de ida”
var u0_1{i in I, j1 in L1}, >=0;  # The flow between demand point i and L1 (pop)
var u1_2{j1 in L1, j2 in L2}, >=0;  # The flow between L1 and L2 (pop)
var u2_3{j2 in L2, j3 in L3}, >=0;  # The flow between L2 and L3 (pop)

var u0_2{i in I, j2 in L2} >= 0;  # Casa → Clínica (bypass UBS)
var u0_3{i in I, j3 in L3} >= 0;  # Casa → Hospital (bypass UBS e clínica)
var u1_3{j1 in L1, j3 in L3} >= 0;  # UBS → Hospital (encaminhamento direto)

# Fluxos de “passo inverso” (step-down)
var u3_2{j3 in L3, j2 in L2} >= 0;  # Alta hospitalar → clínica
var u3_1{j3 in L3, j1 in L1} >= 0;  # Alta hospitalar → UBS
var u2_1{j2 in L2, j1 in L1} >= 0;  # Retorno da clínica → UBS

var u3_0{j3 in L3, i in I} >= 0;  # Alta hospitalar → Casa
var u2_0{j2 in L2, i in I} >= 0;  # Retorno Clínica → Casa
var u1_0{j1 in L1, i in I} >= 0;  # Alta UBS → Casa


# fluxos de telemedicina (Casa -> unidade que presta teleconsulta)
var ut1{i in I, j1 in L1} >= 0;   # tele: domicílio -> UBS (tele atendido por profissional na UBS)
var ut2{i in I, j2 in L2} >= 0;   # tele: domicílio -> Clínica (tele atendido por profissional na clínica)
var ut3{i in I, j3 in L3} >= 0;   # tele: domicílio -> Hospital (tele atendido por profissional no hospital)

# Team variables (positive = deficit/need, negative = excess/surplus)
var deficit1{E[1],L1}, >=0; # Deficit of professional e on location L1 (prof)
var deficit2{E[2],L2}, >=0; # Deficit of professional e on location L2 (prof)
var deficit3{E[3],L3}, >=0; # Deficit of professional e on location L3 (prof)

var surplus1{E[1],EL[1] inter L1}, >= 0; # Surplus of prof e at existing L1 (prof)
var surplus2{E[2],EL[2] inter L2}, >= 0; # Surplus of prof e at existing L2 (prof)
var surplus3{E[3],EL[3] inter L3}, >= 0; # Surplus of prof e at existing L3 (prof)

# Team transfer variables (from existing location to any location with deficit)
var transfer1{e1 in E[1], from in EL[1] inter L1, to in L1: from != to}, integer, >= 0;
var transfer2{e2 in E[2], from in EL[2] inter L2, to in L2: from != to}, integer, >= 0;
var transfer3{e3 in E[3], from in EL[3] inter L3, to in L3: from != to}, integer, >= 0;

# New teams hired (only for candidate locations or to cover remaining deficits)
var newhire1{E[1],L1}, integer, >= 0; # New professionals hired at L1 (prof)
var newhire2{E[2],L2}, integer, >= 0; # New professionals hired at L2 (prof)
var newhire3{E[3],L3}, integer, >= 0; # New professionals hired at L3 (prof)

var Total_Costs_APS, >=0; # Aux variable for report


#################################################
# CONSTRAINTS
#################################################

# Fix variables of EXISTING locations (they must remain open)
s.t. F1{j1 in EL[1] inter L1}: y1[j1] = 1; 
s.t. F2{j2 in EL[2] inter L2}: y2[j2] = 1; 
s.t. F3{j3 in EL[3] inter L3}: y3[j3] = 1;

# Population assignment

# Cada origem i é atribuída a exatamente 1 UBS j1
# s.t. R0a{i in I}: sum{j1 in L1}y[i,j1] = 1;
s.t. R0a{i in I}: 
    sum{j1 in L1}y0_1[i,j1] 
    + sum{j2 in L2}y0_2[i,j2]
    + sum{j3 in L3}y0_3[i,j3] = 1;

# Patients assigned to closest health unit
s.t. R0b{i in I, j1 in L1}: sum{k1 in L1: D0_1[i,k1]>D0_1[i,j1]}y0_1[i,k1] + y1[j1] <= 1;
s.t. R0c{i in I, j2 in L2}: sum{k2 in L2: D0_2[i,k2]>D0_2[i,j2]}y0_2[i,k2] + y2[j2] <= 1;
s.t. R0d{i in I, j3 in L3}: sum{k3 in L3: D0_3[i,k3]>D0_3[i,j3]}y0_3[i,k3] + y3[j3] <= 1;

# s.t. R0{i in I, j1 in L1}: W[i]*y[i,j1] = u0_1[i,j1];
s.t. R0e{i in I, j1 in L1}: W[i]*y0_1[i,j1] = u0_1[i,j1] + ut1[i,j1];
s.t. R0f{i in I, j2 in L2}: W[i]*y0_2[i,j2] = u0_2[i,j2] + ut2[i,j2];
s.t. R0g{i in I, j3 in L3}: W[i]*y0_3[i,j3] = u0_3[i,j3] + ut3[i,j3];

# Percentual maximo de Atendimentos Telemedicina de casa > PHC, SHC, THC
s.t. R0h{i in I, j1 in L1}: ut1[i,j1] <= MAX_TELE_PHC * u0_1[i,j1];
s.t. R0i{i in I, j2 in L2}: ut2[i,j2] <= MAX_TELE_SHC * u0_2[i,j2];
s.t. R0j{i in I, j3 in L3}: ut3[i,j3] <= MAX_TELE_THC * u0_3[i,j3];

# Percentual maximo de deslocamentos Casa > PHC, SHC, THC 
s.t. R0k{i in I, j1 in L1}: u0_1[i,j1] <= MAX_HOME_PHC * W[i];
s.t. R0l{i in I, j2 in L2}: u0_2[i,j2] <= MAX_HOME_SHC * W[i];
s.t. R0m{i in I, j3 in L3}: u0_3[i,j3] <= MAX_HOME_THC * W[i];

# Balanceamento da demanda na origem i (todas as saídas = W[i])
# (Somam-se todos os tipos de saída do domicílio: presencial para L1/L2/L3 
# e tele para L1/L2/L3.)
s.t. DemandOut{i in I}:
    sum{j1 in L1} u0_1[i,j1]
  + sum{j2 in L2} u0_2[i,j2]
  + sum{j3 in L3} u0_3[i,j3]
  + sum{j1 in L1} ut1[i,j1]
  + sum{j2 in L2} ut2[i,j2]
  + sum{j3 in L3} ut3[i,j3]
  = W[i];

# Demanda retornando para a origem i (todas as entradas de step-down = W[i])
# (As altas / retornos de cada nível devolvem pacientes à sua origem; somam-se e igualam W[i].)
s.t. DemandIn{i in I}:
    sum{j1 in L1} u1_0[j1,i] # O1_0[j1]*
  + sum{j2 in L2} u2_0[j2,i] # O2_0[j2]*
  + sum{j3 in L3} u3_0[j3,i] # O3_0[j3]*
  = W[i];


# Flow balance PHC > SHC > THC
# s.t. R1{j1 in L1}: sum{j2 in L2}u1_2[j1,j2] = O1[j1]*sum{i in I}u0_1[i,j1];
# s.t. R2{j2 in L2}: sum{j3 in L3}u2_3[j2,j3] = O2[j2]*sum{j1 in L1}u1_2[j1,j2];

s.t. R1{j1 in L1}: 
    # Outflows
    sum{i in I} u1_0[j1,i]         # L1 → Home # O1_0[j1]*
    + sum{j2 in L2}u1_2[j1,j2]     # L1 → L2    # O1_2[j1]*
    + sum{j3 in L3}u1_3[j1,j3] =   # L1 → L3    # O1_3[j1]*
    # Inflows
    sum{i in I}u0_1[i,j1]                   # Home → L1
    + sum{j2 in L2}u2_1[j2,j1]              # L2 → L1
    + sum{j3 in L3}u3_1[j3,j1]              # L3 → L1
    + sum{i in I} ut1[i,j1];                # Telemedicine → L1

s.t. R1a{j1 in L1}: 
    # Outflows
    O1_0[j1]*
    (sum{i in I}u1_0[j1,i]         # L1 → Home
    + sum{j2 in L2}u1_2[j1,j2]     # L1 → L2
    + sum{j3 in L3}u1_3[j1,j3]) <=   # L1 → L3
    sum{i in I}u1_0[j1,i];     # L1 → Home

s.t. R1b{j1 in L1}: 
    # Outflows
    O1_2[j1]*
    (sum{i in I}u1_0[j1,i]         # L1 → Home
    + sum{j2 in L2}u1_2[j1,j2]     # L1 → L2
    + sum{j3 in L3}u1_3[j1,j3]) <=   # L1 → L3
    sum{j2 in L2}u1_2[j1,j2];     # L1 → L2

s.t. R1c{j1 in L1}: 
    # Outflows
    O1_3[j1]*
    (sum{i in I}u1_0[j1,i]         # L1 → Home
    + sum{j2 in L2}u1_2[j1,j2]     # L1 → L2
    + sum{j3 in L3}u1_3[j1,j3]) <=   # L1 → L3
    sum{j3 in L3}u1_3[j1,j3];     # L1 → L3

s.t. R2{j2 in L2}: 
    # Outflows
    sum{i in I} u2_0[j2,i]              # O2_0[j2]*
    + sum{j1 in L1}u2_1[j2,j1]          # O2_1[j2]*
    + sum{j3 in L3}u2_3[j2,j3] =        # O2_3[j2]*
    # Inflows
    sum{i in I}u0_2[i,j2] 
    + sum{j1 in L1}u1_2[j1,j2] 
    + sum{j3 in L3}u3_2[j3,j2]
    + sum{i in I} ut2[i,j2];

s.t. R2a{j2 in L2}: 
    # Outflows
    O2_0[j2]*
    (sum{i in I}u2_0[j2,i]         # L2 → Home
    + sum{j1 in L1}u2_1[j2,j1]     # L2 → L1
    + sum{j3 in L3}u2_3[j2,j3]) <=   # L2 → L3
    sum{i in I}u2_0[j2,i];     # L2 → Home

s.t. R2b{j2 in L2}: 
    # Outflows
    O2_1[j2]*
    (sum{i in I}u2_0[j2,i]         # L2 → Home
    + sum{j1 in L1}u2_1[j2,j1]     # L2 → L1
    + sum{j3 in L3}u2_3[j2,j3]) <=   # L2 → L3
    sum{j1 in L1}u2_1[j2,j1];     # L2 → L1

s.t. R2c{j2 in L2}: 
    # Outflows
    O2_3[j2]*
    (sum{i in I}u2_0[j2,i]         # L2 → Home
    + sum{j1 in L1}u2_1[j2,j1]     # L2 → L1
    + sum{j3 in L3}u2_3[j2,j3]) <=   # L2 → L3
    sum{j3 in L3}u2_3[j2,j3];     # L2 → L3

s.t. R3{j3 in L3}: 
    # Outflows
    sum{i in I} u3_0[j3,i] # O3_0[j3]*
    + sum{j1 in L1}u3_1[j3,j1]  # O3_1[j3]*
    + sum{j2 in L2}u3_2[j3,j2] = # O3_2[j3]*
    # Inflows
    sum{i in I} u0_3[i,j3] 
    + sum{j1 in L1}u1_3[j1,j3] 
    + sum{j2 in L2}u2_3[j2,j3]
    + sum{i in I} ut3[i,j3];

s.t. R3a{j3 in L3}: 
    # Outflows
    O3_0[j3]*
    (sum{i in I}u3_0[j3,i]         # L3 → Home
    + sum{j1 in L1}u3_1[j3,j1]     # L3 → L1
    + sum{j2 in L2}u3_2[j3,j2]) <=   # L3 → L2
    sum{i in I}u3_0[j3,i];     # L3 → Home

s.t. R3b{j3 in L3}: 
    # Outflows
    O3_1[j3]*
    (sum{i in I}u3_0[j3,i]         # L3 → Home
    + sum{j1 in L1}u3_1[j3,j1]     # L3 → L1
    + sum{j2 in L2}u3_2[j3,j2]) <=   # L3 → L2
    sum{j1 in L1}u3_1[j3,j1];     # L3 → L1

s.t. R3c{j3 in L3}: 
    # Outflows
    O3_1[j3]*
    (sum{i in I}u3_0[j3,i]         # L3 → Home
    + sum{j1 in L1}u3_1[j3,j1]     # L3 → L1
    + sum{j2 in L2}u3_2[j3,j2]) <=   # L3 → L2
    sum{j2 in L2}u3_2[j3,j2];     # L3 → L1

#################################################
# TEAM BALANCE CONSTRAINTS - LEVEL 1 (PHC)
#################################################
# CNES (existente) - Necessário + Transferências OUT - Transferências IN + Novas Contratações = Excesso - Déficit
# For EXISTING locations: calculate surplus/deficit
s.t. TeamBalance1e{j1 in EL[1] inter L1, e1 in E[1]}:
    CNES1[e1,j1]  # Existing teams
    # Required teams based on patient flow
    # - (sum{i in I}u0_1[i,j1] + sum{j2 in L2}u2_1[j2,j1] + sum{j3 in L3}u3_1[j3,j1] + sum{i in I} ut1[i,j1])*MS1[i,e1] 
    # - sum{i in I} (u0_1[i,j1] + ut1[i,j1] + (if i in L2 then u2_1[i,j1] else 0) + (if i in L3 then u3_1[i,j1] else 0))*MS1[i,e1] 
    - (sum{i in I} (u0_1[i,j1] + ut1[i,j1])*MS0_1[i,e1] + sum{j2 in L2}u2_1[j2,j1]*MS1[e1] + sum{j3 in L3}u3_1[j3,j1]*MS1[e1])
    + sum{from in EL[1] inter L1: from != j1}transfer1[e1,from,j1]  # Teams transferred IN
    - sum{to in L1: to != j1}transfer1[e1,j1,to]  # Teams transferred OUT    
    + newhire1[e1,j1]  # New teams hired
    = surplus1[e1,j1] - deficit1[e1,j1];


# For CANDIDATE locations: only new hires and transfers IN
s.t. TeamBalance1c{j1 in CL[1] inter L1, e1 in E[1]}:
    # - (sum{i in I}u0_1[i,j1]+ sum{j2 in L2}u2_1[j2,j1] + sum{j3 in L3}u3_1[j3,j1] + sum{i in I} ut1[i,j1])*MS1[i,e1]  # Required teams
    # - sum{i in I} (u0_1[i,j1] + ut1[i,j1] + (if i in L2 then u2_1[i,j1] else 0) + (if i in L3 then u3_1[i,j1] else 0))*MS1[i,e1]
    - (sum{i in I} (u0_1[i,j1] + ut1[i,j1])*MS0_1[i,e1] + sum{j2 in L2}u2_1[j2,j1]*MS1[e1] + sum{j3 in L3}u3_1[j3,j1]*MS1[e1])
    + sum{from in EL[1] inter L1}transfer1[e1,from,j1]  # Transfers IN
    + newhire1[e1,j1]  # New hires
    = deficit1[e1,j1];

# Surplus can only come from existing locations with teams
s.t. SurplusLimit1{e1 in E[1], j1 in EL[1] inter L1}:
    surplus1[e1,j1] <= CNES1[e1,j1];


# # GLOBAL PROPORTIONALITY: 1 eMU for every 9 eSF
# # Total eMU must be sufficient to support all eSF (1 eMU per 9 eSF)
# s.t. Global_eMU_to_eSF_Ratio_EL:
#     sum{j1 in EL[1] inter L1}(
#         (if j1 in EL[1] then CNES1['eMU',j1] else 0)
#         + sum{from in EL[1] inter L1: from != j1}transfer1['eMU',from,j1] # Teams transferred IN
#         - sum{to in L1: to != j1}transfer1['eMU',j1,to] # Teams transferred OUT         
#         + newhire1['eMU',j1]
#     ) * RATIO_eSF_eMU
#     >=
#     sum{j1 in EL[1] inter L1}(
#         (if j1 in EL[1] then CNES1['eSF',j1] else 0)
#         + sum{from in EL[1] inter L1: from != j1}transfer1['eSF',from,j1]
#         - sum{to in L1: to != j1}transfer1['eSF',j1,to]        
#         + newhire1['eSF',j1]
#     );

# # For CANDIDATE locations: only new hires and transfers IN
# s.t. Global_eMU_to_eSF_Ratio_CL:
#     sum{j1 in CL[1] inter L1}(
#         (if j1 in EL[1] then CNES1['eMU',j1] else 0)
#         + sum{from in EL[1] inter L1: from != j1}transfer1['eMU',from,j1] # Teams transferred IN        
#         + newhire1['eMU',j1]
#     ) * RATIO_eSF_eMU
#     >=
#     sum{j1 in CL[1] inter L1}(
#         (if j1 in EL[1] then CNES1['eSF',j1] else 0)
#         + sum{from in EL[1] inter L1: from != j1}transfer1['eSF',from,j1]        
#         + newhire1['eSF',j1]
#     );



#################################################
# TEAM BALANCE CONSTRAINTS - LEVEL 2 (SHC)
#################################################
# CNES (existente) - Necessário + Transferências OUT - Transferências IN + Novas Contratações = Excesso - Déficit
s.t. TeamBalance2e{j2 in EL[2] inter L2, e2 in E[2]}:
    CNES2[e2,j2]
    - (sum{i in I}u0_2[i,j2] + sum{j1 in L1}u1_2[j1,j2] + sum{j3 in L3}u3_2[j3,j2] + sum{i in I} ut2[i,j2])*MS2[e2]
    + sum{from in EL[2] inter L2: from != j2}transfer2[e2,from,j2] # Teams transferred IN
    - sum{to in L2: to != j2}transfer2[e2,j2,to] # Teams transferred OUT    
    + newhire2[e2,j2]
    = surplus2[e2,j2] - deficit2[e2,j2];

s.t. TeamBalance2c{j2 in CL[2] inter L2, e2 in E[2]}:
    - (sum{i in I}u0_2[i,j2] + sum{j1 in L1}u1_2[j1,j2] + sum{j3 in L3}u3_2[j3,j2] + sum{i in I} ut2[i,j2])*MS2[e2]
    + sum{from in EL[2] inter L2}transfer2[e2,from,j2] # Teams transferred IN
    + newhire2[e2,j2]
    = deficit2[e2,j2];

s.t. SurplusLimit2{e2 in E[2], j2 in EL[2] inter L2}:
    surplus2[e2,j2] <= CNES2[e2,j2];

#################################################
# TEAM BALANCE CONSTRAINTS - LEVEL 3 (THC)
#################################################
# CNES (existente) - Necessário + Transferências OUT - Transferências IN + Novas Contratações = Excesso - Déficit
s.t. TeamBalance3e{j3 in EL[3] inter L3, e3 in E[3]}:
    CNES3[e3,j3]
    - (sum{i in I}u0_3[i,j3] + sum{j1 in L1}u1_3[j1,j3] + sum{j2 in L2}u2_3[j2,j3] + sum{i in I} ut3[i,j3])*MS3[e3]
    + sum{from in EL[3] inter L3: from != j3}transfer3[e3,from,j3] # Teams transferred IN
    - sum{to in L3: to != j3}transfer3[e3,j3,to] # Teams transferred OUT    
    + newhire3[e3,j3]
    = surplus3[e3,j3] - deficit3[e3,j3];

s.t. TeamBalance3c{j3 in CL[3] inter L3, e3 in E[3]}:
    - sum{j2 in L2}u2_3[j2,j3]*MS3[e3]
    + sum{from in EL[3] inter L3}transfer3[e3,from,j3] # Teams transferred IN
    + newhire3[e3,j3]
    = deficit3[e3,j3];

s.t. SurplusLimit3{e3 in E[3], j3 in EL[3] inter L3}:
    surplus3[e3,j3] <= CNES3[e3,j3];

#################################################
# CAPACITY CONSTRAINTS
#################################################

# Existing locations
# s.t. R6e{j1 in EL[1] inter L1}: sum{i in I}u0_1[i,j1] <= C1[j1];
# s.t. R7e{j2 in EL[2] inter L2}: sum{j1 in L1}u1_2[j1,j2] <= C2[j2];
# s.t. R8e{j3 in EL[3] inter L3}: sum{j2 in L2}u2_3[j2,j3] <= C3[j3];
s.t. R6e{j1 in EL[1] inter L1}: 
    sum{i in I}u0_1[i,j1]                   # Home → L1
    + sum{j2 in L2}u2_1[j2,j1]              # L2 → L1
    + sum{j3 in L3}u3_1[j3,j1]              # L3 → L1
    + sum{i in I} ut1[i,j1] <= C1[j1];

s.t. R7e{j2 in EL[2] inter L2}: 
    sum{i in I}u0_2[i,j2] 
    + sum{j1 in L1}u1_2[j1,j2] 
    + sum{j3 in L3}u3_2[j3,j2]
    + sum{i in I} ut2[i,j2] <= C2[j2];

s.t. R8e{j3 in EL[3] inter L3}: 
    sum{i in I} u0_3[i,j3] 
    + sum{j1 in L1}u1_3[j1,j3] 
    + sum{j2 in L2}u2_3[j2,j3]
    + sum{i in I} ut3[i,j3] <= C3[j3];

s.t. R9e{j1 in EL[1] inter L1}: 
    sum{i in I}u1_0[j1,i]                   # L1 → Home
    + sum{j2 in L2}u1_2[j1,j2]              # L1 → L2
    + sum{j3 in L3}u1_3[j1,j3] <= C1[j1];   # L1 → L3

s.t. R10e{j2 in EL[2] inter L2}: 
    sum{i in I}u2_0[j2,i]                   # L2 → Home
    + sum{j1 in L1}u2_1[j2,j1]              # L2 → L1
    + sum{j3 in L3}u2_3[j2,j3] <= C2[j2];   # L2 → L3

s.t. R11e{j3 in EL[3] inter L3}: 
    sum{i in I}u3_0[j3,i]                   # L3 → Home
    + sum{j1 in L1}u3_1[j3,j1]              # L3 → L1
    + sum{j2 in L2}u3_2[j3,j2] <= C3[j3];   # L3 → L2
     

# Candidate locations (activated only if used)
# s.t. R6c{j1 in L1}: sum{i in I}u0_1[i,j1] <= C1[j1]*y1[j1];
# s.t. R7c{j2 in L2}: sum{j1 in L1}u1_2[j1,j2] <= C2[j2]*y2[j2];
# s.t. R8c{j3 in L3}: sum{j2 in L2}u2_3[j2,j3] <= C3[j3]*y3[j3];
s.t. R6c{j1 in CL[1] inter L1}: 
    sum{i in I}u0_1[i,j1]                   # Home → L1
    + sum{j2 in L2}u2_1[j2,j1]              # L2 → L1
    + sum{j3 in L3}u3_1[j3,j1]              # L3 → L1
    + sum{i in I} ut1[i,j1] <= C1[j1]*y1[j1];
s.t. R7c{j2 in CL[2] inter L2}: 
    sum{i in I}u0_2[i,j2] 
    + sum{j1 in L1}u1_2[j1,j2] 
    + sum{j3 in L3}u3_2[j3,j2]
    + sum{i in I} ut2[i,j2] <= C2[j2]*y2[j2];
s.t. R8c{j3 in CL[3] inter L3}: 
    sum{i in I} u0_3[i,j3] 
    + sum{j1 in L1}u1_3[j1,j3] 
    + sum{j2 in L2}u2_3[j2,j3]
    + sum{i in I} ut3[i,j3] <= C3[j3]*y3[j3];

s.t. R9c{j1 in CL[1] inter L1}: 
    sum{i in I}u1_0[j1,i]                   # L1 → Home
    + sum{j2 in L2}u1_2[j1,j2]              # L1 → L2
    + sum{j3 in L3}u1_3[j1,j3] <= C1[j1]*y1[j1];   # L1 → L3

s.t. R10c{j2 in CL[2] inter L2}: 
    sum{i in I}u2_0[j2,i]                   # L2 → Home
    + sum{j1 in L1}u2_1[j2,j1]              # L2 → L1
    + sum{j3 in L3}u2_3[j2,j3] <= C2[j2]*y2[j2];   # L2 → L3

s.t. R11c{j3 in CL[3] inter L3}: 
    sum{i in I}u3_0[j3,i]                   # L3 → Home
    + sum{j1 in L1}u3_1[j3,j1]              # L3 → L1
    + sum{j2 in L2}u3_2[j3,j2] <= C3[j3]*y3[j3];   # L3 → L2

# Budget-adjusted maximum new facilities
s.t. R12c:  sum{j1 in CL[1] inter L1}y1[j1] <= MaxNewPHC;
s.t. R13c: sum{j2 in CL[2] inter L2}y2[j2] <= MaxNewSHC;
s.t. R14c: sum{j3 in CL[3] inter L3}y3[j3] <= MaxNewTHC;

s.t. APSCost: Total_Costs_APS = 
    # Existing facilities cost
    sum{j1 in EL[1] inter L1}FC1[j1]*y1[j1] 
    + sum{j2 in EL[2] inter L2}FC2[j2]*y2[j2] 
    + sum{j3 in EL[3] inter L3}FC3[j3]*y3[j3]
    # New facilities fixed cost    
    + sum{j1 in CL[1] inter L1}(FC1[j1]+IA1[j1])*y1[j1] 
    + sum{j2 in CL[2] inter L2}(FC2[j2]+IA2[j2])*y2[j2] 
    + sum{j3 in CL[3] inter L3}(FC3[j3]+IA3[j3])*y3[j3]
    # New staff cost
    + sum{j1 in L1, c1 in E[1]}CE1[c1]*newhire1[c1,j1] 
    + sum{j2 in L2, c2 in E[2]}CE2[c2]*newhire2[c2,j2] 
    + sum{j3 in L3, c3 in E[3]}CE3[c3]*newhire3[c3,j3]
    # Variable costs
    + sum{j1 in L1}VC1[j1]*(sum{i in I}u0_1[i,j1]                   # Home → L1
    + sum{j2 in L2}u2_1[j2,j1]              # L2 → L1
    + sum{j3 in L3}u3_1[j3,j1]              # L3 → L1
    + sum{i in I} ut1[i,j1])                # Telehealth in L1
    + sum{j2 in L2}VC2[j2]*(sum{i in I}u0_2[i,j2] 
    + sum{j1 in L1}u1_2[j1,j2] 
    + sum{j3 in L3}u3_2[j3,j2]
    + sum{i in I} ut2[i,j2])
    + sum{j3 in L3}VC3[j3]*(sum{i in I} u0_3[i,j3] 
    + sum{j1 in L1}u1_3[j1,j3] 
    + sum{j2 in L2}u2_3[j2,j3]
    + sum{i in I} ut3[i,j3])
    # # Transportation costs
    # + sum{i in I, j1 in L1}D0_1[i,j1]*TC1[i,j1]*u0_1[i,j1] 
    # + sum{j1 in L1, j2 in L2}D1_2[j1,j2]*TC2[j1,j2]*u1_2[j1,j2]  
    # + sum{j2 in L2, j3 in L3}D2_3[j2,j3]*TC3[j2,j3]*u2_3[j2,j3]
    # Re-assignment costs
    + sum{e1 in E[1], from in EL[1] inter L1, to in L1: from != to}
         RC1[e1]*DL1[from,to]*transfer1[e1,from,to]
    + sum{e2 in E[2], from in EL[2] inter L2, to in L2: from != to}
         RC2[e2]*DL2[from,to]*transfer2[e2,from,to]
    + sum{e3 in E[3], from in EL[3] inter L3, to in L3: from != to}
         RC3[e3]*DL3[from,to]*transfer3[e3,from,to];
    # # Penalty for surplus or deficit
    # + sum{e1 in E[1], j1 in EL[1]}CE1[e1]*surplus1[e1,j1] 
    # + sum{e2 in E[2], j2 in EL[2]}CE2[e2]*surplus2[e2,j2] 
    # + sum{e3 in E[3], j3 in EL[3]}CE3[e3]*surplus3[e3,j3] 
    # + sum{e1 in E[1], j1 in L1}CE1[e1]*deficit1[e1,j1] 
    # + sum{e2 in E[2], j2 in L2}CE2[e2]*deficit2[e2,j2] 
    # + sum{e3 in E[3], j3 in L3}CE3[e3]*deficit3[e3,j3]

# Overall budget constraint
s.t. APSBudgetConstraint:  Total_Costs_APS <= BUDGET;

#################################################
# OBJECTIVE FUNCTION
#################################################

minimize Total_Costs:
    # Patient transportation cost
      sum{i in I, j1 in L1}TC0_1[i,j1]*u0_1[i,j1] 
    + sum{i in I, j2 in L2}TC0_2[i,j2]*u0_2[i,j2] 
    + sum{i in I, j3 in L3}TC0_3[i,j3]*u0_3[i,j3]     
    + sum{j1 in L1, j2 in L2}TC1_2[j1,j2]*u1_2[j1,j2]  
    + sum{j1 in L1, j3 in L3}TC1_3[j1,j3]*u1_3[j1,j3]  
    + sum{j2 in L2, j3 in L3}TC2_3[j2,j3]*u2_3[j2,j3] 
    # Cost of existing units
    + sum{j1 in EL[1] inter L1}FC1[j1]*y1[j1] 
    + sum{j2 in EL[2] inter L2}FC2[j2]*y2[j2] 
    + sum{j3 in EL[3] inter L3}FC3[j3]*y3[j3]
    # New unit cost
    + sum{j1 in CL[1] inter L1}(FC1[j1]+IA1[j1])*y1[j1] 
    + sum{j2 in CL[2] inter L2}(FC2[j2]+IA2[j2])*y2[j2] 
    + sum{j3 in CL[3] inter L3}(FC3[j3]+IA3[j3])*y3[j3]    
    # Cost of NEW teams hired
    + sum{j1 in L1, c1 in E[1]}CE1[c1]*newhire1[c1,j1] 
    + sum{j2 in L2, c2 in E[2]}CE2[c2]*newhire2[c2,j2] 
    + sum{j3 in L3, c3 in E[3]}CE3[c3]*newhire3[c3,j3]
    # Team relocation costs
    + sum{e1 in E[1], from in EL[1] inter L1, to in L1: from != to}
         RC1[e1]*DL1[from,to]*transfer1[e1,from,to]
    + sum{e2 in E[2], from in EL[2] inter L2, to in L2: from != to}
         RC2[e2]*DL2[from,to]*transfer2[e2,from,to]
    + sum{e3 in E[3], from in EL[3] inter L3, to in L3: from != to}
         RC3[e3]*DL3[from,to]*transfer3[e3,from,to]    
    # Penalty for surplus or deficit
    + sum{e1 in E[1], j1 in EL[1]}10*CE1[e1]*surplus1[e1,j1] 
    + sum{e2 in E[2], j2 in EL[2]}10*CE2[e2]*surplus2[e2,j2] 
    + sum{e3 in E[3], j3 in EL[3]}10*CE3[e3]*surplus3[e3,j3] 
    + sum{e1 in E[1], j1 in L1}10*CE1[e1]*deficit1[e1,j1] 
    + sum{e2 in E[2], j2 in L2}10*CE2[e2]*deficit2[e2,j2] 
    + sum{e3 in E[3], j3 in L3}10*CE3[e3]*deficit3[e3,j3] 
    # Variable cost per patient
    + sum{j1 in L1}VC1[j1]*(sum{i in I}u0_1[i,j1]  # Home → L1
    + sum{j2 in L2}u2_1[j2,j1]              # L2 → L1
    + sum{j3 in L3}u3_1[j3,j1]              # L3 → L1
    + sum{i in I} ut1[i,j1])                # Telehealth in L1
    + sum{j2 in L2}VC2[j2]*(sum{i in I}u0_2[i,j2] # Home → L2
    + sum{j1 in L1}u1_2[j1,j2]              # L1 → L2
    + sum{j3 in L3}u3_2[j3,j2]              # L3 → L2
    + sum{i in I} ut2[i,j2])                # Telehealth in L2
    + sum{j3 in L3}VC3[j3]*(sum{i in I} u0_3[i,j3] # Home → L3
    + sum{j1 in L1}u1_3[j1,j3]              # L1 → L3
    + sum{j2 in L2}u2_3[j2,j3]              # L2 → L2
    + sum{i in I} ut3[i,j3])                # Telehealth in L3
    ;

solve;
#################################################
# OUTPUT REPORTS
#################################################

printf: "\n========================================\n";
printf: "Health Care Plan with Team Reallocation\n";
printf: "========================================\n";
printf: "Logist cost:\t\t$%10.2f\n", 
      sum{i in I, j1 in L1}TC0_1[i,j1]*u0_1[i,j1] 
    + sum{i in I, j2 in L2}TC0_2[i,j2]*u0_2[i,j2] 
    + sum{i in I, j3 in L3}TC0_3[i,j3]*u0_3[i,j3]     
    + sum{j1 in L1, j2 in L2}TC1_2[j1,j2]*u1_2[j1,j2]  
    + sum{j1 in L1, j3 in L3}TC1_3[j1,j3]*u1_3[j1,j3]  
    + sum{j2 in L2, j3 in L3}TC2_3[j2,j3]*u2_3[j2,j3];
printf: "Fixed cost [Existing]:\t$%10.2f\n", 
      sum{j1 in EL[1] inter L1}FC1[j1]*y1[j1] 
    + sum{j2 in EL[2] inter L2}FC2[j2]*y2[j2] 
    + sum{j3 in EL[3] inter L3}FC3[j3]*y3[j3];
printf: "Fixed cost [Candidate]:\t$%10.2f\n", 
      sum{j1 in CL[1] inter L1}(FC1[j1]+IA1[j1])*y1[j1] 
    + sum{j2 in CL[2] inter L2}(FC2[j2]+IA2[j2])*y2[j2] 
    + sum{j3 in CL[3] inter L3}(FC3[j3]+IA3[j3])*y3[j3];
printf: "New team cost:\t\t$%10.2f\n", 
      sum{j1 in L1, c1 in E[1]}CE1[c1]*newhire1[c1,j1] 
    + sum{j2 in L2, c2 in E[2]}CE2[c2]*newhire2[c2,j2] 
    + sum{j3 in L3, c3 in E[3]}CE3[c3]*newhire3[c3,j3];
printf: "Team relocation cost:\t$%10.2f\n",
      sum{e1 in E[1], from in EL[1] inter L1, to in L1: from != to}
         RC1[e1]*DL1[from,to]*transfer1[e1,from,to]
    + sum{e2 in E[2], from in EL[2] inter L2, to in L2: from != to}
         RC2[e2]*DL2[from,to]*transfer2[e2,from,to]
    + sum{e3 in E[3], from in EL[3] inter L3, to in L3: from != to}
         RC3[e3]*DL3[from,to]*transfer3[e3,from,to];
printf: "Variable Cost:\t\t$%10.2f\n", 
      sum{i in I, j1 in L1}VC1[j1]*u0_1[i,j1] 
    + sum{j1 in L1, j2 in L2}VC2[j2]*u1_2[j1,j2]  
    + sum{j2 in L2, j3 in L3}VC3[j3]*u2_3[j2,j3];
printf: "========================================\n";
printf: "Total     Cost:\t\t$%10.2f\n", Total_Costs;
printf: "Total APS Cost:\t\t$%10.2f\n", Total_Costs_APS;
printf: "Budget Limit:\t\t$%10.2f\n", BUDGET;
printf: "Budget Usage:\t\t%.2f%%\n", (Total_Costs_APS/BUDGET)*100;
printf: "========================================\n";
printf: "New Units:\tQty\tMax\tUse (%%)\n"; 
printf: "========================================\n";
printf: "PHC      :\t%d\t%d\t%.2f%%\n", 
sum{j1 in CL[1] inter L1}y1[j1],
MaxNewPHC, 
if MaxNewPHC > 0 then ((sum{j1 in CL[1] inter L1}y1[j1])/(MaxNewPHC))*100 else 0; 
printf: "SHC      :\t%d\t%d\t%.2f%%\n", 
sum{j2 in CL[2] inter L2}y2[j2],
MaxNewSHC, 
if MaxNewSHC > 0 then ((sum{j2 in CL[2] inter L2}y2[j2])/(MaxNewSHC))*100 else 0; 
printf: "THC      :\t%d\t%d\t%.2f%%\n", 
sum{j3 in CL[3] inter L3}y3[j3],
MaxNewTHC, 
if MaxNewTHC > 0 then ((sum{j3 in CL[3] inter L3}y3[j3])/(MaxNewTHC))*100 else 0; 
printf: "========================================\n";

printf: "\n========================================\n";
printf: "TEAM REALLOCATION SUMMARY\n";
printf: "========================================\n";

# PHC Team Transfers
printf: "\nPHC Team Transfers:\n";
printf: "From\t> To\t\tTeam\tQty\tDist\n";
printf: "================================================\n";
for{e1 in E[1], from in EL[1] inter L1, to in L1: from != to and transfer1[e1,from,to] > 0.01}{
    printf: "[%-4s]\t> [%-4s]\t%-4s\t%.2f\t%.0f\n", 
        from, to, e1, transfer1[e1,from,to], DL1[from,to];
}

# SHC Team Transfers
printf: "\nSHC Team Transfers:\n";
printf: "From\t> To\t\tTeam\tQty\tDist\n";
printf: "================================================\n";
for{e2 in E[2], from in EL[2] inter L2, to in L2: from != to and transfer2[e2,from,to] > 0.01}{
    printf: "[%-4s]\t> [%-4s]\t%-4s\t%.2f\t%.0f\n", 
        from, to, e2, transfer2[e2,from,to], DL2[from,to];
}

# THC Team Transfers
printf: "\nTHC Team Transfers:\n";
printf: "From\t> To\t\tTeam\tQty\tDist\n";
printf: "================================================\n";
for{e3 in E[3], from in EL[3] inter L3, to in L3: from != to and transfer3[e3,from,to] > 0.01}{
    printf: "[%-4s]\t> [%-4s]\t%-4s\t%.2f\t%.0f\n", 
        from, to, e3, transfer3[e3,from,to], DL3[from,to];
}

printf: "\n================================================\n";
printf: "NEW TEAMS HIRED\n";
printf: "================================================\n";
printf: "\nPHC New Hires:\n";
printf: "Location\tTeam\tQty\n";
printf: "================================================\n";
for{j1 in L1, e1 in E[1]: newhire1[e1,j1] > 0.01}{
    printf: "[%-5s]%s\t%-4s\t%.2f\n", 
        j1, 
        if j1 in CL[1] then "*" else " ",
        e1, 
        newhire1[e1,j1];
}

printf: "\nSHC New Hires:\n";
printf: "Location\tTeam\tQty\n";
printf: "================================================\n";
for{j2 in L2, e2 in E[2]: newhire2[e2,j2] > 0.01}{
    printf: "[%-5s]%s\t%-4s\t%.2f\n", 
        j2,
        if j2 in CL[2] then "*" else " ",
        e2, 
        newhire2[e2,j2];
}

printf: "\nTHC New Hires:\n";
printf: "Location\tTeam\tQty\n";
printf: "================================================\n";
for{j3 in L3, e3 in E[3]: newhire3[e3,j3] > 0.01}{
    printf: "[%-5s]%s\t%-4s\t%.2f\n", 
        j3,
        if j3 in CL[3] then "*" else " ",
        e3, 
        newhire3[e3,j3];
}

printf: "\n========================================\n";
printf: "TEAM BALANCE PER LOCATION\n";
printf: "========================================\n";

printf: "\nPHC Locations:\n";
printf: "Loc\t\tTeam\tCNES\tReq'd\tTransf\tNew\tSurp\tDef\n";
printf: "======================================================================\n";

for{j1 in L1: sum{i in I}u0_1[i,j1] > 0}{
    for{e1 in E[1]}{
        printf: "[%-5s]%s\t%-4s\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\n",
            j1,
            if j1 in CL[1] then "*" else " ",
            e1,
            if j1 in EL[1] then CNES1[e1,j1] else 0,
            # sum{i in I}u0_1[i,j1]*MS1[e1],
            # (sum{i in I}u0_1[i,j1] + sum{j2 in L2}u2_1[j2,j1] + sum{j3 in L3}u3_1[j3,j1] + sum{i in I} ut1[i,j1])*MS1[i,e1],
            # sum{i in I} (u0_1[i,j1] + ut1[i,j1] + (if i in L2 then u2_1[i,j1] else 0) + (if i in L3 then u3_1[i,j1] else 0))*MS1[i,e1],
            (sum{i in I} (u0_1[i,j1] + ut1[i,j1])*MS0_1[i,e1] + sum{j2 in L2}u2_1[j2,j1]*MS1[e1] + sum{j3 in L3}u3_1[j3,j1]*MS1[e1]),
            sum{from in EL[1] inter L1: from != j1}transfer1[e1,from,j1] # Transfers IN
            - (if j1 in EL[1] then sum{to in L1: to != j1}transfer1[e1,j1,to] else 0), # Teams transferred OUT            
            newhire1[e1,j1],
            if j1 in EL[1] then surplus1[e1,j1] else 0,
            deficit1[e1,j1];
    }
}

param Req{j1 in L1, e1 in E[1]} :=
    (sum{i in I} (u0_1[i,j1] + ut1[i,j1]) * MS0_1[i,e1])
  + (sum{j2 in L2} u2_1[j2,j1] * MS1[e1])
  + (sum{j3 in L3} u3_1[j3,j1] * MS1[e1]);

param ReqTotal{e1 in E[1]} :=
    sum{j1 in L1: sum{i in I}u0_1[i,j1] > 0} Req[j1,e1];

printf: "\n======================================================================\n";
printf: "FINAL TOTAL REQUIRED TEAMS PER CATEGORY\n";
printf: "======================================================================\n";

for{e1 in E[1]}{
    printf: "%-4s: %.2f teams\n", e1, ReqTotal[e1];
}
printf: "======================================================================\n";

# # Print eMU summary first (global)
# printf: "[GLOBAL]\t%-4s*\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\n",
#     'eMU',
#     sum{j1 in EL[1] inter L1}CNES1['eMU',j1],
#     ceil((sum{j1 in EL[1] inter L1}(
#         (if j1 in EL[1] then CNES1['eSF',j1] else 0)
#         + sum{from in EL[1] inter L1: from != j1}transfer1['eSF',from,j1] # Transfers IN
#         - sum{to in L1: to != j1}transfer1['eSF',j1,to] # Teams transferred OUT        
#         + newhire1['eSF',j1]
#     )) / RATIO_eSF_eMU),
#     # For CANDIDATE locations: only new hires and transfers IN
#     ceil((sum{j1 in CL[1] inter L1}(        
#         + sum{from in EL[1] inter L1: from != j1}transfer1['eSF',from,j1] # Transfers IN        
#         + newhire1['eSF',j1]
#     )) / RATIO_eSF_eMU),
#     sum{from in EL[1] inter L1, to in L1: from != to}transfer1['eMU',from,to], # Teams transferred OUT 
#     sum{j1 in L1}newhire1['eMU',j1],
#     sum{j1 in EL[1] inter L1}surplus1['eMU',j1],
#     sum{j1 in L1}deficit1['eMU',j1];

# # Print individual PHC locations (excluding eMU)
# for{j1 in L1: sum{i in I}u0_1[i,j1] > 0}{
#     for{e1 in E[1]: e1 != 'eMU'}{
#         printf: "[%-5s]%s\t%-4s\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\n",
#             j1,
#             if j1 in CL[1] then "*" else " ",
#             e1,
#             if j1 in EL[1] then CNES1[e1,j1] else 0,
#             (sum{i in I}u0_1[i,j1] + sum{j2 in L2}u2_1[j2,j1] + sum{j3 in L3}u3_1[j3,j1] + sum{i in I} ut1[i,j1])*MS1[e1],
#             sum{from in EL[1] inter L1: from != j1}transfer1[e1,from,j1] 
#             - (if j1 in EL[1] then sum{to in L1: to != j1}transfer1[e1,j1,to] else 0),
#             newhire1[e1,j1],
#             if j1 in EL[1] then surplus1[e1,j1] else 0,
#             deficit1[e1,j1];
#     }
# }



printf: "\nSHC Locations:\n";
printf: "Loc\t\tTeam\tCNES\tReq'd\tTransf\tNew\tSurp\tDef\n";
printf: "======================================================================\n";
for{j2 in L2: sum{j1 in L1}u1_2[j1,j2] > 0}{
    for{e2 in E[2]}{
        printf: "[%-5s]%s\t%-4s\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\n",
            j2,
            if j2 in CL[2] then "*" else " ",
            e2,
            if j2 in EL[2] then CNES2[e2,j2] else 0,
            # sum{j1 in L1}u1_2[j1,j2]*MS2[e2],
            (sum{i in I}u0_2[i,j2] + sum{j1 in L1}u1_2[j1,j2] + sum{j3 in L3}u3_2[j3,j2] + sum{i in I} ut2[i,j2])*MS2[e2],
            sum{from in EL[2] inter L2: from != j2}transfer2[e2,from,j2] # Transfers IN
            - (if j2 in EL[2] then sum{to in L2: to != j2}transfer2[e2,j2,to] else 0), # Teams transferred OUT            
            newhire2[e2,j2],
            if j2 in EL[2] then surplus2[e2,j2] else 0,
            deficit2[e2,j2];
    }
}

printf: "\nTHC Locations:\n";
printf: "Loc\t\tTeam\tCNES\tReq'd\tTransf\tNew\tSurp\tDef\n";
printf: "======================================================================\n";
for{j3 in L3: sum{j2 in L2}u2_3[j2,j3] > 0}{
    for{e3 in E[3]}{
        printf: "[%-5s]%s\t%-4s\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\n",
            j3,
            if j3 in CL[3] then "*" else " ",
            e3,
            if j3 in EL[3] then CNES3[e3,j3] else 0,
            # sum{j2 in L2}u2_3[j2,j3]*MS3[e3],
            (sum{i in I}u0_3[i,j3] + sum{j1 in L1}u1_3[j1,j3] + sum{j2 in L2}u2_3[j2,j3] + sum{i in I} ut3[i,j3])*MS3[e3],
            sum{from in EL[3] inter L3: from != j3}transfer3[e3,from,j3] # Transfers IN
            - (if j3 in EL[3] then sum{to in L3: to != j3}transfer3[e3,j3,to] else 0), # Teams transferred OUT            
            newhire3[e3,j3],
            if j3 in EL[3] then surplus3[e3,j3] else 0,
            deficit3[e3,j3];
    }
}

printf: "\n========================================\n";
printf: "Region:\t\t  Pop\t Flow\n"; 
printf: "========================================\n";
printf{i in I}: "[%-14s]: %d\t %d\n", i, 
W[i], 
sum{j1 in L1}u0_1[i,j1] 
+ sum{j2 in L2} u0_2[i,j2]
+ sum{j3 in L3} u0_3[i,j3]
+ sum{j1 in L1} ut1[i,j1]
+ sum{j2 in L2} ut2[i,j2]
+ sum{j3 in L3} ut3[i,j3];

printf: "========================================\n";
printf: "Reg     > PHC + SHC + THC  :(flow)\n";
printf: "========================================\n";
for{i in I}{
    # PHC
    printf "M[%-4d] > \t : %d\n", i, W[i];
    for{j1 in L1: u0_1[i,j1] > 0}{
    printf "\t> L[%-4s]: %d\n", j1, u0_1[i,j1];}
    for{j1 in L1: ut1[i,j1] > 0}{
    printf "\t> L[%-4s]*: %d\n", j1, ut1[i,j1];} 
    # SHC
    for{j2 in L2: u0_2[i,j2] > 0}{
    printf "\t> L[%-4s]: %d\n", j2, u0_2[i,j2];}
    for{j2 in L2: ut2[i,j2] > 0}{
    printf "\t> L[%-4s]*: %d\n", j2, ut2[i,j2];}    
    # THC
    for{j3 in L3: u0_3[i,j3] > 0}{
    printf "\t> L[%-4s]: %d\n", j3, u0_3[i,j3];}
    for{j3 in L3: ut3[i,j3] > 0}{
    printf "\t> L[%-4s]*: %d\n", j3, ut3[i,j3];}    
}

printf: "========================================\n";
printf: "PHC     > Reg + SHC + THC  :(flow)\n";
printf: "========================================\n";
for{j1 in L1: (sum{i in I}u0_1[i,j1] + sum{j2 in L2}u2_1[j2,j1]+ sum{j3 in L3}u3_1[j3,j1] + sum{i in I} ut1[i,j1]) > 0}{
    printf"L[%-4s] > \t : %d\t(%d + %d + %d)\n", 
        j1, 
        sum{i in I}(u0_1[i,j1] + ut1[i,j1])
        + sum{j2 in L2}u2_1[j2,j1]
        + sum{j3 in L3}u3_1[j3,j1],
        sum{i in I}(u0_1[i,j1]+ ut1[i,j1]), sum{j2 in L2}u2_1[j2,j1], sum{j3 in L3}u3_1[j3,j1];
    # Reg
    for{i in I: u1_0[j1,i] > 0}{
    printf"\t> L[%-4s]: %d\n", i, u1_0[j1,i];} # O1_0[j1]*
    # SHC
    for{j2 in L2: u1_2[j1,j2] > 0}{
    printf"\t> L[%-4s]: %d\n", j2, u1_2[j1,j2];} # O1_2[j1]*
    # THC
    for{j3 in L3: u1_3[j1,j3] > 0}{
    printf"\t> L[%-4s]: %d\n", j3, u1_3[j1,j3];} # O1_3[j1]*
}

printf: "========================================\n";
printf: "SHC     > Reg + PHC + THC  :(flow)\n";
printf: "========================================\n";
for{j2 in L2: (sum{i in I}u0_2[i,j2] + sum{j1 in L1}u1_2[j1,j2] + sum{j3 in L3}u3_2[j3,j2]+ sum{i in I} ut2[i,j2])>0}{
    printf: "L[%-4s] > \t : %d\t(%d + %d + %d)\n", 
        j2, 
        sum{i in I}(u0_2[i,j2] + ut2[i,j2])
        + sum{j1 in L1}u1_2[j1,j2] 
        + sum{j3 in L3}u3_2[j3,j2], 
        sum{i in I}(u0_2[i,j2] + ut2[i,j2]), sum{j1 in L1}u1_2[j1,j2], sum{j3 in L3}u3_2[j3,j2];
    # Reg
    for{i in I: u2_0[j2,i] > 0}{
    printf"\t> L[%-4s]: %d\n", i, u2_0[j2,i];} 
    # PHC
    for{j1 in L1: u2_1[j2,j1] > 0}{
    printf"\t> L[%-4s]: %d\n", j1, u2_1[j2,j1];}
    # THC
    for{j3 in L3: u2_3[j2,j3] > 0}{
    printf"\t> L[%-4s]: %d\n", j3, u2_3[j2,j3];}
}

printf: "========================================\n";
printf: "THC     > Reg + PHC + SHC  :(flow)\n";
printf: "========================================\n";
for{j3 in L3: (sum{i in I}u0_3[i,j3] + sum{j1 in L1}u1_3[j1,j3] + sum{j2 in L2}u2_3[j2,j3]+ sum{i in I} ut3[i,j3])>0}{
    printf: "L[%-4s] > \t : %d\t(%d + %d + %d)\n", 
        j3, 
        sum{i in I}(u0_3[i,j3] + ut3[i,j3])
        + sum{j1 in L1}u1_3[j1,j3] 
        + sum{j2 in L2}u2_3[j2,j3], 
        sum{i in I}(u0_3[i,j3] + ut3[i,j3]), sum{j1 in L1}u1_3[j1,j3], sum{j2 in L2}u2_3[j2,j3];
    # Reg
    for{i in I: u3_0[j3,i] > 0}{
    printf"\t> L[%-4s]: %d\n", i, u3_0[j3,i];} 
    # PHC
    for{j1 in L1: u3_1[j3,j1] > 0}{
    printf"\t> L[%-4s]: %d\n", j1, u3_1[j3,j1];}
    # SHC
    for{j2 in L2: u3_2[j3,j2] > 0}{
    printf"\t> L[%-4s]: %d\n", j2, u3_2[j3,j2];}
}

printf: "========================================\n";
printf: "PHC     :\tCapty\tMet\tUse(%%)\n";
printf: "========================================\n";
printf{j1 in EL[1] inter L1}: 
"[%-5s]:\t%d\t%d\t%3d%%\n", j1,  
C1[j1], 
(sum{i in I}(u0_1[i,j1]+ ut1[i,j1]) + sum{j2 in L2}u2_1[j2,j1] + sum{j3 in L3}u3_1[j3,j1]),
if C1[j1] > 0 then ((sum{i in I}(u0_1[i,j1]+ ut1[i,j1]) + sum{j2 in L2}u2_1[j2,j1] + sum{j3 in L3}u3_1[j3,j1])/(C1[j1]))*100 else 0;
printf{j1 in CL[1] inter L1: (sum{i in I}(u0_1[i,j1]+ ut1[i,j1]) + sum{j2 in L2}u2_1[j2,j1] + sum{j3 in L3}u3_1[j3,j1])>0}: 
"[%-5s*]:\t%d\t%d\t%3d%%\n", j1, 
C1[j1], 
(sum{i in I}(u0_1[i,j1]+ ut1[i,j1]) + sum{j2 in L2}u2_1[j2,j1] + sum{j3 in L3}u3_1[j3,j1]),
if C1[j1] > 0 then ((sum{i in I}(u0_1[i,j1]+ ut1[i,j1]) + sum{j2 in L2}u2_1[j2,j1] + sum{j3 in L3}u3_1[j3,j1])/(C1[j1]))*100 else 0;

printf: "========================================\n";
printf: "SHC     :\tCapty\tMet\tUse(%%)\n";
printf: "========================================\n";
printf{j2 in EL[2] inter L2}: "[%-6s]:\t%d\t%d\t%3d%%\n", j2, 
C2[j2], 
(sum{i in I}(u0_2[i,j2] + ut2[i,j2]) + sum{j1 in L1}u1_2[j1,j2] + sum{j3 in L3}u3_2[j3,j2]),
if C2[j2] > 0 then ((sum{i in I}(u0_2[i,j2] + ut2[i,j2]) + sum{j1 in L1}u1_2[j1,j2] + sum{j3 in L3}u3_2[j3,j2])/(C2[j2]))*100 else 0;
printf{j2 in CL[2] inter L2: (sum{i in I}(u0_2[i,j2] + ut2[i,j2]) + sum{j1 in L1}u1_2[j1,j2] + sum{j3 in L3}u3_2[j3,j2])>0}: 
"[%-5s*]:\t%d\t%d\t%3d%%\n", j2, 
C2[j2], 
(sum{i in I}(u0_2[i,j2] + ut2[i,j2]) + sum{j1 in L1}u1_2[j1,j2] + sum{j3 in L3}u3_2[j3,j2]),
if C2[j2] > 0 then ((sum{i in I}(u0_2[i,j2] + ut2[i,j2]) + sum{j1 in L1}u1_2[j1,j2] + sum{j3 in L3}u3_2[j3,j2])/(C2[j2]))*100 else 0;

printf: "========================================\n";
printf: "THC     :\tCapty\tMet\tUse(%%)\n";
printf: "========================================\n";
printf{j3 in EL[3] inter L3}: "[%-6s]:\t%d\t%d\t%3d%%\n", j3, 
C3[j3], 
(sum{i in I}(u0_3[i,j3] + ut3[i,j3]) + sum{j1 in L1}u1_3[j1,j3] + sum{j2 in L2}u2_3[j2,j3]),
if C3[j3] > 0 then ((sum{i in I}(u0_3[i,j3] + ut3[i,j3]) + sum{j1 in L1}u1_3[j1,j3] + sum{j2 in L2}u2_3[j2,j3])/(C3[j3]))*100 else 0;
printf{j3 in CL[3] inter L3: (sum{i in I}(u0_3[i,j3] + ut3[i,j3]) + sum{j1 in L1}u1_3[j1,j3] + sum{j2 in L2}u2_3[j2,j3])>0}: 
"[%-5s*]:\t%d\t%d\t%3d%%\n", j3, 
C3[j3], 
(sum{i in I}(u0_3[i,j3] + ut3[i,j3]) + sum{j1 in L1}u1_3[j1,j3] + sum{j2 in L2}u2_3[j2,j3]),
if C3[j3] > 0 then ((sum{i in I}(u0_3[i,j3] + ut3[i,j3]) + sum{j1 in L1}u1_3[j1,j3] + sum{j2 in L2}u2_3[j2,j3])/(C3[j3]))*100 else 0;
printf: "========================================\n\n";

# display{e1 in E[1], from in EL[1] inter L1, to in L1: from != to and transfer1[e1,from,to] > 0} transfer1[e1,from,to];

printf: "==========================================================="; 
printf: "===========================================================\n";

# printf:"\n\nRelatorio gerado em: %s\t\n",time;
# printf:"Desenvolvimento: Joao Flavio de F. Almeida\t\n";

# display{i in I, j1 in L1: y0_1[i,j1]>0}: y0_1[i,j1];
# display{i in I, j2 in L2: y0_2[i,j2]>0}: y0_2[i,j2];
# display{i in I, j3 in L3: y0_3[i,j3]>0}: y0_3[i,j3];

# display{i in I, j1 in L1: u0_1[i,j1]>0}: u0_1[i,j1];
# display{i in I, j1 in L1: ut1[i,j1]>0}: ut1[i,j1];

# display{i in I, j2 in L2: u0_2[i,j2]>0}: u0_2[i,j2];
# display{i in I, j2 in L2: ut2[i,j2]>0}: ut2[i,j2];

# display{i in I, j3 in L3: u0_3[i,j3]>0}: u0_3[i,j3];
# display{i in I, j3 in L3: ut3[i,j3]>0}: ut3[i,j3];


# display{j1 in L1, i in I: u1_0[j1,i]>0}: u1_0[j1,i];
# display{j1 in L1: y1[j1] > 0}: y1[j1];

# display{j2 in L2, i in I: u2_0[j2,i]>0}: u2_0[j2,i];
# display{j3 in L3, i in I: u3_0[j3,i]>0}: u3_0[j3,i];

display y3;
end;

