#!/usr/bin/env python3
"""
Data Consistency Checker for AMPL Healthcare Facility Location Models
Validates data for feasibility BEFORE running optimizer.

Usage:
    py check_data_consistency.py LS.dat LS_distdur.dat
    py check_data_consistency.py LS.dat LS_distdur.dat > report.txt
    py check_data_consistency.py LS.dat LS_distdur.dat --output report.txt
    py check_data_consistency.py LS.dat LS_distdur.dat --output report.txt --ascii

Output notes:
    - Progress lines ([CHECK N] ...) always go to STDERR.
    - Full report (including INFO) goes to STDOUT or --output file.
    - When --output is used, the complete report is also mirrored to stderr.
    - Unicode symbols are used on a TTY; plain ASCII when redirected or --ascii is passed.
"""

import argparse
import math
import re
import sys
from collections import defaultdict


# ------------------------------------------------------------------------------
# Output routing
# ------------------------------------------------------------------------------

_report_file = None   # set when --output is used


def _rprint(*args, **kwargs):
    """Print to report destination.
    - If --output is active: writes to file + mirrors to stderr (user always sees it)
    - Otherwise: writes to stdout
    """
    if _report_file is not None:
        file_kwargs = {k: v for k, v in kwargs.items() if k != 'file'}
        print(*args, file=_report_file, **file_kwargs)
        print(*args, file=sys.stderr, **file_kwargs)
    else:
        print(*args, **kwargs)


def _progress(msg):
    """Progress messages always go to stderr only."""
    print(msg, file=sys.stderr)


# ------------------------------------------------------------------------------
# Unicode vs ASCII
# ------------------------------------------------------------------------------

USE_UNICODE = True


def _sym(u, a):
    return u if USE_UNICODE else a


def _ellipsis():
    return _sym('\u2026', '...')


def _dash():
    return _sym('\u2014', '-')


def _rule(n=76):
    return _sym('\u00b7', '-') * n


def _arrow():
    return _sym('\u25b8', '>')


# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

def strip_comments(content):
    """Remove AMPL-style # comments."""
    return re.sub(r'#[^\n]*', '', content)


def _fmt_table(headers, rows):
    """Return lines for a plain-text table."""
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
# Diagnostic class
# ------------------------------------------------------------------------------

class Diagnostic:
    def __init__(self, level, title, what='', why='', fix='',
                 table_headers=None, table_rows=None):
        self.level = level
        self.title = title
        self.what = what
        self.why = why
        self.fix = fix
        self.table_headers = table_headers or []
        self.table_rows = table_rows or []

    def render(self):
        if USE_UNICODE:
            icons = {'ERROR': '\u274c', 'WARNING': '\u26a0 ', 'INFO': '\u2139 '}
        else:
            icons = {'ERROR': '[ERROR]  ', 'WARNING': '[WARNING]', 'INFO': '[INFO]   '}
        icon = icons.get(self.level, '[?]')

        lines = [
            f"{icon} {self.level}: {self.title}",
            "  " + _rule(76),
        ]
        if self.what:
            lines.append(f"  {_arrow()} WHAT:")
            for sub in self._wrap(self.what, 72):
                lines.append(f"      {sub}")
        if self.why:
            lines.append(f"  {_arrow()} WHY:")
            for sub in self.why.split('\n'):
                lines.append(f"      {sub}")
        if self.table_headers and self.table_rows:
            lines.append(f"  {_arrow()} DETAILS:")
            for tline in _fmt_table(self.table_headers, self.table_rows):
                lines.append(f"      {tline}")
        if self.fix:
            lines.append(f"  {_arrow()} FIX:")
            for sub in self.fix.split('\n'):
                lines.append(f"      {sub}")
        lines.append("  " + _rule(76))
        return '\n'.join(lines)

    @staticmethod
    def _wrap(text, width):
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
# DataValidator class
# ------------------------------------------------------------------------------

