#!/usr/bin/env python3
"""Report original subjective anchors as percentiles of the no-anchor distribution.

Writes analyses/results/originalAnchorPercentiles/originalAnchorPercentiles.txt
"""

from __future__ import annotations

import csv
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
CSV_PATH = REPO / "data" / "anchorYearsDecontaminatedLong.csv"
OUT_DIR = REPO / "analyses" / "results" / "originalAnchorPercentiles"
OUT_TXT = OUT_DIR / "originalAnchorPercentiles.txt"

# Manuscript Table 1 order; data_q is question index in the long CSV.
TABLE = [
    ("Revolutionary War", 1775, 1730, 1820, 9),
    ("Great Depression", 1929, 1910, 1950, 4),
    ("Disneyland", 1955, 1920, 1980, 3),
    ("McDonald's", 1955, 1920, 1980, 8),
    ("Reagan", 1981, 1960, 2000, 10),
    ("Thriller", 1983, 1970, 1990, 1),
    ("Internet", 1983, 1960, 1990, 2),
    ("Pixar", 1995, 1990, 2000, 11),
    ("Firefox", 2004, 1970, 2010, 6),
    ("YouTube", 2005, 1990, 2010, 7),
    ("iPhone", 2007, 1990, 2010, 5),
]


def percentile_rank(y: list[float], x: float) -> tuple[float, float, int, int, int, int]:
    n = len(y)
    n_lt = sum(1 for v in y if v < x)
    n_eq = sum(1 for v in y if v == x)
    n_le = n_lt + n_eq
    mid = 100.0 * (n_lt + 0.5 * n_eq) / n
    cdf = 100.0 * n_le / n
    return mid, cdf, n_lt, n_eq, n_le, n


def load_rows() -> list[dict]:
    rows = []
    with open(CSV_PATH, newline="") as f:
        reader = csv.reader(f)
        header = [h.strip() for h in next(reader)]
        for raw in reader:
            d = dict(zip(header, [c.strip() for c in raw]))
            rows.append(
                {
                    "question": int(float(d["question"])),
                    "version": int(float(d["version"])),
                    "truth": float(d["truth"]),
                    "estimate": float(d["estimate"]),
                }
            )
    return rows


def main() -> None:
    rows = load_rows()
    lines: list[str] = []
    w = lines.append
    w("Original event-years: subjective anchors as percentiles of the no-anchor distribution")
    w("=" * 84)
    w("")
    w("Purpose: for each original (subjectively chosen) low/high anchor, report where that")
    w("value falls in the empirical distribution of no-anchor estimates for the same question.")
    w("This answers the R2 reviewer request to compare subjective anchors to percentile-based")
    w("anchors (e.g., Barrera Experiment 2 used 5% and 95%; F2026 replication used 1st/99th).")
    w("")
    w("Data: data/anchorYearsDecontaminatedLong.csv")
    w("No-anchor cohort: version == 3 (after contaminant removal).")
    w("Anchor values: original Low/High from manuscript Table 1.")
    w("")
    w("Percentile definitions:")
    w("  midrank_pct = 100 * (#estimates < anchor + 0.5 * #estimates == anchor) / n")
    w("  cdf_pct     = 100 * (#estimates <= anchor) / n")
    w("Primary reported value is midrank_pct (standard percentile rank).")
    w("")
    firefox_truths = sorted({r["truth"] for r in rows if r["question"] == 6})
    w(f"Note: Firefox truth in the long CSV is {firefox_truths}; manuscript uses 2004.")
    w("      Percentiles below use estimates only (truth not needed).")
    w("")

    hdr = (
        f'{"Question":<22} {"Truth":>5} {"Anchor":>6} {"Side":<4} '
        f'{"n":>3} {"min":>6} {"max":>6} {"mid%":>7} {"cdf%":>7} '
        f'{"#<":>3} {"#=":>3} {"#<=":>4}'
    )
    w(hdr)
    w("-" * len(hdr))

    summary = {}
    for label, truth, low, high, q in TABLE:
        y = [r["estimate"] for r in rows if r["question"] == q and r["version"] == 3]
        for side, a in (("Low", low), ("High", high)):
            mid, cdf, n_lt, n_eq, n_le, n = percentile_rank(y, a)
            w(
                f"{label:<22} {truth:5d} {a:6d} {side:<4} "
                f"{n:3d} {min(y):6.0f} {max(y):6.0f} {mid:7.1f} {cdf:7.1f} "
                f"{n_lt:3d} {n_eq:3d} {n_le:4d}"
            )
            summary.setdefault(label, {"truth": truth})
            summary[label][side] = (a, mid)

    w("")
    w("Compact Table-1 companion (midrank percentiles of original anchors in no-anchor group)")
    w("-" * 84)
    w(f'{"Question":<22} {"Truth":>5} {"Low":>6} {"Low%":>7} {"High":>6} {"High%":>7}')
    w("-" * 60)
    for label, truth, low, high, q in TABLE:
        lo_a, lo_p = summary[label]["Low"]
        hi_a, hi_p = summary[label]["High"]
        w(f"{label:<22} {truth:5d} {lo_a:6d} {lo_p:6.1f}% {hi_a:6d} {hi_p:6.1f}%")

    w("")
    w("Interpretation notes")
    w("-" * 20)
    w("- A Low% near 5 and High% near 95 would resemble Barrera Experiment 2 anchor placement.")
    w("- A Low% near 1 and High% near 99 would resemble the F2026 replication anchor rule.")
    w("- Subjective original anchors are often well inside the no-anchor range (not as extreme")
    w("  as 1st/99th), especially on the high side for recent events.")
    w("")
    w("Regenerate: python3 analyses/lib/report_original_anchor_percentiles.py")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    OUT_TXT.write_text("\n".join(lines) + "\n")
    print(f"Wrote {OUT_TXT}")


if __name__ == "__main__":
    main()
