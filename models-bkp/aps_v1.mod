#############################################################################
# Project CNPq: Increasing PHC with team sizing
# Author: João Flávio de Freitas Almeida <joao.flavio@dep.ufmg.br>
# LEPOINT: Laboratório de Estudos em Planejamento de Operações Integradas
# Departmento de Engenharia de Produção
# Universidade Federal de Minas Gerais - Escola de Engenharia
#############################################################################
# Health Care Facility Location Problem: Considering fixed facilities, 
# choose intermediate facilities according to a criteria that improve service
# quality. Consider health care teams. 
# >> Patients are allocated to closest health unit (constraint: R0b)
# >> BUDGET CONSTRAINT ADDED
#############################################################################

set I; # The set of demand points.

set K; # Health care levels (PHC, SHC, THC)

param Dmax{K}; # Maximal distance (or travel time)

set E{K}; # Health care team from level k 

set EL{K}; # EXISTING health care units on three levels

set CL{K}; # CANDIDATE health care LOCATIONS on three levels

set L{k in K} := EL[k] union CL[k]; 

################################################
# BUDGET PARAMETER
param BUDGET >= 0; # Overall budget constraint ($/year)
################################################

# Custo anual por equipe (salário + encargos + consumíveis + logística)
param CE1{c1 in E[1]}; # Team cost K1 ($/year)
param CE2{c2 in E[2]}; # Team cost K2 ($/year)
param CE3{c3 in E[3]}; # Team cost K3 ($/year)

param D1{I,L[1]}:=round(Uniform(5,15));    # The travel time between i and level-1 PCF.   (min)
param D2{L[1],L[2]}:=round(Uniform(10,30)); # The travel time between candidate L1 and L2. (min)
param D3{L[2],L[3]}:=round(Uniform(20,40)); # The travel time between candidate L2 and L3. (min)

set Link1 dimen 2:= setof{i in I, j1 in L[1]: D1[i,j1] <= Dmax[1]}(i,j1);
set H1:= setof{i in I,j1 in L[1]: D1[i,j1] <= Dmax[1]} j1;
set Link2 dimen 2:= setof{j1 in L[1], j2 in L[2]: D2[j1,j2] <= Dmax[2]}(j1,j2);
set H2:= setof{j1 in L[1], j2 in L[2]: D2[j1,j2] <= Dmax[2]} j2;
set Link3 dimen 2:= setof{j2 in L[2], j3 in L[3]: D3[j2,j3] <= Dmax[3]}(j2,j3);
set H3:= setof{j2 in L[2], j3 in L[3]: D3[j2,j3] <= Dmax[3]} j3;

set L1:= L[1] inter H1;
set L2:= L[2] inter H2;
set L3:= L[3] inter H3;

display L1;
display L2;
display L3;

################################################
param TC1{I,L[1]}; # Travel cost/pat  from demand point i to L1   ($/min)
param TC2{L[1],L[2]}; # Travel cost/pat  from L1 to L2            ($/min)
param TC3{L[2],L[3]}; # Travel cost/pat  from L2 to L3            ($/min)

param VC1{L[1]}; # Variable cost of PHC j / pop h ($/pop)
param VC2{L[2]}; # Variable cost of SHC j / pop h ($/pop)
param VC3{L[3]}; # Variable cost of THC j / pop h ($/pop)

param FC1{L[1]}; # Fixed cost for operating PHC j    ($/year)
param FC2{L[2]}; # Fixed cost for operating SHC j    ($/year)
param FC3{L[3]}; # Fixed cost for operating THC j    ($/year)

param IA1{L[1]}; # Annualized Investment for operating NEW PHC j    ($/year)
param IA2{L[2]}; # Annualized Investment for operating NEW SHC j    ($/year)
param IA3{L[3]}; # Annualized Investment for operating NEW THC j    ($/year)

param W{I}; # The population size at demand point i (pop)

