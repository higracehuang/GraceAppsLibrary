#!/usr/bin/env python3
"""
prune_release_notes.py
Single-command tool to:
1. Prune in-app ReleaseNote(...) entries to the latest N (default: 5, matching ReleaseNotesView).
2. Extract all string literals from the removed ReleaseNote(...) entries (converting Swift
   string interpolation `\\(...)` to `%@` to match Xcode String Catalog keys).
3. Remove those keys (unless still referenced elsewhere in Swift code) and any `stale` keys
   from the app's Localizable.xcstrings files.

Usage:
  python3 ../GraceAppsLibrary/scripts/prune_release_notes.py [--keep 5] [--dry-run] [--root .]
"""

import argparse
import json
import re
from pathlib import Path
from typing import List, Tuple


CANDIDATE_FILENAMES = {
    "AppReleaseNotes.swift",
    "ReleaseNotesData.swift",
    "ReleaseNotes.swift",
}


def find_release_notes_files(root: Path) -> List[Path]:
    found = []
    for path in root.rglob("*.swift"):
        if any(part in {".git", ".build", "DerivedData", "SourcePackages"} for part in path.parts):
            continue
        if path.name in CANDIDATE_FILENAMES and "ReleaseNote(" in path.read_text(encoding="utf-8", errors="ignore"):
            found.append(path)
    return sorted(found)


def find_release_note_blocks(text: str) -> List[Tuple[int, int]]:
    """Return (start_idx, end_idx_exclusive) for each top-level `ReleaseNote(...)` call."""
    blocks = []
    for match in re.finditer(r"\bReleaseNote\s*\(", text):
        start = match.start()
        # Skip if this ReleaseNote( is nested inside an already-captured block.
        if blocks and start < blocks[-1][1]:
            continue
        i = match.end() - 1  # at '('
        depth = 0
        in_string = False
        escaped = False
        while i < len(text):
            ch = text[i]
            if in_string:
                if escaped:
                    escaped = False
                elif ch == "\\":
                    escaped = True
                elif ch == '"':
                    in_string = False
            else:
                if ch == '"':
                    in_string = True
                elif ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
                    if depth == 0:
                        blocks.append((start, i + 1))
                        break
            i += 1
    return blocks


def extract_swift_string_literals(snippet: str) -> List[str]:
    """Extract double-quoted string literals from a Swift snippet, normalizing \\(...) -> %@."""
    results = []
    i = 0
    while i < len(snippet):
        if snippet[i] == '"':
            i += 1
            chars = []
            while i < len(snippet):
                ch = snippet[i]
                if ch == "\\":
                    if i + 1 < len(snippet) and snippet[i + 1] == "(":
                        # Skip balanced (...) interpolation and emit %@
                        i += 2
                        paren_depth = 1
                        while i < len(snippet) and paren_depth > 0:
                            if snippet[i] == "(":
                                paren_depth += 1
                            elif snippet[i] == ")":
                                paren_depth -= 1
                            i += 1
                        chars.append("%@")
                        continue
                    elif i + 1 < len(snippet):
                        esc = snippet[i + 1]
                        mapping = {"n": "\n", "t": "\t", "r": "\r", '"': '"', "\\": "\\"}
                        chars.append(mapping.get(esc, esc))
                        i += 2
                        continue
                elif ch == '"':
                    i += 1
                    break
                chars.append(ch)
                i += 1
            results.append("".join(chars))
        else:
            i += 1
    return results


def prune_file(swift_path: Path, keep: int, dry_run: bool) -> Tuple[int, List[str]]:
    text = swift_path.read_text(encoding="utf-8")
    blocks = find_release_note_blocks(text)
    if len(blocks) <= keep:
        return 0, []

    kept_end = blocks[keep - 1][1]
    last_end = blocks[-1][1]

    removed_snippets = [text[s:e] for s, e in blocks[keep:]]
    extracted_strings: List[str] = []
    for snip in removed_snippets:
        for s in extract_swift_string_literals(snip):
            # Ignore short version strings like "1.9.0"
            if re.fullmatch(r"\d+\.\d+(?:\.\d+)?", s):
                continue
            extracted_strings.append(s)

    new_text = text[:kept_end] + text[last_end:]
    if not dry_run:
        swift_path.write_text(new_text, encoding="utf-8")

    return len(blocks) - keep, extracted_strings


def string_referenced_in_repo(key: str, root: Path, excluded: List[Path]) -> bool:
    excluded_set = {p.resolve() for p in excluded}
    for path in root.rglob("*.swift"):
        if path.resolve() in excluded_set:
            continue
        if any(part in {".git", ".build", "DerivedData", "SourcePackages"} for part in path.parts):
            continue
        content = path.read_text(encoding="utf-8", errors="ignore")
        if key in content:
            return True
    return False


def clean_xcstrings(root: Path, candidate_keys: List[str], excluded_swift: List[Path], dry_run: bool) -> Tuple[int, int]:
    removed_pruned = 0
    removed_stale = 0

    safe_keys = {k for k in candidate_keys if not string_referenced_in_repo(k, root, excluded_swift)}

    for xc_path in sorted(root.rglob("Localizable.xcstrings")):
        if any(part in {".git", ".build", "DerivedData", "SourcePackages"} for part in xc_path.parts):
            continue
        data = json.loads(xc_path.read_text(encoding="utf-8"))
        strings = data.get("strings", {})
        to_delete = []
        for k, v in strings.items():
            if k in safe_keys:
                to_delete.append((k, "pruned"))
            elif v.get("extractionState") == "stale":
                to_delete.append((k, "stale"))

        for k, kind in to_delete:
            if not dry_run:
                del strings[k]
            if kind == "pruned":
                removed_pruned += 1
            else:
                removed_stale += 1

        if to_delete and not dry_run:
            xc_path.write_text(json.dumps(data, indent=2, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")

    return removed_pruned, removed_stale


def main() -> int:
    parser = argparse.ArgumentParser(description="Prune old in-app ReleaseNote entries and clean unused Localizable.xcstrings keys.")
    parser.add_argument("--root", default=".", help="App repository root (default: current directory)")
    parser.add_argument("--keep", type=int, default=5, help="Number of latest ReleaseNote entries to keep (default: 5)")
    parser.add_argument("--file", help="Explicit path to ReleaseNotes Swift file")
    parser.add_argument("--dry-run", action="store_true", help="Report what would be pruned/cleaned without modifying files")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    files = [Path(args.file).resolve()] if args.file else find_release_notes_files(root)

    if not files:
        print(f"No ReleaseNotes Swift files found under {root}")
        return 0

    all_candidates: List[str] = []
    total_pruned_blocks = 0
    for f in files:
        pruned_count, candidates = prune_file(f, keep=args.keep, dry_run=args.dry_run)
        total_pruned_blocks += pruned_count
        all_candidates.extend(candidates)
        print(f"{'[DRY RUN] ' if args.dry_run else ''}{f.relative_to(root)}: pruned {pruned_count} old ReleaseNote entries")

    removed_pruned, removed_stale = clean_xcstrings(root, all_candidates, files, dry_run=args.dry_run)
    prefix = "[DRY RUN] " if args.dry_run else ""
    print(f"{prefix}Localizable.xcstrings cleanup: removed {removed_pruned} pruned release-note keys, {removed_stale} stale keys.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
