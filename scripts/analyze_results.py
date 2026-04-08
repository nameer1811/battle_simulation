#!/usr/bin/env python3
"""
analyze_results.py — Aggregate and visualize grid sweep output CSVs.

Usage:
    python scripts/analyze_results.py [--output-dir OUTPUT_DIR] [--plots-dir PLOTS_DIR]

Defaults:
    --output-dir  output/grid
    --plots-dir   output/plots
"""

import argparse
import glob
import os
import sys

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns


METRICS = [
    "texian_casualties",
    "mexican_casualties",
    "mexican_captured",
    "cos_remaining",
    "battle_duration",
    "texian_side_morale",
    "mexican_side_morale",
]


def load_csvs(output_dir: str) -> pd.DataFrame:
    pattern = os.path.join(output_dir, "batch-*.csv")
    files = glob.glob(pattern)
    if not files:
        print(f"No CSV files found matching: {pattern}", file=sys.stderr)
        sys.exit(1)
    frames = [pd.read_csv(f) for f in files]
    df = pd.concat(frames, ignore_index=True)
    print(f"Loaded {len(files)} CSV files — {len(df):,} total rows")
    return df


def compute_summary(df: pd.DataFrame) -> pd.DataFrame:
    agg = {m: ["mean", "std", "min", "max"] for m in METRICS}
    agg["texian_win"] = "mean"
    summary = df.groupby(["mexican_concentration", "cos_fatigue"]).agg(agg)
    summary.columns = ["_".join(c).strip("_") for c in summary.columns]
    summary = summary.rename(columns={"texian_win_mean": "texian_win_rate"})
    summary["runs"] = df.groupby(["mexican_concentration", "cos_fatigue"]).size()
    return summary.reset_index()


def pivot_metric(summary: pd.DataFrame, col: str) -> pd.DataFrame:
    return summary.pivot(
        index="cos_fatigue", columns="mexican_concentration", values=col
    ).sort_index(ascending=False)


def save_heatmap(data: pd.DataFrame, title: str, path: str, fmt: str = ".2f", cmap: str = "RdYlGn"):
    fig, ax = plt.subplots(figsize=(10, 8))
    sns.heatmap(data, annot=True, fmt=fmt, cmap=cmap, ax=ax, linewidths=0.5)
    ax.set_title(title, fontsize=14)
    ax.set_xlabel("mexican_concentration")
    ax.set_ylabel("cos_fatigue")
    plt.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)
    print(f"  Saved: {path}")


def main():
    parser = argparse.ArgumentParser(description="Analyze battle simulation grid sweep results.")
    parser.add_argument("--output-dir", default=os.path.join("output", "grid"),
                        help="Directory containing batch-*.csv files (default: output/grid)")
    parser.add_argument("--plots-dir", default=os.path.join("output", "plots"),
                        help="Directory to write PNG heatmaps (default: output/plots)")
    args = parser.parse_args()

    os.makedirs(args.plots_dir, exist_ok=True)

    df = load_csvs(args.output_dir)
    summary = compute_summary(df)

    # Save merged raw data and per-config summary
    merged_path = os.path.join(args.output_dir, "merged.csv")
    summary_path = os.path.join(args.output_dir, "summary.csv")
    df.to_csv(merged_path, index=False)
    summary.to_csv(summary_path, index=False)
    print(f"Saved merged data:  {merged_path}")
    print(f"Saved summary data: {summary_path}")

    # Print quick stats
    print("\n--- Quick stats across all configurations ---")
    print(f"Configs: {len(summary)}")
    print(f"Runs per config (median): {summary['runs'].median():.0f}")
    print(f"Overall Texian win rate:  {df['texian_win'].mean():.1%}")
    print()

    # Generate heatmaps
    print("Generating heatmaps...")

    save_heatmap(
        pivot_metric(summary, "texian_win_rate"),
        "Texian Win Rate by Configuration",
        os.path.join(args.plots_dir, "win_rate.png"),
        fmt=".2f",
        cmap="RdYlGn",
    )

    for metric in METRICS:
        col = f"{metric}_mean"
        save_heatmap(
            pivot_metric(summary, col),
            f"Mean {metric.replace('_', ' ').title()} by Configuration",
            os.path.join(args.plots_dir, f"{metric}_mean.png"),
            fmt=".1f",
            cmap="viridis_r" if "casualt" in metric or "captured" in metric else "viridis",
        )

    print(f"\nAll plots saved to: {args.plots_dir}/")


if __name__ == "__main__":
    main()