param MS1{E[1]}; # Ministry of Health parameter for requirements PHC (prof/pop)
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

param O1{L[1]}; # The proportion of patients in a L-1 to a L-2 PCF. (%)
param O2{L[2]}; # The proportion of patients in a L-1 to a L-2 PCF. (%)

################################################
# BUDGET PREPROCESSING: Calculate minimum cost per NEW facility
# This estimates the cost of opening one NEW facility at each level
param MinCostPerNewPHC := min{j1 in CL[1] inter L1}(FC1[j1]+IA1[j1] + sum{c1 in E[1]}CE1[c1]);
param MinCostPerNewSHC := min{j2 in CL[2] inter L2}(FC2[j2]+IA2[j2] + sum{c2 in E[2]}CE2[c2]);
param MinCostPerNewTHC := min{j3 in CL[3] inter L3}(FC3[j3]+IA3[j3] + sum{c3 in E[3]}CE3[c3]);

# Calculate existing facilities cost (mandatory costs)
param ExistingCost := 
    sum{j1 in EL[1] inter L1}FC1[j1] + 
    sum{j2 in EL[2] inter L2}FC2[j2] + 
    sum{j3 in EL[3] inter L3}FC3[j3];

# Available budget for new facilities
param AvailableBudget := max(0, BUDGET - ExistingCost);

# Maximum possible new facilities (conservative estimate)
param MaxNewPHC := if card(CL[1] inter L1) > 0 then 
                   min(U[1], floor(AvailableBudget / MinCostPerNewPHC)) 
                   else 0;
param MaxNewSHC := if card(CL[2] inter L2) > 0 then 
                   min(U[2], floor(AvailableBudget / MinCostPerNewSHC)) 
                   else 0;
param MaxNewTHC := if card(CL[3] inter L3) > 0 then 
                   min(U[3], floor(AvailableBudget / MinCostPerNewTHC)) 
                   else 0;

# Display budget information
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
var y{i in I, j1 in L1}, >=0, binary; # 1, if Pop is ASSIGNED to L-1 PCF (1) or not (0)
var y1{j1 in L1}, >=0, binary; # 1, if a L-1 PCF is used (1) at loc. k. or not (0)
var y2{j2 in L2}, >=0, binary; # 1, if a L-2 SCF is used (1) at loc. k. or not (0)
var y3{j3 in L3}, >=0, binary; # 1, if a L-3 TCF is used (1) at loc. k. or not (0)

var u1{i in I, j1 in L1}, >=0;  # The flow p between demand point i and L1 (pop)
var u2{j1 in L1, j2 in L2}, >=0;  # The flow between L1 and L2              (pop)
var u3{j2 in L2, j3 in L3}, >=0;  # The flow between L2 and L3              (pop)

# Número de equipes contratadas na UBS
var l1{E[1],L1}; # Lack (or excess) of professional e on localion L1          (prof)
var l2{E[2],L2}; # Lack (or excess) of professional e on localion L2          (prof)
var l3{E[3],L3}; # Lack (or excess) of professional e on localion L3          (prof)

#################################################
# Minimizes social and business costs:
minimize Total_Costs:
    # Patient transportation cost
      sum{i in I, j1 in L1}D1[i,j1]*TC1[i,j1]*u1[i,j1] 
    + sum{j1 in L1, j2 in L2}D2[j1,j2]*TC2[j1,j2]*u2[j1,j2]  
    + sum{j2 in L2, j3 in L3}D3[j2,j3]*TC3[j2,j3]*u3[j2,j3] 
    # Cost of existing unit (including staff)
    + sum{j1 in EL[1] inter L1}FC1[j1]*y1[j1] 
    + sum{j2 in EL[2] inter L2}FC2[j2]*y2[j2] 
    + sum{j3 in EL[3] inter L3}FC3[j3]*y3[j3]
    # New unit cost
    + sum{j1 in CL[1] inter L1}(FC1[j1]+IA1[j1])*y1[j1] 
    + sum{j2 in CL[2] inter L2}(FC2[j2]+IA2[j2])*y2[j2] 
    + sum{j3 in CL[3] inter L3}(FC3[j3]+IA3[j3])*y3[j3]  
    # Cost of new staff
    + sum{j1 in CL[1] inter L1,c1 in E[1]}CE1[c1]*y1[j1] 
    + sum{j2 in CL[2] inter L2,c2 in E[2]}CE2[c2]*y2[j2] 
    + sum{j3 in CL[3] inter L3,c3 in E[3]}CE3[c3]*y3[j3]
    # Variable cost per patient
    + sum{i in I, j1 in L1}VC1[j1]*u1[i,j1] 
    + sum{j1 in L1, j2 in L2}VC2[j2]*u2[j1,j2]  
    + sum{j2 in L2, j3 in L3}VC3[j3]*u3[j2,j3];

