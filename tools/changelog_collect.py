#!/usr/bin/env python3
"""Folds the changelog fragments in changelog.d/ into CHANGELOG.md at release time.

Every PR adds its entry as its own file changelog.d/<topic>.md (one or more "- **Title:** text" bullets),
so parallel PRs never touch the same lines of CHANGELOG.md. At release:

    python3 tools/changelog_collect.py --version v0.9.2            # writes CHANGELOG.md, deletes the fragments
    python3 tools/changelog_collect.py --version v0.9.2 --dry-run  # only prints the new section

Newest fragment first (by the commit that added it, files not yet committed count as newest). Entries
still written under a "## Unreleased" heading in CHANGELOG.md are folded in as well, after the fragments.
"""
import argparse
import datetime
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FRAG_DIR = os.path.join(ROOT, "changelog.d")
CHANGELOG = os.path.join(ROOT, "CHANGELOG.md")


def fragments():
    """[(path, text)] newest first."""
    if not os.path.isdir(FRAG_DIR):
        return []
    r = []
    for name in os.listdir(FRAG_DIR):
        if not name.endswith(".md") or name.upper() == "README.MD":
            continue
        path = os.path.join(FRAG_DIR, name)
        text = open(path, encoding="utf-8").read().strip()
        if not text:
            continue
        if not text.startswith("- "):
            sys.exit("%s: a fragment must start with a '- ' bullet" % os.path.relpath(path, ROOT))
        out = subprocess.run(["git", "log", "--diff-filter=A", "--format=%ct", "-1", "--", path],
                             cwd=ROOT, capture_output=True, text=True).stdout.strip()
        added = int(out) if out else 1 << 62
        r.append((added, name, path, text))
    r.sort(key=lambda f: (-f[0], f[1]))
    return [(p, t) for _, _, p, t in r]


def split_unreleased(lines):
    """(head lines, unreleased bullet lines, rest lines) of CHANGELOG.md."""
    start = next((i for i, l in enumerate(lines) if l.strip() == "## Unreleased"), None)
    if start is None:
        first = next((i for i, l in enumerate(lines) if l.startswith("## ")), len(lines))
        return lines[:first], [], lines[first:]
    end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("## ")), len(lines))
    body = [l for l in lines[start + 1:end]]
    while body and not body[-1].strip():
        body.pop()
    return lines[:start], body, lines[end:]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True, help="e.g. v0.9.2")
    ap.add_argument("--date", default=datetime.date.today().isoformat())
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    frags = fragments()
    lines = open(CHANGELOG, encoding="utf-8").read().split("\n")
    head, unreleased, rest = split_unreleased(lines)
    body = [t for _, t in frags]
    if unreleased:
        body.append("\n".join(unreleased))
    if not body:
        sys.exit("Nothing to release: no fragments in changelog.d/ and no '## Unreleased' entries.")
    section = "## %s – %s\n%s\n" % (a.version, a.date, "\n".join(body))
    if a.dry_run:
        print(section)
        return
    while head and not head[-1].strip():
        head.pop()
    text = "\n".join(head) + "\n\n" + section + "\n" + "\n".join(rest)
    open(CHANGELOG, "w", encoding="utf-8").write(text.rstrip("\n") + "\n")
    for p, _ in frags:
        os.remove(p)
    print("%s: %d fragments%s folded into CHANGELOG.md" % (a.version, len(frags), " + Unreleased" if unreleased else ""))


if __name__ == "__main__":
    main()
