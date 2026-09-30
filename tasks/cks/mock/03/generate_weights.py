#!/usr/bin/env python3
"""Generate and verify Mock03 task weights from worker/files/tests.bats.

Modes:
  python3 generate_weights.py                Print the Markdown weight table.
  python3 generate_weights.py --check        Compare computed weights against the
                                              'Task weight' lines already present in
                                              README.MD and report any drift. Exits
                                              non-zero if README.MD is out of sync
                                              with tests.bats.
  python3 generate_weights.py --check-timed  Verify that worker/files/tests_timed.bats
                                              is an exact copy of the Init + Tasks 1-20
                                              portion of tests.bats (result file paths
                                              renamed to timed_all/timed_ok are the only
                                              allowed difference). Exits non-zero on any
                                              other drift, so Tasks 21-22 can never leak
                                              into the timed suite and Tasks 1-20 edits
                                              in tests.bats can't silently go stale in
                                              tests_timed.bats. Also validates, across the
                                              WHOLE tests.bats file, that @test task numbers
                                              are non-decreasing and that Tasks 0-20 are all
                                              present before the cutoff - a correlated drift
                                              where a later task ends up positioned before
                                              Task20 (e.g. after a bad manual edit) is
                                              rejected loudly instead of silently producing
                                              a truncated timed prefix that still matches an
                                              equally-truncated tests_timed.bats.

Both --check modes are manual pre-commit sanity checks after editing tests.bats,
tests_timed.bats, or README.MD - there is no CI integration by design.

The test file is the source of truth: each echo '<points>' >>
/var/work/tests/result/all contributes points to the task named by its BATS test.
"""

import sys
from collections import defaultdict
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
import re

TEST_FILE = Path(__file__).parent / "worker/files/tests.bats"
TIMED_TEST_FILE = Path(__file__).parent / "worker/files/tests_timed.bats"
README_FILE = Path(__file__).parent / "README.MD"
TIMED_LAST_TASK = 20
TEST_HEADER = re.compile(r'^@test\s+"(?P<task>\d+)(?:\.|\s)')
POINTS = re.compile(
    r"echo\s+['\"](?P<points>(?:\d+(?:\.\d+)?|\.\d+))['\"]\s*>>\s*"
    r"/var/work/tests/result/all\b"
)
README_TASK_HEADER = re.compile(r'\*\*(?P<task>\d+)\*\*')
README_WEIGHT_LINE = re.compile(r'\*{0,2}Task weight\*{0,2}\s*\|\s*(?P<percent>\d+(?:\.\d+)?)%')


def compute_weights() -> tuple[dict[int, Decimal], Decimal]:
    weights: dict[int, Decimal] = defaultdict(Decimal)
    current_task: int | None = None

    for line in TEST_FILE.read_text(encoding="utf-8").splitlines():
        header = TEST_HEADER.match(line)
        if header:
            current_task = int(header.group("task"))
            continue
        points = POINTS.search(line)
        if points and current_task is not None:
            weights[current_task] += Decimal(points.group("points"))

    weights.pop(0, None)  # BATS initialization is not a scored task.
    total = sum(weights.values(), Decimal())
    if not total:
        raise SystemExit(f"No task points found in {TEST_FILE}")
    return weights, total


def percent_table(weights: dict[int, Decimal], total: Decimal) -> dict[int, Decimal]:
    return {
        task: (weights[task] * Decimal(100) / total).quantize(
            Decimal("0.01"), rounding=ROUND_HALF_UP
        )
        for task in weights
    }


def print_table(percents: dict[int, Decimal], total: Decimal) -> None:
    print("| Task | Task weight |")
    print("| ---: | ---: |")
    for task in sorted(percents):
        print(f"| {task} | {percents[task]}% |")
    print(f"\nTotal points: {total}")


def parse_readme_weights() -> dict[int, Decimal]:
    """Parse the sequence of '**N**' task headers followed by 'Task weight | X%' rows."""
    text = README_FILE.read_text(encoding="utf-8")
    readme_weights: dict[int, Decimal] = {}
    pending_task: int | None = None
    for line in text.splitlines():
        header = README_TASK_HEADER.search(line)
        if header and 'Task weight' not in line:
            pending_task = int(header.group("task"))
            continue
        weight = README_WEIGHT_LINE.search(line)
        if weight and pending_task is not None:
            readme_weights[pending_task] = Decimal(weight.group("percent"))
            pending_task = None
    return readme_weights