# Fix variables of EXISTING location
s.t. F1{j1 in EL[1] inter L1}:y1[j1] = 1; 
s.t. F2{j2 in EL[2] inter L2}:y2[j2] = 1; 
s.t. F3{j3 in EL[3] inter L3}:y3[j3] = 1;

# Entire population at each demand point i must be assigned 
s.t. R0{i in I, j1 in L1}: W[i]*y[i,j1] = u1[i,j1];
s.t. R0a{i in I}: sum{j1 in L1}y[i,j1] = 1;

# Patients are assigned to closest health unit
s.t. R0b{i in I, j1 in L1}: sum{k in L1: D1[i,k]>D1[i,j1]}y[i,k] + y1[j1] <= 1;

# Flow balance from PHC > SHC > THC
s.t. R1{j1 in L1}: sum{j2 in L2}u2[j1,j2] = O1[j1]*sum{i in I}u1[i,j1];
s.t. R2{j2 in L2}: sum{j3 in L3}u3[j2,j3] = O2[j2]*sum{j1 in L1}u2[j1,j2];

# Team of existing 
s.t. R3e{j1 in EL[1] inter L1, e1 in E[1]}: sum{i in I}u1[i,j1]*MS1[e1] - l1[e1,j1] = CNES1[e1,j1];
s.t. R4e{j2 in EL[2] inter L2, e2 in E[2]}: sum{j1 in EL[1] inter L1}u2[j1,j2]*MS2[e2] - l2[e2,j2] = CNES2[e2,j2];
s.t. R5e{j3 in EL[3] inter L3, e3 in E[3]}: sum{j2 in EL[2] inter L2}u3[j2,j3]*MS3[e3] - l3[e3,j3] = CNES3[e3,j3];

# New team
s.t. R3c{j1 in CL[1] inter L1, e1 in E[1]}: sum{i in I}u1[i,j1]*MS1[e1] = l1[e1,j1];
s.t. R4c{j2 in CL[2] inter L2, e2 in E[2]}: sum{j1 in L1}u2[j1,j2]*MS2[e2] = l2[e2,j2];
s.t. R5c{j3 in CL[3] inter L3, e3 in E[3]}: sum{j2 in L2}u3[j2,j3]*MS3[e3] = l3[e3,j3];

# Capacity of existing (patients)
s.t. R6e{j1 in EL[1] inter L1}: sum{i in I}u1[i,j1] <= C1[j1];
s.t. R7e{j2 in EL[2] inter L2}: sum{j1 in L1}u2[j1,j2] <= C2[j2];
s.t. R8e{j3 in EL[3] inter L3}: sum{j2 in L2}u3[j2,j3] <= C3[j3];

# Activation of new units
s.t. R6c{j1 in L1}: sum{i in I}u1[i,j1] <= C1[j1]*y1[j1];
s.t. R7c{j2 in L2}: sum{j1 in L1}u2[j1,j2] <= C2[j2]*y2[j2];
s.t. R8c{j3 in L3}: sum{j2 in L2}u3[j2,j3] <= C3[j3]*y3[j3];