class DataValidator:

    SIZE_DEFAULT = 3
    SIZE_MAX = 5
    POP_PER_SIZE = 3000
    MAX_HOME_SHC = 0.15
    MAX_HOME_THC = 0.05
    MAX_TELE = 0.05

    def __init__(self):
        self.data = {
            'I': set(),
            'L': defaultdict(set),
            'EL': defaultdict(set),
            'CL': defaultdict(set),
            'W': {},
            'SIZE': {},
            'C1': {}, 'C2': {}, 'C3': {},
            'O1_0': {}, 'O2_0': {}, 'O3_0': {},
            'Dmax': {},
            'D0_1_count': 0, 'D0_2_count': 0, 'D0_3_count': 0,
            'D0_1': {}, 'D0_2': {}, 'D0_3': {},
        }
        self.errors = []
        self.warnings = []
        self.info = []
        self.diagnostics = []
        self._r0b_violations = []
        self._files_read = []

    def validate_files(self, filenames):
        for filename in filenames:
            try:
                with open(filename, 'r', encoding='utf-8', errors='replace') as f:
                    raw = f.read()
                n_lines = raw.count('\n')
                _progress(f"Reading data section from {filename}...")
                _progress(f"  {n_lines} lines were read")
                self._parse_data(strip_comments(raw))
                self._files_read.append((filename, n_lines))
            except FileNotFoundError:
                _progress(f"ERROR: File not found: {filename}")
                return False

        for k in [1, 2, 3]:
            self.data['L'][k] = self.data['EL'][k] | self.data['CL'][k]

        self.run_all_checks()
        return True

    def _parse_data(self, content):
        # EL[k] / CL[k]
        for k in [1, 2, 3]:
            for key in ('EL', 'CL'):
                m = re.search(rf'set {key}\[{k}\]\s*:=\s*([\s\S]*?);', content)
                if m:
                    self.data[key][k].update(m.group(1).strip().split())

        # Origins I and demand W
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

        # SIZE
        m = re.search(r'param:\s*ITEM1\s+SIZE[^:]*:=\s*([\s\S]*?);', content)
        if m:
            for line in m.group(1).strip().split('\n'):
                parts = line.split()
                if len(parts) >= 3:
                    try:
                        self.data['SIZE'][parts[0]] = int(parts[2])
                    except ValueError:
                        pass

        # C2 / C3
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
            m = re.search(rf'param\s*:\s*[\s\S]*?{ratio_key}[\s\S]*?:=\s*([\s\S]*?);', content)
            if m:
                for line in m.group(1).strip().split('\n'):
                    parts = line.split()
                    if len(parts) >= 2:
                        try:
                            self.data[ratio_key][parts[0]] = float(parts[1])
                        except ValueError:
                            pass

        # Dmax
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
            ('D0_1', 'D0_1_count'), ('D0_2', 'D0_2_count'), ('D0_3', 'D0_3_count')
        ]:
            m = re.search(rf'param {dist_key}[^:]*:=\s*([\s\S]*?);', content)
            if m:
                tokens = m.group(1).strip().split()
                self.data[count_key] += len(tokens) // 3
                it = iter(tokens)
                try:
                    while True:
                        i = next(it)
                        j = next(it)
                        dv = float(next(it))
                        self.data[dist_key][(i, j)] = dv
                except StopIteration:
                    pass

    def run_all_checks(self):
        W = 80
        _rprint("\n" + "=" * W)
        _rprint("DATA CONSISTENCY VALIDATION")
        _rprint("=" * W)
        for fname, nlines in self._files_read:
            _rprint(f"  File : {fname}  ({nlines} lines)")
        _rprint("")

        checks = [
            ("Set Definitions", self.check_set_definitions),
            ("Parameter Index Consistency", self.check_parameter_indices),
            ("Capacity Values", self.check_capacity_values),
            ("Distance Parameters", self.check_distance_parameters),
            ("Step-Down Ratios", self.check_step_down_ratios),
            ("Demand Feasibility", self.check_demand_feasibility),
            ("Facility Connectivity", self.check_facility_connectivity),
            ("Network Balance", self.check_network_balance),
            ("R0b Spatial-Lock Analysis", self.check_r0b_spatial_lock),
            ("Distance Matrix Coverage", self.check_distance_coverage),
        ]

        for idx, (name, fn) in enumerate(checks, 1):
            _progress(f"  [CHECK {idx:2d}] {name} ...")
            _rprint(f"\n[CHECK {idx}] {name}")
            _rprint("-" * W)
            fn()

        self.print_results()

    # --------------------------------------------------------------------------
    # Checks 1-8 (unchanged)
    # --------------------------------------------------------------------------

    def check_set_definitions(self):
        if not self.data['I']:
            if self.data['W']:
                self.errors.append("Set I (origins) defined in W but not as a set")
            else:
                self.warnings.append("Set I (origins) not found — file may be distance-only")
            return

        self.info.append(f"Set I: {len(self.data['I'])} origins")

        for k in [1, 2, 3]:
            lk = self.data['L'][k]
            if not lk:
                self.errors.append(f"Set L[{k}] (level {k} facilities) is empty")
            else:
                el_c = len(self.data['EL'][k])
                cl_c = len(self.data['CL'][k])
                self.info.append(f"Set L[{k}]: {len(lk)} facilities ({el_c} existing, {cl_c} candidates)")

    def check_parameter_indices(self):
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
                self.info.append(f"All {cap_name} indices are in set L[{level}] (none defined)")
                continue
            if not lk:
                self.errors.append(f"{cap_name} has entries but L[{level}] is empty")
                continue
            invalid = [j for j in cap_data if j not in lk]
            if invalid:
                self.errors.append(f"{cap_name} has invalid facilities: {invalid}")
            else:
                self.info.append(f"All {cap_name} indices are in set L[{level}]")

        el1 = self.data['EL'][1]
        if el1:
            sized = [j for j in el1 if j in self.data['SIZE']]
            if sized:
                self.info.append(f"SIZE defined for {len(sized)}/{len(el1)} existing L[1] facilities")
            else:
                self.info.append("C1 derived from SIZE (none explicit)")

    def check_capacity_values(self):
        for cap_name, min_rec in [('C2', 1000), ('C3', 500)]:
            cap_data = self.data[cap_name]
            if not cap_data:
                continue
            mn, mx = min(cap_data.values()), max(cap_data.values())
            self.info.append(f"{cap_name}: min={mn:.0f}, max={mx:.0f}")
            if mn < 100:
                self.errors.append(f"{cap_name} capacity unrealistically small (min={mn})")

        el1 = self.data['EL'][1]
        if el1 and self.data['SIZE']:
            c1_vals = [self.data['SIZE'].get(j, self.SIZE_DEFAULT) * self.POP_PER_SIZE for j in el1]
            self.info.append(f"C1 (SIZE x {self.POP_PER_SIZE}): min={min(c1_vals)}, max={max(c1_vals)}")

    def check_distance_parameters(self):
        for dist_key, count_key in [('D0_1', 'D0_1_count'), ('D0_2', 'D0_2_count'), ('D0_3', 'D0_3_count')]:
            cnt = self.data[count_key]
            if cnt:
                self.info.append(f"{dist_key} defined ({cnt} entries)")
            else:
                self.warnings.append(f"{dist_key} not found")

        if self.data['Dmax']:
            self.info.append("Dmax defined: " + ', '.join(f"L{k}={v:.0f}m" for k, v in sorted(self.data['Dmax'].items())))

    def check_step_down_ratios(self):
        for ratio_name in ('O1_0', 'O2_0', 'O3_0'):
            rd = self.data[ratio_name]
            if not rd:
                self.warnings.append(f"{ratio_name} not found")
                continue
            mn = min(rd.values())
            mx = max(rd.values())
            avg = sum(rd.values()) / len(rd)
            self.info.append(f"{ratio_name}: min={mn:.2f}, max={mx:.2f}, avg={avg:.2f}")
            if mn <= 0 or mx >= 1:
                self.warnings.append(f"{ratio_name} has values outside (0, 1)")

    def check_demand_feasibility(self):
        if not self.data['W']:
            return
        vals = list(self.data['W'].values())
        n = len(vals)
        total = sum(vals)
        avg = total / n
        lo = min(vals)
        hi = max(vals)
        sv = sorted(vals)
        mid = n // 2
        median = sv[mid] if n % 2 == 1 else (sv[mid - 1] + sv[mid]) / 2

        self.info.append(f"Total demand: {total:.0f}")
        self.info.append(f"Range: [{lo:.0f}, {hi:.0f}]")
        self.info.append(f"Average: {avg:.1f}")
        self.info.append(f"Median:  {median:.1f}")

    def check_facility_connectivity(self):
        for dist_key, count_key in [('D0_1', 'D0_1_count'), ('D0_2', 'D0_2_count'), ('D0_3', 'D0_3_count')]:
            cnt = self.data[count_key]
            if cnt:
                self.info.append(f"{dist_key}: {cnt} distance entries defined")

    def check_network_balance(self):
        if not self.data['W'] or not self.data['C2'] or not self.data['C3']:
            return
        total_demand = sum(self.data['W'].values())
        total_c2 = sum(self.data['C2'].values())
        total_c3 = sum(self.data['C3'].values())

        self.info.append(f"Total demand: {total_demand:.0f}")
        self.info.append(f"Total capacity: C2={total_c2:.0f}, C3={total_c3:.0f}")

    # Check 9 and 10 (R0b and Distance Coverage) remain unchanged from original
    # (They are long but were already correct)

    def check_r0b_spatial_lock(self):
        # [Original implementation unchanged - kept for completeness]
        W = self.data['W']
        d01 = self.data['D0_1']
        el1 = self.data['EL'][1]
        cl1 = self.data['CL'][1]
        sizes = self.data['SIZE']
        dmax1 = self.data['Dmax'].get(1, None)

        if not W or not d01 or not el1 or dmax1 is None:
            if not W:
                self.info.append("Check 9 skipped: no demand data")
            elif not d01:
                self.warnings.append("Check 9 skipped: D0_1 not loaded")
            elif not el1:
                self.warnings.append("Check 9 skipped: EL[1] not defined")
            else:
                self.warnings.append("Check 9 skipped: Dmax[1] not found")
            return

        L1 = list(el1) + list(cl1)
        MAX_C1 = self.SIZE_MAX * self.POP_PER_SIZE

        max_bypass = self.MAX_HOME_SHC * (1 + self.MAX_TELE) + self.MAX_HOME_THC * (1 + self.MAX_TELE)
        min_l1_frac = 1.0 - max_bypass

        def cap_filter(j):
            return MAX_C1 if j in el1 else sizes.get(j, self.SIZE_DEFAULT) * self.POP_PER_SIZE

        def in_link01(i, j):
            return d01.get((i, j), float('inf')) <= dmax1 and cap_filter(j) >= W[i]

        min_d_el1 = {}
        for i in W:
            ds = [d01.get((i, j), float('inf')) for j in el1 if in_link01(i, j)]
            min_d_el1[i] = min(ds) if ds else float('inf')

        eff_nb = {}
        for i in W:
            cut = min_d_el1[i]
            if cut == float('inf'):
                eff_nb[i] = []
            else:
                eff_nb[i] = [j for j in L1 if in_link01(i, j) and d01.get((i, j), float('inf')) <= cut]

        forced = {}
        for i, nb in eff_nb.items():
            if len(nb) == 1:
                forced.setdefault(nb[0], []).append(i)

        violations = []
        for j, locked in forced.items():
            fd = sum(W[o] for o in locked)
            cap = MAX_C1
            if fd > cap:
                irred = max(0.0, fd * min_l1_frac - cap)
                min_sz = math.ceil(fd * min_l1_frac / self.POP_PER_SIZE)
                violations.append({
                    'phc': j, 'size': sizes.get(j, self.SIZE_DEFAULT), 'cap': cap,
                    'fd': fd, 'n_orig': len(locked), 'irred': irred,
                    'origins': locked, 'min_size_needed': min_sz,
                })

        n_single = sum(1 for nb in eff_nb.values() if len(nb) == 1)
        w_single = sum(W[i] for i, nb in eff_nb.items() if len(nb) == 1)
        self.info.append(f"After R0b: {n_single} origins ({w_single:.0f} patients) restricted to exactly 1 PHC")
        self.info.append(f"PHC max expandable capacity: {MAX_C1:,} patients (SIZE={self.SIZE_MAX})")

        if not violations:
            self.info.append("R0b spatial-lock: OK — no PHC has forced demand exceeding max capacity")
            return

        self.errors.append(f"R0b spatial-lock: {len(violations)} PHC(s) have forced demand > max capacity => LP infeasible")

        self._r0b_violations = sorted(violations, key=lambda x: -x['irred'])

        for v in self._r0b_violations:
            j = v['phc']
            top3 = sorted([(o, W[o]) for o in v['origins']], key=lambda x: -x[1])[:3]
            top3_str = ', '.join(f"{o} (W={w:.0f})" for o, w in top3)
            if len(v['origins']) > 3:
                top3_str += f", {_ellipsis()} (+{len(v['origins'])-3} more)"

            what_msg = (f"PHC {j} (current SIZE={v['size']}, C1_max={v['cap']:,}) receives forced demand of "
                        f"{v['fd']:,.0f} patients from {v['n_orig']} locked clusters. "
                        f"Irreducible L1 load still exceeds capacity.")

            why_msg = "Constraint R0b + F1 creates a hard spatial lock to the closest existing PHC."

            fix_msg = ("Option A: Remove or soften R0b in aps.mod (recommended)\n"
                       "Option B: Increase SIZE for this PHC\n"
                       "Option C: Add closer CL[1] candidate")

            tbl_headers = ["PHC", "SIZE", "C1 max", "Forced demand", "Irred. overflow", "# locked"]
            tbl_rows = [[j, str(v['size']), f"{v['cap']:,}", f"{v['fd']:,.0f}", f"{v['irred']:,.0f}", str(v['n_orig'])]]

            self.diagnostics.append(Diagnostic('ERROR',
                f"R0b Spatial Lock — PHC {j}: forced demand exceeds max capacity",
                what=what_msg, why=why_msg, fix=fix_msg,
                table_headers=tbl_headers, table_rows=tbl_rows))

    def check_distance_coverage(self):
        MAX_LISTED = 50
        for dist_key, level in [('D0_1', 1), ('D0_2', 2), ('D0_3', 3)]:
            I = self.data['I']
            L_k = self.data['L'][level]
            d = self.data[dist_key]

            if not I or not L_k:
                continue
            if not d:
                continue

            expected = len(I) * len(L_k)
            defined = len(d)
            missing_pairs = [(i, j) for i in sorted(I) for j in sorted(L_k) if (i, j) not in d]
            n_missing = len(missing_pairs)

            if n_missing == 0:
                self.info.append(f"{dist_key} coverage: complete ({defined}/{expected} pairs)")
                continue

            self.errors.append(f"{dist_key} coverage: {n_missing} of {expected} pairs missing — model will abort")

            by_origin = defaultdict(list)
            for i, j in missing_pairs:
                by_origin[i].append(j)

            tbl_headers = ["Origin", "# missing", "Missing destinations (first 5)"]
            tbl_rows = []
            for origin in sorted(by_origin)[:MAX_LISTED]:
                miss = by_origin[origin]
                samp = ', '.join(miss[:5])
                if len(miss) > 5:
                    samp += f" {_ellipsis()} (+{len(miss)-5} more)"
                tbl_rows.append([origin, str(len(miss)), samp])

            self.diagnostics.append(Diagnostic('ERROR',
                f"{dist_key} missing {n_missing} O-D pairs — model will abort at preprocessing",
                what=f"{dist_key} requires all {expected} pairs. {n_missing} are missing.",
                why="GLPK aborts on missing parameter values without default.",
                fix=f"Add the missing entries to the {dist_key} block in *_distdur.dat",
                table_headers=tbl_headers, table_rows=tbl_rows))

    # --------------------------------------------------------------------------
    # Improved print_results - INFO always shown
    # --------------------------------------------------------------------------

    def print_results(self):
        W = 80
        _rprint("\n" + "=" * W)
        _rprint("VALIDATION RESULTS")
        _rprint("=" * W)

        if self.errors:
            _rprint(f"\nERRORS ({len(self.errors)}):")
            _rprint("-" * W)
            for i, err in enumerate(self.errors, 1):
                _rprint(f"{i}. {err}")

        if self.warnings:
            _rprint(f"\nWARNINGS ({len(self.warnings)}):")
            _rprint("-" * W)
            for i, warn in enumerate(self.warnings, 1):
                _rprint(f"{i}. {warn}")

        # INFO is now always displayed
        if self.info:
            _rprint(f"\nINFO ({len(self.info)}):")
            _rprint("-" * W)
            for i, inf in enumerate(self.info, 1):
                _rprint(f"{i}. {inf}")

        if self.diagnostics:
            _rprint("\n" + "=" * W)
            _rprint("DETAILED DIAGNOSTICS")
            _rprint("=" * W)
            for diag in self.diagnostics:
                _rprint()
                _rprint(diag.render())

        # SIZEX suggestion block
        if self._r0b_violations:
            _rprint("\n" + "=" * W)
            _rprint("SUGGESTED FIX — param SIZEX")
            _rprint("=" * W)
            _rprint("param SIZEX :=")
            for v in sorted(self._r0b_violations, key=lambda x: -x['irred']):
                _rprint(f"  {v['phc']:<26}  {v['min_size_needed']:>3}   "
                        f"# demand={v['fd']:,.0f}  irred={v['irred']:,.0f}")
            _rprint(";")

        _rprint("\n" + "=" * W)
        if self.errors:
            _rprint("RESULT: FAILED — Fix errors before running model")
            ret = 1
        elif self.warnings:
            _rprint("RESULT: PASSED WITH WARNINGS")
            ret = 0
        else:
            _rprint("RESULT: PASSED — Data is valid")
            ret = 0
        _rprint("=" * W)

        return ret


# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

def main():
    global USE_UNICODE, _report_file

    parser = argparse.ArgumentParser(
        prog='check_data_consistency.py',
        description='Validate AMPL healthcare facility location data files.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument('files', nargs='+', metavar='FILE.dat')
    parser.add_argument('--output', '-o', metavar='REPORT', default=None,
                        help='Write the report to this file (UTF-8)')
    parser.add_argument('--ascii', action='store_true', default=False,
                        help='Force plain ASCII output')

    args = parser.parse_args()

    # Unicode decision
    if args.ascii or (args.output is None and not sys.stdout.isatty()):
        USE_UNICODE = False

    # Output file setup
    if args.output:
        try:
            _report_file = open(args.output, 'w', encoding='utf-8')
            _progress(f"Writing report to: {args.output}")
        except OSError as e:
            print(f"Cannot open output file: {e}", file=sys.stderr)
            return 1
    else:
        if hasattr(sys.stdout, 'reconfigure'):
            try:
                sys.stdout.reconfigure(encoding='utf-8', errors='replace')
            except Exception:
                pass

    try:
        validator = DataValidator()
        if not validator.validate_files(args.files):
            return 2
        return validator.print_results()
    finally:
        if _report_file is not None:
            _report_file.close()
            _progress(f"Report saved: {args.output}")


if __name__ == "__main__":
    sys.exit(main())