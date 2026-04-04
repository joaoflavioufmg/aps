#!/usr/bin/env python3
"""
Data Consistency Checker for AMPL Healthcare Facility Location Models
Validates data for feasibility BEFORE running optimizer.

Checks 1-8 : structural / parameter consistency
Check  9   : R0b spatial-lock analysis (detects LP-level infeasibility
             caused by the closest-unit assignment rule locking demand
             origins to a single over-capacity PHC)
"""

import math
import re
import sys
from collections import defaultdict


# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

def strip_comments(content):
    """Remove AMPL-style # comments so regexes never match commented-out lines."""
    return re.sub(r'#[^\n]*', '', content)


def _fmt_table(headers, rows):
    """Return a list of lines for a plain-text box table."""
    widths = [len(h) for h in headers]
    str_rows = [[str(c) for c in row] for row in rows]
    for row in str_rows:
        for k, cell in enumerate(row):
            widths[k] = max(widths[k], len(cell))
    border = '+' + '+'.join('-' * (w + 2) for w in widths) + '+'

    def fmt_row(cells):
        return '|' + '|'.join(f' {c:<{widths[k]}} ' for k, c in enumerate(cells)) + '|'

    lines = [border, fmt_row(headers), border]
    for row in str_rows:
        lines.append(fmt_row(row))
    lines.append(border)
    return lines


# ------------------------------------------------------------------------------
# Rich diagnostic message container
# ------------------------------------------------------------------------------

class Diagnostic:
    """
    Structured diagnostic with WHAT / WHY / FIX sections and an optional
    ASCII table.  Used for Check 9 (and extensible to other checks).

    level : 'ERROR' | 'WARNING' | 'INFO'
    """

    ICONS = {'ERROR': 'X', 'WARNING': '!', 'INFO': 'i'}

    def __init__(self, level, title, what='', why='', fix='',
                 table_headers=None, table_rows=None):
        self.level         = level
        self.title         = title
        self.what          = what
        self.why           = why
        self.fix           = fix
        self.table_headers = table_headers or []
        self.table_rows    = table_rows    or []

    def render(self):
        icon = {'ERROR': '❌', 'WARNING': '⚠', 'INFO': 'ℹ'}.get(self.level, '•')
        lines = [
            f"{icon} {self.level}: {self.title}",
            "  " + "·" * 76,
        ]
        if self.what:
            lines.append("  ▸ WHAT:")
            for sub in self._wrap(self.what, 72):
                lines.append(f"      {sub}")
        if self.why:
            lines.append("  ▸ WHY:")
            for sub in self.why.split('\n'):
                lines.append(f"      {sub}")
        if self.table_headers and self.table_rows:
            lines.append("  ▸ DETAILS:")
            for tline in _fmt_table(self.table_headers, self.table_rows):
                lines.append(f"      {tline}")
        if self.fix:
            lines.append("  ▸ FIX:")
            for sub in self.fix.split('\n'):
                lines.append(f"      {sub}")
        lines.append("  " + "·" * 76)
        return '\n'.join(lines)

    @staticmethod
    def _wrap(text, width):
        """Very simple word-wrap."""
        words, line, out = text.split(), [], []
        for w in words:
            if sum(len(x) + 1 for x in line) + len(w) > width and line:
                out.append(' '.join(line))
                line = [w]
            else:
                line.append(w)
        if line:
            out.append(' '.join(line))
        return out


# ------------------------------------------------------------------------------
# Validator
# ------------------------------------------------------------------------------