# Budget-adjusted constraints on number of new facilities
s.t. R9c:  sum{j1 in CL[1] inter L1}y1[j1] <= MaxNewPHC;
s.t. R10c: sum{j2 in CL[2] inter L2}y2[j2] <= MaxNewSHC;
s.t. R11c: sum{j3 in CL[3] inter L3}y3[j3] <= MaxNewTHC;

# OVERALL BUDGET CONSTRAINT
s.t. BudgetConstraint:
    # Existing facilities cost
      sum{j1 in EL[1] inter L1}FC1[j1]*y1[j1] 
    + sum{j2 in EL[2] inter L2}FC2[j2]*y2[j2] 
    + sum{j3 in EL[3] inter L3}FC3[j3]*y3[j3]
    # New facilities fixed cost    
    + sum{j1 in CL[1] inter L1}(FC1[j1]+IA1[j1])*y1[j1] 
    + sum{j2 in CL[2] inter L2}(FC2[j2]+IA2[j2])*y2[j2] 
    + sum{j3 in CL[3] inter L3}(FC3[j3]+IA3[j3])*y3[j3]  
    # New staff cost
    + sum{j1 in CL[1] inter L1,c1 in E[1]}CE1[c1]*y1[j1] 
    + sum{j2 in CL[2] inter L2,c2 in E[2]}CE2[c2]*y2[j2] 
    + sum{j3 in CL[3] inter L3,c3 in E[3]}CE3[c3]*y3[j3]
    # Variable costs
    + sum{i in I, j1 in L1}VC1[j1]*u1[i,j1] 
    + sum{j1 in L1, j2 in L2}VC2[j2]*u2[j1,j2]  
    + sum{j2 in L2, j3 in L3}VC3[j3]*u3[j2,j3]
    # Transportation costs
    + sum{i in I, j1 in L1}D1[i,j1]*TC1[i,j1]*u1[i,j1] 
    + sum{j1 in L1, j2 in L2}D2[j1,j2]*TC2[j1,j2]*u2[j1,j2]  
    + sum{j2 in L2, j3 in L3}D3[j2,j3]*TC3[j2,j3]*u3[j2,j3]
    <= BUDGET;

solve;

printf: "\n========================================\n";
printf: "Health Care Plan\n";
printf: "========================================\n";
printf: "Logist cost:\t\t$%10.2f\n", 
      sum{i in I, j1 in L1}D1[i,j1]*TC1[i,j1]*u1[i,j1] 
    + sum{j1 in L1, j2 in L2}D2[j1,j2]*TC2[j1,j2]*u2[j1,j2]  
    + sum{j2 in L2, j3 in L3}D3[j2,j3]*TC3[j2,j3]*u3[j2,j3];
printf: "Fixed cost [E]:\t\t$%10.2f\n", 
      sum{j1 in EL[1] inter L1}FC1[j1]*y1[j1] 
    + sum{j2 in EL[2] inter L2}FC2[j2]*y2[j2] 
    + sum{j3 in EL[3] inter L3}FC3[j3]*y3[j3];
printf: "Fixed cost [C]:\t\t$%10.2f\n",       
    + sum{j1 in CL[1] inter L1}(FC1[j1]+IA1[j1])*y1[j1] 
    + sum{j2 in CL[2] inter L2}(FC2[j2]+IA2[j2])*y2[j2] 
    + sum{j3 in CL[3] inter L3}(FC3[j3]+IA3[j3])*y3[j3];
printf: "New team cost [C]:\t$%10.2f\n", 
      sum{j1 in CL[1] inter L1,c1 in E[1]}CE1[c1]*y1[j1] 
    + sum{j2 in CL[2] inter L2,c2 in E[2]}CE2[c2]*y2[j2] 
    + sum{j3 in CL[3] inter L3,c3 in E[3]}CE3[c3]*y3[j3];   
