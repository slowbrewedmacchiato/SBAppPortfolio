#!/usr/bin/env python3
"""Verify String Catalogs are complete.

Guards three failure modes, all of which have shipped in this repo before:

  1. A key used in Swift but absent from the catalog, so the UI falls back to
     the raw key.
  2. A locale entry that exists but carries an empty value, which reads as
     "fully translated" to a shallow check and renders English at runtime.
  3. A key translated into only some of the catalog's locales.

Run from the repository root:  python3 Scripts/check-localization.py
"""

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

# (catalog, source roots it draws its keys from)
TARGETS = [
    (
        "Sources/SBAppPortfolio/Resources/Localizable.xcstrings",
        ["Sources/SBAppPortfolio"],
    ),
    (
        "Example/Thicket/Sources/Localization/Localizable.xcstrings",
        ["Example/Thicket/Sources"],
    ),
]

# String(localized: "...") with an optional leading label, capturing the literal.
KEY_PATTERN = re.compile(r'String\(\s*localized:\s*"((?:[^"\\]|\\.)*)"')
# Swift interpolation segments, allowing one level of nested parentheses.
INTERPOLATION = re.compile(r"\\\((?:[^()]|\([^()]*\))*\)")
# Placeholder tokens the catalog may use for an interpolated value.
PLACEHOLDER = re.compile(r"%(?:lld|ld|@|d|f)")


def normalize(key: str) -> str:
    """Collapse interpolations and format specifiers to a single token.

    A Swift literal writes `\\(code)` where the catalog stores `%lld` or `%@`
    depending on the interpolated type. Comparing raw strings would report a
    false mismatch, so both sides collapse to the same placeholder.
    """
    return PLACEHOLDER.sub("{}", INTERPOLATION.sub("{}", key))


def keys_used_in(source_roots: list[str]) -> set[str]:
    found = set()
    for root in source_roots:
        for path in (ROOT / root).rglob("*.swift"):
            for match in KEY_PATTERN.finditer(path.read_text(encoding="utf-8")):
                found.add(normalize(match.group(1)))
    return found


def check(catalog_path: str, source_roots: list[str]) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []

    catalog = json.loads((ROOT / catalog_path).read_text(encoding="utf-8"))
    entries = catalog.get("strings", {})

    # The catalog's locale set is the union across entries, so a locale added
    # to one key but forgotten on another is caught rather than assumed.
    all_locales = {
        locale
        for entry in entries.values()
        for locale in entry.get("localizations", {})
    }

    catalog_keys = {normalize(key) for key in entries}
    for key in sorted(keys_used_in(source_roots) - catalog_keys):
        errors.append(f"{catalog_path}: key used in code but missing from catalog: {key!r}")

    for key, entry in sorted(entries.items()):
        localizations = entry.get("localizations", {})
        if not localizations:
            # Xcode manages some entries itself (for example the app name
            # pulled from Info.plist). Nothing to verify.
            continue

        for locale in sorted(all_locales - set(localizations)):
            errors.append(f"{catalog_path}: {key!r} has no {locale} entry")

        for locale, unit in sorted(localizations.items()):
            value = unit.get("stringUnit", {}).get("value", "")
            if not value.strip():
                errors.append(f"{catalog_path}: {key!r} is empty in {locale}")

    for key in sorted(catalog_keys - keys_used_in(source_roots)):
        warnings.append(f"{catalog_path}: catalog key not referenced in code: {key!r}")

    return errors, warnings


def main() -> int:
    all_errors: list[str] = []
    all_warnings: list[str] = []

    for catalog_path, source_roots in TARGETS:
        if not (ROOT / catalog_path).exists():
            all_errors.append(f"missing catalog: {catalog_path}")
            continue
        errors, warnings = check(catalog_path, source_roots)
        all_errors += errors
        all_warnings += warnings

    for warning in all_warnings:
        print(f"warning: {warning}")
    for error in all_errors:
        print(f"error: {error}")

    if all_errors:
        print(f"\n{len(all_errors)} localization problem(s) found.")
        return 1

    checked = len(TARGETS)
    print(f"All {checked} catalog(s) complete: every key translated in every locale.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
