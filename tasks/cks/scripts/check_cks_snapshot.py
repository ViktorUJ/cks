#!/usr/bin/env python3
"""Проверка "свежести" machine-readable snapshot-файлов курса CKS.

Проверяет поле `checked_at` в metadata/cks-exam-snapshot.yaml (и, опционально,
metadata/tool-compatibility.yaml) и завершает работу с ненулевым кодом, если snapshot
старше допустимого возраста. Скрипт не делает сетевых запросов и не пытается сам
определить актуальное значение - он только проверяет дату последней ручной/CI проверки.

Использование:
    python3 scripts/check_cks_snapshot.py
    python3 scripts/check_cks_snapshot.py --max-age-days 30
    python3 scripts/check_cks_snapshot.py --file metadata/tool-compatibility.yaml
"""

from __future__ import annotations

import argparse
import sys
from datetime import date, datetime
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover - зависимость должна быть установлена в CI
    print(
        "ERROR: пакет PyYAML не установлен. Установите его: pip install pyyaml",
        file=sys.stderr,
    )
    sys.exit(2)

DEFAULT_MAX_AGE_DAYS = 30
DEFAULT_SNAPSHOT_FILES = (
    "metadata/cks-exam-snapshot.yaml",
    "metadata/tool-compatibility.yaml",
)


def find_repo_root(start: Path) -> Path:
    """Ищет корень репозитория `tasks/cks` начиная от текущей директории скрипта."""
    candidate = start
    for _ in range(6):
        if (candidate / "metadata" / "cks-exam-snapshot.yaml").exists():
            return candidate
        candidate = candidate.parent
    # Fallback: работать относительно текущей рабочей директории.
    return Path.cwd()


def parse_checked_at(value: object, path: Path) -> date:
    if isinstance(value, date) and not isinstance(value, datetime):
        return value
    if isinstance(value, str):
        try:
            return date.fromisoformat(value)
        except ValueError as exc:
            raise ValueError(
                f"{path}: поле 'checked_at' не в формате YYYY-MM-DD: {value!r}"
            ) from exc
    raise ValueError(f"{path}: поле 'checked_at' отсутствует или имеет неверный тип")


def check_file(path: Path, max_age_days: int) -> list[str]:
    errors: list[str] = []
    if not path.exists():
        errors.append(f"[FAIL] {path}: файл не найден")
        return errors

    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        errors.append(f"[FAIL] {path}: невозможно распарсить YAML: {exc}")
        return errors

    if not isinstance(data, dict) or "checked_at" not in data:
        errors.append(f"[FAIL] {path}: нет top-level поля 'checked_at'")
        return errors

    try:
        checked = parse_checked_at(data["checked_at"], path)
    except ValueError as exc:
        errors.append(f"[FAIL] {exc}")
        return errors

    age_days = (date.today() - checked).days
    if age_days < 0:
        errors.append(
            f"[FAIL] {path}: checked_at ({checked}) в будущем относительно сегодняшней даты"
        )
        return errors

    if age_days > max_age_days:
        errors.append(
            f"[FAIL] {path}: snapshot устарел на {age_days} дн. "
            f"(максимум {max_age_days} дн., checked_at={checked})"
        )
    else:
        print(f"[PASS] {path}: age={age_days} дн. (max={max_age_days})")

    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--max-age-days",
        type=int,
        default=DEFAULT_MAX_AGE_DAYS,
        help=f"Максимально допустимый возраст snapshot в днях (default: {DEFAULT_MAX_AGE_DAYS})",
    )
    parser.add_argument(
        "--file",
        dest="files",
        action="append",
        help="Путь к конкретному snapshot-файлу (можно указать несколько раз). "
        "По умолчанию проверяются оба стандартных metadata-файла.",
    )
    args = parser.parse_args(argv)

    repo_root = find_repo_root(Path(__file__).resolve().parent)
    targets = (
        [Path(f) for f in args.files]
        if args.files
        else [repo_root / f for f in DEFAULT_SNAPSHOT_FILES]
    )

    all_errors: list[str] = []
    for target in targets:
        all_errors.extend(check_file(target, args.max_age_days))

    if all_errors:
        print("\n".join(all_errors), file=sys.stderr)
        return 1

    print("Все проверенные snapshot-файлы в пределах допустимого возраста.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