def check() -> int:
    weights, total = compute_weights()
    computed = percent_table(weights, total)
    readme_weights = parse_readme_weights()

    all_tasks = sorted(set(computed) | set(readme_weights))
    mismatches = []
    for task in all_tasks:
        computed_pct = computed.get(task)
        readme_pct = readme_weights.get(task)
        if computed_pct is None:
            mismatches.append(f"Task {task}: present in README.MD but not in tests.bats")
        elif readme_pct is None:
            mismatches.append(f"Task {task}: present in tests.bats but not in README.MD")
        elif computed_pct != readme_pct:
            mismatches.append(
                f"Task {task}: README.MD says {readme_pct}%, tests.bats computes {computed_pct}%"
            )

    if mismatches:
        print("DRIFT DETECTED between README.MD and worker/files/tests.bats:")
        for m in mismatches:
            print(f"  - {m}")
        print("\nRe-run without --check to print the current table and update README.MD.")
        return 1

    print(f"OK: all {len(all_tasks)} task weights in README.MD match tests.bats (total points: {total}).")
    return 0


def extract_timed_prefix(last_task: int) -> str:
    """Return the exact source text of tests.bats up to (and including) the last
    @test block whose task number is <= last_task, using the same TEST_HEADER
    semantics as compute_weights() - i.e. a task boundary, not a hardcoded line
    number.

    Validates two invariants over the ENTIRE file (not just the returned prefix),
    so a correlated-drift case where a later task appears before an earlier one
    beyond the cutoff can't silently produce a truncated/wrong prefix:
      1. @test task numbers are non-decreasing across the whole file.
      2. The prefix actually contains every task ID in {0, 1, ..., last_task} -
         not just IDs up to the first task > last_task encountered.
    """
    lines = TEST_FILE.read_text(encoding="utf-8").splitlines(keepends=True)
    last_task_seen = -1
    cutoff_line_idx = None
    tasks_in_prefix: set[int] = set()

    for idx, line in enumerate(lines):
        header = TEST_HEADER.match(line)
        if not header:
            continue
        task = int(header.group("task"))
        if task < last_task_seen:
            raise SystemExit(
                f"{TEST_FILE}: @test task numbers are not in ascending order "
                f"at line {idx + 1} (task {task} follows task {last_task_seen}) - "
                "the timed-prefix boundary assumption no longer holds."
            )
        last_task_seen = task
        if cutoff_line_idx is None:
            if task > last_task:
                cutoff_line_idx = idx
            else:
                tasks_in_prefix.add(task)

    expected_tasks = set(range(0, last_task + 1))
    missing = expected_tasks - tasks_in_prefix
    if missing:
        raise SystemExit(
            f"{TEST_FILE}: the Init + Tasks 1-{last_task} prefix is missing task IDs "
            f"{sorted(missing)} even though ascending order holds for the tasks seen "
            "before the cutoff - check for gaps or a task number typo."
        )

    prefix_lines = lines if cutoff_line_idx is None else lines[:cutoff_line_idx]
    return "".join(prefix_lines)


def check_timed() -> int:
    if not TIMED_TEST_FILE.exists():
        print(f"MISSING: {TIMED_TEST_FILE} does not exist.")
        return 1

    expected_prefix = extract_timed_prefix(TIMED_LAST_TASK)
    # tests_timed.bats intentionally renames the result-file paths so the timed
    # suite doesn't clobber the full suite's result/all and result/ok when both
    # are run against the same worker.
    expected_timed = expected_prefix.replace(
        "/var/work/tests/result/all", "/var/work/tests/result/timed_all"
    ).replace(
        "/var/work/tests/result/ok", "/var/work/tests/result/timed_ok"
    )
    actual_timed = TIMED_TEST_FILE.read_text(encoding="utf-8")

    if expected_timed != actual_timed:
        print(
            f"DRIFT DETECTED: {TIMED_TEST_FILE.name} is not an exact copy of the "
            f"Init + Tasks 1-{TIMED_LAST_TASK} prefix of {TEST_FILE.name} "
            "(modulo the timed_all/timed_ok result-path rename)."
        )
        expected_lines = expected_timed.splitlines()
        actual_lines = actual_timed.splitlines()
        for i, (exp, act) in enumerate(zip(expected_lines, actual_lines), start=1):
            if exp != act:
                print(f"  first mismatch at line {i}:")
                print(f"    expected: {exp}")
                print(f"    actual:   {act}")
                break
        else:
            print(f"  files differ in length: expected {len(expected_lines)} lines, "
                  f"actual {len(actual_lines)} lines.")
        print(
            "\nRegenerate tests_timed.bats from the current tests.bats prefix "
            f"(Init + Tasks 1-{TIMED_LAST_TASK}), renaming result/all -> result/timed_all "
            "and result/ok -> result/timed_ok."
        )
        return 1

    print(
        f"OK: {TIMED_TEST_FILE.name} is an exact copy of the Init + Tasks "
        f"1-{TIMED_LAST_TASK} prefix of {TEST_FILE.name} (result paths renamed as expected)."
    )
    return 0


def main() -> None:
    if "--check-timed" in sys.argv[1:]:
        sys.exit(check_timed())
    if "--check" in sys.argv[1:]:
        sys.exit(check())
    weights, total = compute_weights()
    print_table(percent_table(weights, total), total)


if __name__ == "__main__":
    main()