printf: "Variable Cost:\t\t$%10.2f\n", 
      sum{i in I, j1 in L1}VC1[j1]*u1[i,j1] 
    + sum{j1 in L1, j2 in L2}VC2[j2]*u2[j1,j2]  
    + sum{j2 in L2, j3 in L3}VC3[j3]*u3[j2,j3];
printf: "========================================\n";
printf: "Total    Cost:\t\t$%10.2f\n", Total_Costs;
printf: "Budget Limit:\t\t$%10.2f\n", BUDGET;
printf: "Budget Usage:\t\t%.2f%%\n", (Total_Costs/BUDGET)*100;
printf: "========================================\n";
printf: "New Units:\tQty\tMax*\tUse (%%)\n"; 
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
printf: "*Budget-adjusted max. units.\n";
printf: "========================================\n";
printf: "Municipality:\t  Pop\t Flow\n"; 
printf: "========================================\n";
printf{i in I}: "[%-14s]: %d\t %d\n", i, 
W[i], 
sum{j1 in L1}u1[i,j1];
printf: "========================================\n";
printf: "Mun     > PHC   :(flow)\n";
printf: "========================================\n";
for{i in I}{
    printf"M[%-4d] > \t: %d\n", i, W[i];
    for{j1 in L1: u1[i,j1] > 0}{
    printf"\t> L[%-4s]: %d\n", j1, u1[i,j1];
    }
}
printf: "========================================\n";
printf: "PHC     > SHC   :(flow)\n";
printf: "========================================\n";
for{j1 in L1: sum{i in I}u1[i,j1] > 0}{
    printf"L[%-4s] > \t: %d\n", j1, O1[j1]*sum{i in I}u1[i,j1];
    for{j2 in L2: u2[j1,j2] > 0}{
    printf"\t> L[%-4s]: %d\n", j2, u2[j1,j2];
    }
}

printf: "========================================\n";
printf: "SHC     > THC   :(flow)\n";
printf: "========================================\n";
for{j2 in L2: sum{j1 in L1}u2[j1,j2]>0}{
    printf: "L[%-4s] > \t : %d\n", j2, O2[j2]*sum{j1 in L1}u2[j1,j2];
    for{j3 in L3: u3[j2,j3] > 0}{
        printf: "\t> L[%-4s]: %d\n", j3, u3[j2,j3];
    }
}

printf: "========================================\n\n";
printf: "========================================\n";
printf: "Health care team (Existing and New*)\n";
printf: "========================================\n";
printf: "========================================\n";
printf: "PHC-Team CNES\tFlow\tLack/Excess\n";
printf: "========================================\n";
for{j1 in EL[1] inter L1: sum{i in I}u1[i,j1] > 0}{
    printf"L[%-4s]\n", j1;
    for{e1 in E[1]}{
    printf"  [%-s]: %.2f\t%.2f\t%.2f\n", e1, CNES1[e1,j1], 
    sum{i in I}u1[i,j1]*MS1[e1],
    l1[e1,j1];
    }
}

for{j1 in CL[1] inter L1: sum{i in I}u1[i,j1] > 0}{
    printf"L[%-4s*]\n", j1;
    for{e1 in E[1]}{
    printf"  [%-s]: \t%.2f\t%.2f\n", e1, 
    sum{i in I}u1[i,j1]*MS1[e1],
    l1[e1,j1];
    }
}
printf: "========================================\n";
printf: "SHC-Team CNES\tFlow\tLack/Excess\n";
printf: "========================================\n";
for{j2 in EL[2] inter L2: sum{j1 in L1}u2[j1,j2] > 0}{
    printf"L[%-4s]\n", j2;
    for{e2 in E[2]}{
    printf"  [%-s]: %.2f\t%.2f\t%.2f\n", e2, CNES2[e2,j2], 
    sum{j1 in L1}u2[j1,j2]*MS2[e2],
    l2[e2,j2];
    }
}

