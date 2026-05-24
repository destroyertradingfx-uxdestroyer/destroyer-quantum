#!/bin/bash
# DESTROYER QUANTUM — Version Push Script
# Commits all changes with a version tag and pushes to GitHub.
#
# Usage:
#   ./push_version.sh 28.11 'DEBATE LAYER' 'Integrated debate layer with all 12 strategies'
#
# Args:
#   $1 — Version number (e.g., 28.11)
#   $2 — Codename (e.g., 'DEBATE LAYER')
#   $3 — Notes (optional, e.g., 'Fixed array bounds crash')

set -e

VERSION="$1"
CODENAME="$2"
NOTES="${3:-}"

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version> <codename> [notes]"
    echo "Example: $0 28.11 'DEBATE LAYER' 'Integrated all 12 strategies'"
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "=== DESTROYER QUANTUM — Version Push ==="
echo "Version:  V${VERSION}"
echo "Codename: ${CODENAME}"
echo "Notes:    ${NOTES:-none}"
echo ""

# Stage everything
git add -A

# Check for changes
if git diff --cached --quiet; then
    echo "No changes to commit."
    exit 0
fi

# Count changes
MODIFIED=$(git diff --cached --name-only | wc -l)
echo "Files changed: ${MODIFIED}"

# Build commit message
SUBJECT="V${VERSION} ${CODENAME} — ${MODIFIED} file(s) updated"

BODY=""
if [ -n "$NOTES" ]; then
    BODY="${NOTES}

"
fi

BODY="${BODY}Changed files:
$(git diff --cached --name-status | sed 's/^/  /')"

# Commit
echo ""
echo "Committing: ${SUBJECT}"
git commit -m "${SUBJECT}

${BODY}"

# Tag
TAG="V${VERSION}"
echo ""
echo "Tagging: ${TAG}"
git tag -f "${TAG}"

# Push
echo ""
echo "Pushing to GitHub..."
git push origin "$(git branch --show-current)" 2>&1
git push origin "${TAG}" --force 2>&1 || true

echo ""
echo "✅ DONE — V${VERSION} ${CODENAME} pushed to GitHub"

# Log it
mkdir -p memory
echo "[$(date '+%Y-%m-%d %H:%M:%S')] PUSHED V${VERSION} ${CODENAME} — ${NOTES}" >> memory/auto_push.log
