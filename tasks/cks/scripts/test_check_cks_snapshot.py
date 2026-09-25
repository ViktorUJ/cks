#!/usr/bin/env python3
"""Unit tests for transition-aware snapshot freshness defaults."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("check_cks_snapshot.py")
SPEC = importlib.util.spec_from_file_location("check_cks_snapshot", MODULE_PATH)
assert SPEC and SPEC.loader
snapshot = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(snapshot)


class TransitionFreshnessTests(unittest.TestCase):
    def write_snapshot(self, directory: Path, upstream: str, exam: str) -> Path:
        directory.mkdir(parents=True, exist_ok=True)
        path = directory / "cks-exam-snapshot.yaml"
        path.write_text(
            "checked_at: '2026-09-10'\n"
            f"upstream:\n  latest_stable: '{upstream}'\n"
            "exam:\n  linux_foundation:\n    product_page:\n"
            f"      kubernetes: '{exam}'\n",
            encoding="utf-8",
        )
        return path

    def test_transition_uses_seven_days(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = self.write_snapshot(Path(directory), "1.37", "1.35")
            self.assertEqual(snapshot.default_max_age_days(path), 7)

    def test_matching_minors_use_thirty_days(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = self.write_snapshot(Path(directory), "v1.37", "1.37")
            self.assertEqual(snapshot.default_max_age_days(path), 30)

    def test_cli_override_wins_in_both_version_states(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            transition = self.write_snapshot(root / "transition", "1.37", "1.35")
            matching = self.write_snapshot(root / "matching", "1.37", "1.37")
            self.assertEqual(snapshot.selected_max_age_days(transition, 20), 20)
            self.assertEqual(snapshot.selected_max_age_days(matching, 20), 20)

    def test_numeric_minor_comparison_is_not_lexicographic(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = self.write_snapshot(Path(directory), "1.10", "1.9")
            self.assertEqual(snapshot.default_max_age_days(path), 7)

    def test_malformed_version_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = self.write_snapshot(Path(directory), "not-a-version", "1.35")
            with self.assertRaises(ValueError):
                snapshot.default_max_age_days(path)
            self.assertEqual(snapshot.main(["--file", str(path)]), 1)


if __name__ == "__main__":
    unittest.main()
