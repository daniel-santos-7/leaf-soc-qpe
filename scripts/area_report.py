#!/usr/bin/env python3
# ----------------------------------------------------------------------
# Leaf project
# developed by: Daniel Santos
# module: area report from a Yosys gate-level stat log
# 2026
# ----------------------------------------------------------------------

import argparse
import re
import sys

GATE_COST = {
    "$_BUF_": 0, "$_NOT_": 2,
    "$_NAND_": 4, "$_NOR_": 4,
    "$_AND_": 6, "$_OR_": 6, "$_ANDNOT_": 6, "$_ORNOT_": 6,
    "$_AOI3_": 6, "$_OAI3_": 6, "$_AOI4_": 8, "$_OAI4_": 8,
    "$_XOR_": 12, "$_XNOR_": 12, "$_NMUX_": 10, "$_MUX_": 12,
}


def ff_cost(cell, args):
    cost = args.ff
    if "DFFE" in cell or "DFFCE" in cell or "DFFSRE" in cell:
        cost += args.ff_en
    if cell.startswith("$_SDFF"):
        cost += args.ff_srst
    return cost


def parse(path, args):
    text = open(path).read()
    end = text.find("=== design hierarchy ===")
    if end < 0:
        sys.exit(f"{path}: no 'design hierarchy' section, run stat on a hierarchical design")
    parts = re.split(r"^=== (\S+) ===$", text[:end], flags=re.M)
    local, ffs, subs, unknown = {}, {}, {}, set()
    for name, body in zip(parts[1::2], parts[2::2]):
        cost = flops = 0
        children = {}
        for count, cell in re.findall(r"^\s+(\d+)\s+(\S+)$", body, flags=re.M):
            count = int(count)
            if cell in GATE_COST:
                cost += count * GATE_COST[cell]
            elif cell.startswith("$_") and "DFF" in cell:
                cost += count * ff_cost(cell, args)
                flops += count
            elif cell.startswith("$"):
                unknown.add(cell)
            else:
                children[cell] = children.get(cell, 0) + count
        local[name], ffs[name], subs[name] = cost, flops, children
    for name in subs:
        subs[name] = {c: n for c, n in subs[name].items() if c in local}
    return local, ffs, subs, unknown


def main():
    ap = argparse.ArgumentParser(description="Per-module area table from a Yosys gate-level 'stat' log.")
    ap.add_argument("log")
    ap.add_argument("--top", default="leaf_soc")
    ap.add_argument("--depth", type=int, default=3)
    ap.add_argument("--ff", type=int, default=24)
    ap.add_argument("--ff-en", type=int, default=12)
    ap.add_argument("--ff-srst", type=int, default=6)
    args = ap.parse_args()

    local, ffs, subs, unknown = parse(args.log, args)
    if args.top not in local:
        sys.exit(f"{args.log}: module {args.top} not found")

    memo = {}

    def total(m):
        if m not in memo:
            memo[m] = (local[m] + sum(n * total(c)[0] for c, n in subs[m].items()),
                       ffs[m] + sum(n * total(c)[1] for c, n in subs[m].items()))
        return memo[m]

    def label(m):
        return re.sub(r"\(rtl\)$", "", re.sub(r"_B([A-Za-z0-9]+?)(_\w*)?$", r"(\1)", m))

    top_area, top_ff = total(args.top)
    rows = [(f"**{args.top}** (total)", top_area, top_ff)]
    if local[args.top]:
        rows.append(("logic in " + args.top, local[args.top], ffs[args.top]))

    def walk(m, depth, prefix):
        kids = sorted(subs[m].items(), key=lambda kv: -kv[1] * total(kv[0])[0])
        for i, (c, n) in enumerate(kids):
            last = i == len(kids) - 1
            branch = "" if depth == 1 else prefix + ("└ " if last else "├ ")
            mult = f" ×{n}" if n > 1 else ""
            area, flops = total(c)
            rows.append((branch + label(c) + mult, n * area, n * flops))
            if depth < args.depth:
                walk(c, depth + 1, "" if depth == 1 else prefix + ("  " if last else "│ "))

    walk(args.top, 1, "")

    print(f"| Module | Transistors (est.) | % of total | Flip-flops |")
    print(f"|---|---:|---:|---:|")
    for name, area, flops in rows:
        print(f"| {name} | {area:,} | {100 * area / top_area:.2f}% | {flops:,} |".replace(",", " "))
    print()
    print(f"Weights: gates as Yosys 'stat -tech cmos'; flip-flop {args.ff}, "
          f"+{args.ff_en} with enable, +{args.ff_srst} with synchronous reset. "
          "Black boxes (hard macros) count as zero.")
    if unknown:
        print("Cells without a weight (counted as zero): " + ", ".join(sorted(unknown)))


if __name__ == "__main__":
    main()
