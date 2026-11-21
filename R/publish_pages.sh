#!/usr/bin/env bash
# Publish the rendered summary.html to GitHub Pages (branch gh-pages, served as index.html).
# The HTML is not tracked on main (see .gitignore); gh-pages holds only the published page, so
# its history can be reset at any time without touching the code history.
#
# Usage (from anywhere in the repository, after `Rscript R/render_all.R`):
#   bash R/publish_pages.sh ["extra commit message lines"]
# Site: https://fbzimmermann.github.io/nep2spict/
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"
[ -f summary.html ] || { echo "summary.html not found: render summary.qmd first" >&2; exit 1; }

# Do not publish local paths or user names that a render may have written into the page
if grep -q -E "C:[/\\\\]Users|ownCloud|Havforskningsinstituttet" summary.html; then
  echo "summary.html contains local paths; not publishing" >&2; exit 1
fi

src="$(git rev-parse --short HEAD)"
dirty=""; git diff --quiet HEAD -- summary.qmd R data/config || dirty=" (uncommitted changes)"

wt="$(mktemp -d)"
cleanup() { git worktree remove --force "$wt" >/dev/null 2>&1 || rm -rf "$wt"; }
trap cleanup EXIT

if git ls-remote --exit-code --heads origin gh-pages >/dev/null 2>&1; then
  git fetch -q origin gh-pages
  git worktree add -q -B gh-pages "$wt" origin/gh-pages
else
  git worktree add -q --orphan -b gh-pages "$wt"   # git >= 2.42
fi

cp summary.html "$wt/index.html"
touch "$wt/.nojekyll"                              # serve as is, no Jekyll processing

cd "$wt"
git add -A
if git diff --cached --quiet; then echo "gh-pages already up to date"; exit 0; fi
msg="Publish summary.html from main@${src}${dirty}"
[ $# -gt 0 ] && msg="$msg"$'\n\n'"$1"
git commit -q -m "$msg"
git push -q -u origin gh-pages
echo "Published: https://fbzimmermann.github.io/nep2spict/"