for{j2 in CL[2] inter L2: sum{j1 in L1}u2[j1,j2] > 0}{
    printf"L[%-4s*]\n", j2;
    for{e2 in E[2]: sum{j1 in L1}u2[j1,j2]>0}{
    printf"  [%-s]: \t%.2f\t%.2f\n", e2,  
    sum{j1 in L1}u2[j1,j2]*MS2[e2],
    l2[e2,j2];
    }
}

printf: "========================================\n";
printf: "THC-Team CNES\tFlow\tLack/Excess\n";
printf: "========================================\n";
for{j3 in EL[3] inter L3: sum{j2 in L2}u3[j2,j3] > 0}{
    printf"L[%-4s]\n", j3;
    for{e3 in E[3]}{
    printf"  [%-s]: %.2f\t%.2f\t%.2f\n", e3, CNES3[e3,j3], 
    sum{j2 in L2}u3[j2,j3]*MS3[e3],
    l3[e3,j3];
    }
}

for{j3 in CL[3] inter L3: sum{j2 in L2}u3[j2,j3] > 0}{
    printf"L[%-4s*]\n", j3;
    for{e3 in E[3]: sum{j2 in L2}u3[j2,j3]>0}{
    printf"  [%-s]: \t%.2f\t%.2f\n", e3,  
    sum{j2 in L2}u3[j2,j3]*MS3[e3],
    l3[e3,j3];
    }
}

printf: "========================================\n";
printf: "PHC:\tCapty\tMet\tUse(%%)\n";
printf: "========================================\n";
# Existing location
printf{j1 in EL[1] inter L1}: 
"[%-4s]:\t%d\t%d\t%3d%%\n", j1,  
C1[j1], 
sum{i in I}u1[i,j1],
if C1[j1] > 0 then ((sum{i in I}u1[i,j1])/(C1[j1]))*100 else 0;
# Candidate location
printf{j1 in CL[1] inter L1: sum{i in I}u1[i,j1]>0}: 
"[%-4s*]:\t%d\t%d\t%3d%%\n", j1, 
C1[j1], 
sum{i in I}u1[i,j1],
if C1[j1] > 0 then ((sum{i in I}u1[i,j1])/(C1[j1]))*100 else 0;

printf: "========================================\n";
printf: "SHC     :\tCapty\tMet\tUse(%%)\n";
printf: "========================================\n";
# Existing location
printf{j2 in EL[2] inter L2}: "[%-6s]:\t%d\t%d\t%3d%%\n", j2, 
C2[j2], 
sum{j1 in L1}u2[j1,j2],
if C2[j2] > 0 then ((sum{j1 in L1}u2[j1,j2])/(C2[j2]))*100 else 0;

# Candidate location
printf{j2 in CL[2] inter L2: sum{j1 in L1}u2[j1,j2]>0}: 
"[%-5s*]:\t%d\t%d\t%3d%%\n", j2, 
C2[j2], 
sum{j1 in L1}u2[j1,j2],
if C2[j2] > 0 then ((sum{j1 in L1}u2[j1,j2])/(C2[j2]))*100 else 0;

printf: "========================================\n";
printf: "THC     :\tCapty\tMet\tUse(%%)\n";
printf: "========================================\n";
# Existing location
printf{j3 in EL[3] inter L3}: "[%-6s]:\t%d\t%d\t%3d%%\n", j3, 
C3[j3], 
sum{j2 in L2}u3[j2,j3],
if C3[j3] > 0 then ((sum{j2 in L2}u3[j2,j3])/(C3[j3]))*100 else 0;

# Candidate location
printf{j3 in CL[3] inter L3: sum{j2 in L2}u3[j2,j3]>0}: 
"[%-5s*]:\t%d\t%d\t%3d%%\n", j3, 
C3[j3], 
sum{j2 in L2}u3[j2,j3],
if C3[j3] > 0 then ((sum{j2 in L2}u3[j2,j3])/(C3[j3]))*100 else 0;
printf: "========================================\n\n";

end;