class DataValidator:

    # Model constants matching aps.mod defaults
    SIZE_DEFAULT = 3     # param SIZE{L[1]}, default 3, <= 5
    SIZE_MAX     = 5     # param SIZE{L[1]}, default 3, <= 5
    POP_PER_SIZE = 3000  # C1[j1] := SIZE[j1] * 3000
    MAX_HOME_SHC = 0.15  # R0l: u0_2 <= 0.15 * W[i]
    MAX_HOME_THC = 0.05  # R0m: u0_3 <= 0.05 * W[i]
    MAX_TELE     = 0.05  # R0h/i/j: ut <= 0.05 * u_presential

    def __init__(self):
        self.data = {
            'I':         set(),
            'L':         defaultdict(set),
            'EL':        defaultdict(set),
            'CL':        defaultdict(set),
            'W':         {},
            'SIZE':      {},
            'C1':        {}, 'C2': {}, 'C3': {},
            'O1_0':      {}, 'O2_0': {}, 'O3_0': {},
            'Dmax':      {},
            'D0_1_count': 0,
            'D0_2_count': 0,
            'D0_3_count': 0,
            'D0_1':      {},   # (i, j1) -> metres  — used for Checks 9 & 10
            'D0_2':      {},   # (i, j2) -> metres  — used for Check 10
            'D0_3':      {},   # (i, j3) -> metres  — used for Check 10
        }
        self.errors      = []
        self.warnings    = []
        self.info        = []
        self.diagnostics = []

    # --------------------------------------------------------------------------
    # Public API
    # --------------------------------------------------------------------------

    def validate_files(self, filenames):
        """Load all data files then run validation once."""
        for filename in filenames:
            try:
                with open(filename, 'r', encoding='utf-8', errors='replace') as f:
                    raw = f.read()
                self._parse_data(strip_comments(raw))
            except FileNotFoundError:
                print(f"File not found: {filename}")
                return False

        for k in [1, 2, 3]:
            self.data['L'][k] = self.data['EL'][k] | self.data['CL'][k]

        self.run_all_checks()
        return True

    # --------------------------------------------------------------------------
    # Parsing
    # --------------------------------------------------------------------------

    def _parse_data(self, content):
        """Extract sets and parameters from comment-stripped AMPL data."""

        # EL[k] / CL[k]
        for k in [1, 2, 3]:
            for key in ('EL', 'CL'):
                m = re.search(rf'set {key}\[{k}\]\s*:=\s*([\s\S]*?);', content)
                if m:
                    self.data[key][k].update(m.group(1).strip().split())

        # Origins (set I) and demand W — tolerates optional IVS column
        m = re.search(r'param:\s*I:\s+W\s+[^:]*:=\s*([\s\S]*?);', content)
        if m:
            for line in m.group(1).strip().split('\n'):
                parts = line.split()
                if len(parts) >= 2:
                    try:
                        self.data['W'][parts[0]] = float(parts[1])
                        self.data['I'].add(parts[0])
                    except ValueError:
                        pass

        # SIZE — from ITEM1 table: "facility  ITEM  SIZE  FC1  VC1"
        m = re.search(r'param:\s*ITEM1\s+SIZE[^:]*:=\s*([\s\S]*?);', content)
        if m:
            for line in m.group(1).strip().split('\n'):
                parts = line.split()
                if len(parts) >= 3:
                    try:
                        self.data['SIZE'][parts[0]] = int(parts[2])
                    except ValueError:
                        pass

        # C2 / C3  (C1 is derived from SIZE in the model; no explicit C1 block)
        for cap_key in ('C2', 'C3'):
            m = re.search(rf'param {cap_key}[^:]*:=\s*([\s\S]*?);', content)
            if m:
                for line in m.group(1).strip().split('\n'):
                    parts = line.split()
                    if len(parts) >= 2:
                        try:
                            self.data[cap_key][parts[0]] = float(parts[1])
                        except ValueError:
                            pass

        # Step-down ratios
        for ratio_key in ('O1_0', 'O2_0', 'O3_0'):
            m = re.search(
                rf'param\s*:\s*[\s\S]*?{ratio_key}[\s\S]*?:=\s*([\s\S]*?);',
                content,
            )
            if m:
                for line in m.group(1).strip().split('\n'):
                    parts = line.split()
                    if len(parts) >= 2:
                        try:
                            self.data[ratio_key][parts[0]] = float(parts[1])
                        except ValueError:
                            pass

        # Dmax — handles both common formats
        m = re.search(r'param\s*:\s*K\s*:\s*Dmax\s*:=\s*([\s\S]*?);', content)
        if not m:
            m = re.search(r'param Dmax\[K\]\s*:=\s*([\s\S]*?);', content)
        if m:
            for line in m.group(1).strip().split('\n'):
                parts = line.split()
                if len(parts) >= 2:
                    try:
                        self.data['Dmax'][int(parts[0])] = float(parts[1])
                    except ValueError:
                        pass

        # Distance matrices
        for dist_key, count_key in [
            ('D0_1', 'D0_1_count'),
            ('D0_2', 'D0_2_count'),
            ('D0_3', 'D0_3_count'),
        ]:
            m = re.search(rf'param {dist_key}[^:]*:=\s*([\s\S]*?);', content)
            if m:
                tokens = m.group(1).strip().split()
                self.data[count_key] += len(tokens) // 3
                it = iter(tokens)
                try:
                    while True:
                        i  = next(it)
                        j  = next(it)
                        dv = float(next(it))
                        self.data[dist_key][(i, j)] = dv
                except StopIteration:
                    pass

    # --------------------------------------------------------------------------
    # Orchestration
    # --------------------------------------------------------------------------

    def run_all_checks(self):
        W = 80
        print("\n" + "=" * W)
        print("DATA CONSISTENCY VALIDATION")
        print("=" * W)

        self.check_set_definitions()
        self.check_parameter_indices()
        self.check_capacity_values()
        self.check_distance_parameters()
        self.check_step_down_ratios()
        self.check_demand_feasibility()
        self.check_facility_connectivity()
        self.check_network_balance()
        self.check_r0b_spatial_lock()
        self.check_distance_coverage()

        self.print_results()

    # --------------------------------------------------------------------------
    # Checks 1–8
    # --------------------------------------------------------------------------

    def check_set_definitions(self):
        print("\n[CHECK 1] Set Definitions")
        print("-" * 80)

        if not self.data['I']:
            if self.data['W']:
                self.errors.append("Set I (origins) defined in W but not as a set")
            else:
                self.warnings.append(
                    "Set I (origins) not found — file may be distance-only"
                )
            return

        self.info.append(f"Set I: {len(self.data['I'])} origins")

        for k in [1, 2, 3]:
            lk = self.data['L'][k]
            if not lk:
                self.errors.append(
                    f"Set L[{k}] (level {k} facilities) is empty — "
                    f"check set EL[{k}] and CL[{k}] definitions"
                )
            else:
                el_c = len(self.data['EL'][k])
                cl_c = len(self.data['CL'][k])
                self.info.append(
                    f"Set L[{k}]: {len(lk)} facilities "
                    f"({el_c} existing, {cl_c} candidates)"
                )

    def check_parameter_indices(self):
        print("\n[CHECK 2] Parameter Index Consistency")
        print("-" * 80)

        if self.data['W'] and self.data['I']:
            invalid = [i for i in self.data['W'] if i not in self.data['I']]
            if invalid:
                self.errors.append(f"Demand W has invalid origins: {invalid}")
            else:
                self.info.append("All W indices are in set I")

        for cap_name, level in [('C2', 2), ('C3', 3)]:
            cap_data = self.data[cap_name]
            lk = self.data['L'][level]
            if not cap_data:
                self.info.append(
                    f"All {cap_name} indices are in set L[{level}] (none defined)"
                )
                continue
            if not lk:
                self.errors.append(
                    f"{cap_name} has entries but L[{level}] is empty"
                )
                continue
            invalid = [j for j in cap_data if j not in lk]
            if invalid:
                self.errors.append(
                    f"{cap_name} has invalid facilities: {invalid}"
                )
            else:
                self.info.append(f"All {cap_name} indices are in set L[{level}]")

        el1 = self.data['EL'][1]
        if el1:
            sized = [j for j in el1 if j in self.data['SIZE']]
            if sized:
                self.info.append(
                    f"SIZE defined for {len(sized)}/{len(el1)} existing L[1] facilities "
                    f"(C1 = SIZE x {self.POP_PER_SIZE}, default SIZE={self.SIZE_DEFAULT})"
                )
            else:
                self.info.append(
                    "All C1 indices are in set L[1] (C1 derived from SIZE, none explicit)"
                )

    def check_capacity_values(self):
        print("\n[CHECK 3] Capacity Values")
        print("-" * 80)

        for cap_name, min_rec in [('C2', 1000), ('C3', 500)]:
            cap_data = self.data[cap_name]
            if not cap_data:
                continue
            mn, mx = min(cap_data.values()), max(cap_data.values())
            self.info.append(f"{cap_name}: min={mn:.0f}, max={mx:.0f}")
            if mn < 100:
                self.errors.append(
                    f"{cap_name} capacity unrealistically small (min={mn}). "
                    f"Recommend >= {min_rec}."
                )

        el1 = self.data['EL'][1]
        if el1 and self.data['SIZE']:
            c1_vals = [self.data['SIZE'].get(j, self.SIZE_DEFAULT) * self.POP_PER_SIZE for j in el1]
            self.info.append(
                f"C1 (SIZE x {self.POP_PER_SIZE}): "
                f"min={min(c1_vals)}, max={max(c1_vals)}, "
                f"expandable to max {self.SIZE_MAX * self.POP_PER_SIZE} (SIZE={self.SIZE_MAX})"
            )

    def check_distance_parameters(self):
        print("\n[CHECK 4] Distance Parameters")
        print("-" * 80)

        for dist_key, count_key in [
            ('D0_1', 'D0_1_count'), ('D0_2', 'D0_2_count'), ('D0_3', 'D0_3_count')
        ]:
            cnt = self.data[count_key]
            if cnt:
                self.info.append(f"{dist_key} defined ({cnt} entries)")
            else:
                self.warnings.append(f"{dist_key} not found")

        if self.data['Dmax']:
            self.info.append(
                "Dmax defined: "
                + ', '.join(
                    f"L{k}={v:.0f}m" for k, v in sorted(self.data['Dmax'].items())
                )
            )

    def check_step_down_ratios(self):
        print("\n[CHECK 5] Step-Down Ratios")
        print("-" * 80)

        for ratio_name in ('O1_0', 'O2_0', 'O3_0'):
            rd = self.data[ratio_name]
            if not rd:
                self.warnings.append(f"{ratio_name} not found")
                continue
            mn = min(rd.values())
            mx = max(rd.values())
            avg = sum(rd.values()) / len(rd)
            self.info.append(
                f"{ratio_name}: min={mn:.2f}, max={mx:.2f}, avg={avg:.2f}"
            )
            if mn <= 0 or mx >= 1:
                self.warnings.append(
                    f"{ratio_name} has values outside (0, 1): min={mn}, max={mx}"
                )

    def check_demand_feasibility(self):
        print("\n[CHECK 6] Demand Feasibility")
        print("-" * 80)

        if not self.data['W']:
            return
        vals  = list(self.data['W'].values())
        n     = len(vals)
        total = sum(vals)
        avg   = total / n
        lo    = min(vals)
        hi    = max(vals)

        # Median
        sorted_vals = sorted(vals)
        mid = n // 2
        median = (sorted_vals[mid] if n % 2 == 1
                  else (sorted_vals[mid - 1] + sorted_vals[mid]) / 2)

        # Mode (most frequent value; show up to 3 if there are ties)
        freq = defaultdict(int)
        for v in vals:
            freq[v] += 1
        max_freq = max(freq.values())
        modes = sorted(k for k, c in freq.items() if c == max_freq)
        if len(modes) <= 3:
            mode_str = ', '.join(f"{m:.0f}" for m in modes)
        else:
            mode_str = (', '.join(f"{m:.0f}" for m in modes[:3])
                        + f" … (+{len(modes)-3} more ties)")
        mode_str += f" (freq={max_freq})"

        # Population standard deviation
        variance = sum((v - avg) ** 2 for v in vals) / n
        std_dev  = math.sqrt(variance)

        self.info.append(f"Total demand: {total:.0f}")
        self.info.append(f"Range: [{lo:.0f}, {hi:.0f}]")
        self.info.append(f"Average: {avg:.1f}")
        self.info.append(f"Median:  {median:.1f}")
        self.info.append(f"Mode:    {mode_str}")
        self.info.append(f"Std Dev: {std_dev:.1f}")

    def check_facility_connectivity(self):
        print("\n[CHECK 7] Facility Connectivity")
        print("-" * 80)

        for dist_key, count_key in [
            ('D0_1', 'D0_1_count'), ('D0_2', 'D0_2_count'), ('D0_3', 'D0_3_count')
        ]:
            cnt = self.data[count_key]
            if cnt:
                self.info.append(f"{dist_key}: {cnt} distance entries defined")

    def check_network_balance(self):
        print("\n[CHECK 8] Network Balance")
        print("-" * 80)

        if not self.data['W'] or not self.data['C2'] or not self.data['C3']:
            return

        total_demand = sum(self.data['W'].values())
        total_c2     = sum(self.data['C2'].values())
        total_c3     = sum(self.data['C3'].values())

        avg_o1_0 = (sum(self.data['O1_0'].values()) / len(self.data['O1_0'])
                    if self.data['O1_0'] else 0.71)
        avg_o2_0 = (sum(self.data['O2_0'].values()) / len(self.data['O2_0'])
                    if self.data['O2_0'] else 0.65)
        avg_o3_0 = (sum(self.data['O3_0'].values()) / len(self.data['O3_0'])
                    if self.data['O3_0'] else 0.80)

        transfers_l1 = total_demand * (1 - avg_o1_0)
        returns_l2   = transfers_l1 * avg_o2_0
        transfers_l2 = transfers_l1 * (1 - avg_o2_0)
        returns_l3   = transfers_l2 * avg_o3_0

        self.info.append(f"Total demand:          {total_demand:.0f}")
        self.info.append(f"Total capacity: C2={total_c2:.0f}, C3={total_c3:.0f}")
        self.info.append(f"L1->L2/L3 transfers:   {transfers_l1:.0f} patients")
        self.info.append(f"L2->L3 transfers:      {transfers_l2:.0f} patients")
        self.info.append(f"L2 required capacity:  {returns_l2 + transfers_l2:.0f}")
        self.info.append(f"L3 required capacity:  {returns_l3:.0f}")

        for level, name, needed, total_cap in [
            (2, 'L2', returns_l2 + transfers_l2, total_c2),
            (3, 'L3', returns_l3,                total_c3),
        ]:
            if not self.data['L'][level]:
                self.errors.append(f"No {name} facilities defined")
            elif needed > total_cap:
                self.errors.append(
                    f"{name} insufficient: {needed:.0f} > {total_cap:.0f}"
                )
            else:
                self.info.append(f"{name} capacity sufficient")

    # --------------------------------------------------------------------------
    # Check 9 — R0b Spatial-Lock Analysis
    # --------------------------------------------------------------------------

    def check_r0b_spatial_lock(self):
        """
        Detect LP-level infeasibility caused by the R0b closest-unit rule.

        R0b (aps.mod) prevents assigning an origin i to any PHC j1 that is
        farther than the closest already-open existing PHC reachable from i.
        Because F1 forces y1[j]=1 for ALL EL[1], this creates a hard distance
        cutoff per origin.

        When the total demand locked to a single PHC exceeds that PHC's maximum
        expandable capacity (SIZE_MAX x POP_PER_SIZE), the LP relaxation is
        provably infeasible — the violation cannot be fixed by branching.
        """
        print("\n[CHECK 9] R0b Spatial-Lock Analysis")
        print("-" * 80)

        W     = self.data['W']
        d01   = self.data['D0_1']
        el1   = self.data['EL'][1]
        cl1   = self.data['CL'][1]
        sizes = self.data['SIZE']
        dmax1 = self.data['Dmax'].get(1, None)

        # Prerequisites
        if not W:
            self.info.append("Check 9 skipped: no demand data (W) found")
            return
        if not d01:
            self.warnings.append(
                "Check 9 skipped: D0_1 distance matrix not loaded "
                "(add the *_distdur.dat file to enable this check)"
            )
            return
        if not el1:
            self.warnings.append(
                "Check 9 skipped: EL[1] (existing PHCs) not defined"
            )
            return
        if dmax1 is None:
            self.warnings.append("Check 9 skipped: Dmax[1] not found")
            return

        L1    = list(el1) + list(cl1)
        MAX_C1 = self.SIZE_MAX * self.POP_PER_SIZE  # e.g. 5 * 3000 = 15 000

        # Maximum fraction of W[i] that can bypass L1 entirely via R0l / R0m
        max_bypass = (
            self.MAX_HOME_SHC * (1 + self.MAX_TELE)   # L2 direct
            + self.MAX_HOME_THC * (1 + self.MAX_TELE)  # L3 direct
        )
        min_l1_frac = 1.0 - max_bypass   # ~0.79

        def cap_filter(j):
            return MAX_C1 if j in el1 else sizes.get(j, self.SIZE_DEFAULT) * self.POP_PER_SIZE

        def in_link01(i, j):
            return (
                d01.get((i, j), float('inf')) <= dmax1
                and cap_filter(j) >= W[i]
            )

        # Step 1 — nearest EL[1] distance per origin
        min_d_el1 = {}
        for i in W:
            ds = [d01.get((i, j), float('inf')) for j in el1 if in_link01(i, j)]
            min_d_el1[i] = min(ds) if ds else float('inf')

        # Step 2 — effective neighbours after R0b cutoff
        eff_nb = {}
        for i in W:
            cut = min_d_el1[i]
            if cut == float('inf'):
                eff_nb[i] = []
            else:
                eff_nb[i] = [
                    j for j in L1
                    if in_link01(i, j) and d01.get((i, j), float('inf')) <= cut
                ]

        # Step 3 — origins with exactly 1 option are fully forced to it
        forced = {}
        for i, nb in eff_nb.items():
            if len(nb) == 1:
                forced.setdefault(nb[0], []).append(i)

        # Step 4 — identify violations
        violations = []
        for j, locked in forced.items():
            fd  = sum(W[o] for o in locked)
            cap = MAX_C1
            if fd > cap:
                irred = max(0.0, fd * min_l1_frac - cap)
                violations.append({
                    'phc':     j,
                    'size':    sizes.get(j, self.SIZE_DEFAULT),
                    'cap':     cap,
                    'fd':      fd,
                    'n_orig':  len(locked),
                    'irred':   irred,
                    'origins': locked,
                })

        # Step 5 — aggregate info
        n_single = sum(1 for nb in eff_nb.values() if len(nb) == 1)
        w_single = sum(W[i] for i, nb in eff_nb.items() if len(nb) == 1)
        self.info.append(
            f"After R0b: {n_single} origins ({w_single:.0f} patients) "
            f"restricted to exactly 1 PHC option"
        )
        self.info.append(
            f"PHC max expandable capacity: {MAX_C1:,} patients "
            f"(SIZE={self.SIZE_MAX} x {self.POP_PER_SIZE})"
        )

        if not violations:
            self.info.append(
                "R0b spatial-lock: OK — no PHC has forced demand exceeding max capacity"
            )
            return

        # Flat error for exit-code / summary
        total_n = sum(v['n_orig'] for v in violations)
        total_w = sum(v['fd']    for v in violations)
        self.errors.append(
            f"R0b spatial-lock: {len(violations)} PHC(s) have forced demand > max capacity "
            f"=> LP is provably infeasible "
            f"({total_n} locked clusters, {total_w:.0f} locked patients)"
        )

        # Rich diagnostic per violated PHC
        for v in sorted(violations, key=lambda x: -x['irred']):
            j = v['phc']
            top3 = sorted(
                [(o, W[o]) for o in v['origins']], key=lambda x: -x[1]
            )[:3]
            top3_str = ', '.join(f"{o} (W={w:.0f})" for o, w in top3)
            if len(v['origins']) > 3:
                top3_str += f", ... (+{len(v['origins'])-3} more)"

            min_size_needed = math.ceil(v['fd'] * min_l1_frac / self.POP_PER_SIZE)

            what_msg = (
                f"PHC {j} (current SIZE={v['size']}, C1_max={v['cap']:,}) "
                f"receives a forced demand of {v['fd']:,.0f} patients from "
                f"{v['n_orig']} locked clusters ({top3_str}). "
                f"Raw overflow = {v['fd'] - v['cap']:,.0f}. "
                f"Even after allowing the maximum {(1-min_l1_frac)*100:.0f}% direct "
                f"diversion to L2/L3 (R0l/R0m constraints), the irreducible L1 load "
                f"is {v['fd'] * min_l1_frac:,.0f} patients, still exceeding capacity "
                f"by {v['irred']:,.0f}. The LP relaxation cannot be satisfied."
            )

            why_msg = (
                "Constraint R0b prevents assigning origin i to any PHC farther\n"
                "than its closest already-open EL[1] facility. Constraint F1\n"
                "forces y1[j]=1 for ALL existing PHCs, so the R0b distance\n"
                f"cutoff is always active. The {v['n_orig']} clusters listed\n"
                f"above have {j} as their nearest EL[1] within Dmax[1]={dmax1:.0f}m,\n"
                "leaving them with NO alternative PHC. The data validator's\n"
                "aggregate checks (total demand vs total C2/C3 capacity) pass\n"
                "because they never examine the per-PHC spatial geometry."
            )

            fix_msg = (
                f"Option A  Remove or soften constraint R0b in aps.mod  (recommended)\n"
                f"          Comment out 's.t. R0b ...' or convert it to a soft\n"
                f"          penalty in the objective. This instantly removes the\n"
                f"          geometric lock without changing any data file.\n"
                f"\n"
                f"Option B  Raise the SIZE ceiling for PHC {j} in aps.mod\n"
                f"          Change 'param SIZE{{L[1]}}, default {self.SIZE_DEFAULT}, <= {self.SIZE_MAX}'\n"
                f"          to '<= {min_size_needed}' specifically for this PHC\n"
                f"          ({min_size_needed} x {self.POP_PER_SIZE} = "
                f"{min_size_needed * self.POP_PER_SIZE:,} >= irreducible load "
                f"{v['fd'] * min_l1_frac:,.0f}).\n"
                f"\n"
                f"Option C  Add a new CL[1] candidate PHC geographically closer\n"
                f"          to the locked clusters. Once a closer candidate is\n"
                f"          placed within Dmax[1]={dmax1:.0f}m of those origins,\n"
                f"          R0b will route them to that candidate instead,\n"
                f"          relieving the load on {j}.\n"
                f"\n"
                f"Option D  Increase Dmax[1] (currently {dmax1:.0f}m)\n"
                f"          A wider radius gives locked origins additional EL[1]\n"
                f"          options; the R0b cutoff distance rises to the farther\n"
                f"          facility, which may have spare capacity."
            )

            tbl_headers = [
                "PHC", "SIZE (cur)", "C1 max", "Forced demand",
                "Overflow", "Irred. overflow", "# locked clusters"
            ]
            tbl_rows = [[
                j,
                str(v['size']),
                f"{v['cap']:,}",
                f"{v['fd']:,.0f}",
                f"+{v['fd'] - v['cap']:,.0f}",
                f"{v['irred']:,.0f}",
                str(v['n_orig']),
            ]]

            self.diagnostics.append(Diagnostic(
                level='ERROR',
                title=f"R0b Spatial Lock — PHC {j}: forced demand exceeds max capacity",
                what=what_msg,
                why=why_msg,
                fix=fix_msg,
                table_headers=tbl_headers,
                table_rows=tbl_rows,
            ))

    # --------------------------------------------------------------------------
    # Check 10 — Distance Matrix Coverage (no missing O-D pairs)
    # --------------------------------------------------------------------------

    def check_distance_coverage(self):
        """
        Verify that every required origin–destination pair has a distance
        value in the data files.

        The model declares:
            param D0_1{i in I, j1 in L[1]};   # no default
            param D0_2{i in I, j2 in L[2]};   # no default
            param D0_3{i in I, j3 in L[3]};   # no default

        A missing (i, j) entry causes GLPK to abort with
        "no value for D0_k[i, j]" before the solve even starts.
        """
        print("\n[CHECK 10] Distance Matrix Coverage")
        print("-" * 80)

        MAX_LISTED = 50   # cap on individual missing-pair lines printed

        for dist_key, level in [('D0_1', 1), ('D0_2', 2), ('D0_3', 3)]:
            I   = self.data['I']
            L_k = self.data['L'][level]
            d   = self.data[dist_key]

            if not I or not L_k:
                self.info.append(
                    f"{dist_key} coverage: skipped "
                    f"(I or L[{level}] not defined)"
                )
                continue

            if not d:
                # already flagged by check_distance_parameters
                continue

            expected   = len(I) * len(L_k)
            defined    = len(d)
            missing_pairs = [
                (i, j) for i in sorted(I) for j in sorted(L_k)
                if (i, j) not in d
            ]
            n_missing = len(missing_pairs)

            if n_missing == 0:
                self.info.append(
                    f"{dist_key} coverage: complete "
                    f"({defined}/{expected} pairs defined)"
                )
                continue

            # --- summarise by origin ---
            by_origin = defaultdict(list)
            for (i, j) in missing_pairs:
                by_origin[i].append(j)

            n_origins_missing = len(by_origin)
            pct = 100.0 * n_missing / expected

            self.errors.append(
                f"{dist_key} coverage: {n_missing} of {expected} pairs missing "
                f"({pct:.1f}%) — affects {n_origins_missing} origin(s). "
                f"GLPK will abort with 'no value for {dist_key}[i,j]'."
            )

            # Build a rich diagnostic with a per-origin table
            tbl_headers = ["Origin", "# missing dests", "Missing destinations (first 5)"]
            tbl_rows    = []
            listed = 0
            for origin in sorted(by_origin):
                missing_dests = by_origin[origin]
                sample = missing_dests[:5]
                sample_str = ', '.join(sample)
                if len(missing_dests) > 5:
                    sample_str += f" … (+{len(missing_dests)-5} more)"
                tbl_rows.append([origin, str(len(missing_dests)), sample_str])
                listed += 1
                if listed >= MAX_LISTED:
                    tbl_rows.append([
                        f"… +{n_origins_missing - listed} more origins",
                        "—", "—"
                    ])
                    break

            # Flat list of the first MAX_LISTED missing pairs (mirrors GLPK error format)
            flat_examples = []
            for (i, j) in missing_pairs[:MAX_LISTED]:
                flat_examples.append(f"no value for {dist_key}[{i},{j}]")
            if n_missing > MAX_LISTED:
                flat_examples.append(
                    f"… ({n_missing - MAX_LISTED} more missing pairs not shown)"
                )

            what_msg = (
                f"{dist_key} requires one entry for every (origin, facility) pair "
                f"because it is declared without a default value in aps.mod "
                f"(param {dist_key}{{I, L[{level}]}}). "
                f"Out of {expected} required pairs, {n_missing} ({pct:.1f}%) are absent. "
                f"{n_origins_missing} distinct origin(s) are affected."
            )
            why_msg  = (
                f"GLPK evaluates D0_{level}_KM and set Link0{level} by iterating\n"
                f"over ALL pairs in I × L[{level}]. Any missing entry triggers\n"
                f"an immediate 'MathProg model processing error' before the solve."
            )
            fix_msg  = (
                f"Add the missing {n_missing} (origin, facility, distance) triples\n"
                f"to the {dist_key} block in the *_distdur.dat file.\n"
                f"Each line must follow the format:\n"
                f"  <origin_id>  <facility_id>  <distance_in_metres>\n"
                f"e.g.:\n"
                + "\n".join(f"  {flat_examples[k]}" for k in range(min(3, len(flat_examples))))
            )

            self.diagnostics.append(Diagnostic(
                level='ERROR',
                title=(
                    f"{dist_key} missing {n_missing} of {expected} O-D pairs "
                    f"— model will abort at preprocessing"
                ),
                what=what_msg,
                why=why_msg,
                fix=fix_msg,
                table_headers=tbl_headers,
                table_rows=tbl_rows,
            ))

            # Also print flat list inline so it mirrors the GLPK error output
            print(f"\n  Missing {dist_key} pairs ({min(n_missing, MAX_LISTED)} shown"
                  + (f" of {n_missing}" if n_missing > MAX_LISTED else "") + "):")
            for line in flat_examples:
                print(f"    {line}")

    # --------------------------------------------------------------------------
    # Output
    # --------------------------------------------------------------------------

    def print_results(self):
        W = 80
        print("\n" + "=" * W)
        print("VALIDATION RESULTS")
        print("=" * W)

        if self.errors:
            print(f"\nERRORS ({len(self.errors)}):")
            print("-" * W)
            for i, err in enumerate(self.errors, 1):
                print(f"{i}. {err}")

        if self.warnings:
            print(f"\nWARNINGS ({len(self.warnings)}):")
            print("-" * W)
            for i, warn in enumerate(self.warnings, 1):
                print(f"{i}. {warn}")

        if self.info:
            print(f"\nINFO ({len(self.info)}):")
            print("-" * W)
            for i, inf in enumerate(self.info, 1):
                print(f"{i}. {inf}")

        # Rich diagnostics
        if self.diagnostics:
            print("\n" + "=" * W)
            print("DETAILED DIAGNOSTICS")
            print("=" * W)
            for diag in self.diagnostics:
                print()
                print(diag.render())

        print("\n" + "=" * W)
        if self.errors:
            print("RESULT: FAILED — Fix errors before running model")
            print("=" * W)
            return 1
        elif self.warnings:
            print("RESULT: PASSED WITH WARNINGS")
            print("=" * W)
            return 0
        else:
            print("RESULT: PASSED — Data is valid")
            print("=" * W)
            return 0


# ------------------------------------------------------------------------------
# Entry point
# ------------------------------------------------------------------------------

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 check_data_consistency.py <file1.dat> [file2.dat] ...")
        return 1

    validator = DataValidator()
    validator.validate_files(sys.argv[1:])
    return 0 if not validator.errors else 1


if __name__ == "__main__":
    sys.exit(main())
