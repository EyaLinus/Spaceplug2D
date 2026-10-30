One file per change: `changelog.d/<topic>.md` with one or more `- **Title:** text` bullets.
`python3 tools/changelog_collect.py --version vX.Y.Z` folds them into CHANGELOG.md at release time.
