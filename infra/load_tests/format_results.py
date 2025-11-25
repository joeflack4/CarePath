#!/usr/bin/env python3
"""
Format and display load test results from Locust CSV output.

Usage:
    python format_results.py [results_dir]

If no directory is specified, uses ./results/ in the same directory as this script.
"""

import csv
import os
import sys
from datetime import datetime
from pathlib import Path


def find_latest_results(results_dir: Path) -> tuple[Path | None, Path | None]:
    """Find the most recent stats and failures CSV files."""
    stats_files = sorted(results_dir.glob("*_stats.csv"), key=os.path.getmtime, reverse=True)
    failures_files = sorted(results_dir.glob("*_failures.csv"), key=os.path.getmtime, reverse=True)

    stats_file = stats_files[0] if stats_files else None
    failures_file = failures_files[0] if failures_files else None

    return stats_file, failures_file


def parse_stats(stats_file: Path) -> list[dict]:
    """Parse the stats CSV file."""
    with open(stats_file, "r") as f:
        reader = csv.DictReader(f)
        return list(reader)


def parse_failures(failures_file: Path) -> list[dict]:
    """Parse the failures CSV file."""
    if not failures_file or not failures_file.exists():
        return []
    with open(failures_file, "r") as f:
        reader = csv.DictReader(f)
        return list(reader)


def format_duration(ms: float) -> str:
    """Format milliseconds to human-readable duration."""
    if ms < 1000:
        return f"{ms:.0f}ms"
    elif ms < 60000:
        return f"{ms / 1000:.2f}s"
    else:
        return f"{ms / 60000:.2f}m"


def print_results(stats: list[dict], failures: list[dict], stats_file: Path):
    """Print formatted results summary."""
    print("=" * 70)
    print("LOAD TEST RESULTS")
    print("=" * 70)
    print(f"Results file: {stats_file.name}")
    print(f"Generated: {datetime.fromtimestamp(stats_file.stat().st_mtime)}")
    print()

    # Find aggregated row
    aggregated = None
    endpoints = []
    for row in stats:
        if row.get("Name") == "Aggregated":
            aggregated = row
        elif row.get("Name"):
            endpoints.append(row)

    if aggregated:
        print("-" * 70)
        print("SUMMARY")
        print("-" * 70)

        total_requests = int(aggregated.get("Request Count", 0))
        total_failures = int(aggregated.get("Failure Count", 0))
        error_rate = (total_failures / total_requests * 100) if total_requests > 0 else 0

        avg_response = float(aggregated.get("Average Response Time", 0))
        p50 = float(aggregated.get("50%", 0))
        p95 = float(aggregated.get("95%", 0))
        p99 = float(aggregated.get("99%", 0))
        rps = float(aggregated.get("Requests/s", 0))

        print(f"Total Requests:    {total_requests:,}")
        print(f"Total Failures:    {total_failures:,}")
        print(f"Error Rate:        {error_rate:.2f}%")
        print()
        print(f"Requests/sec:      {rps:.2f}")
        print()
        print("Response Times:")
        print(f"  Average:         {format_duration(avg_response)}")
        print(f"  P50 (median):    {format_duration(p50)}")
        print(f"  P95:             {format_duration(p95)}")
        print(f"  P99:             {format_duration(p99)}")
        print()

        # P95 threshold check
        p95_threshold_ms = 100
        if p95 <= p95_threshold_ms:
            print(f"  P95 Target (100ms): PASS ({format_duration(p95)})")
        else:
            print(f"  P95 Target (100ms): FAIL ({format_duration(p95)} > 100ms)")

    if endpoints:
        print()
        print("-" * 70)
        print("BY ENDPOINT")
        print("-" * 70)
        print(f"{'Endpoint':<35} {'Reqs':>8} {'Fail':>6} {'Avg':>10} {'P95':>10}")
        print("-" * 70)
        for row in endpoints:
            name = row.get("Name", "")[:35]
            reqs = int(row.get("Request Count", 0))
            fails = int(row.get("Failure Count", 0))
            avg = float(row.get("Average Response Time", 0))
            p95 = float(row.get("95%", 0))
            print(f"{name:<35} {reqs:>8} {fails:>6} {format_duration(avg):>10} {format_duration(p95):>10}")

    if failures:
        print()
        print("-" * 70)
        print("FAILURES")
        print("-" * 70)
        for failure in failures[:10]:  # Show top 10 failures
            method = failure.get("Method", "")
            name = failure.get("Name", "")
            error = failure.get("Error", "")[:60]
            count = failure.get("Occurrences", "")
            print(f"{method} {name}: {error} (x{count})")

    print()
    print("=" * 70)


def main():
    # Determine results directory
    script_dir = Path(__file__).parent
    if len(sys.argv) > 1:
        results_dir = Path(sys.argv[1])
    else:
        results_dir = script_dir / "results"

    if not results_dir.exists():
        print(f"Results directory not found: {results_dir}")
        print("Run a load test first to generate results.")
        sys.exit(1)

    stats_file, failures_file = find_latest_results(results_dir)

    if not stats_file:
        print(f"No results found in {results_dir}")
        print("Run a load test first to generate results.")
        sys.exit(1)

    stats = parse_stats(stats_file)
    failures = parse_failures(failures_file) if failures_file else []

    print_results(stats, failures, stats_file)


if __name__ == "__main__":
    main()
