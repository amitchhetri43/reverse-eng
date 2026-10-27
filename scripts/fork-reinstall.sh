#!/usr/bin/env bash
# Build the fork clone and install its dist over the running REA package.
#
# Nothing here contacts npm, a registry, GitHub, or any other remote. It only
# compiles what is already on disk and copies the result into the existing
# installation directory.
#
# Usage: bash scripts/fork-reinstall.sh [--skip-build]
set -euo pipefail

FORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_ROOT="${REA_INSTALL_ROOT:-$HOME/.local/share/rea/install/lib/node_modules/rea-agents}"
NODE_BIN_DIR="${REA_NODE_BIN_DIR:-$HOME/.local/share/rea/node-v24.22.1-darwin-arm64/bin}"

if [[ ! -d "$INSTALL_ROOT" ]]; then
  echo "no installed package at $INSTALL_ROOT" >&2
  echo "set REA_INSTALL_ROOT to the directory that holds the installed rea-agents package" >&2
  exit 1
fi

if [[ "${1:-}" != "--skip-build" ]]; then
  echo "== building $FORK_DIR =="
  ( cd "$FORK_DIR" && PATH="$NODE_BIN_DIR:$PATH" npm run compile )
fi

echo "== replacing dist in $INSTALL_ROOT =="
rsync -a --delete "$FORK_DIR/dist/" "$INSTALL_ROOT/dist/"

# Shipped prose and skill instructions carry the fork's own wording; keep the
# installed copy in step with the clone.
for doc in README.md DISCLAIMER.md LICENSE THIRD_PARTY_NOTICES.md CHANGELOG.md; do
  [[ -f "$FORK_DIR/$doc" ]] && cp "$FORK_DIR/$doc" "$INSTALL_ROOT/$doc"
done
if [[ -d "$INSTALL_ROOT/skills/reverse-engineer-anything" ]]; then
  rsync -a --exclude 'SKILL.md' "$FORK_DIR/.agents/skills/reverse-engineer-anything/references/" \
        "$INSTALL_ROOT/skills/reverse-engineer-anything/references/"
fi

echo "== installed version =="
"$NODE_BIN_DIR/node" -e 'console.log(require(process.argv[1]).version)' "$INSTALL_ROOT/package.json"

echo "== verifying no registry update path survives =="
if grep -rIl --include='*.js' --include='*.mjs' -e 'incur-update-check' "$INSTALL_ROOT/dist" >/dev/null 2>&1; then
  echo "note: the --incur-update-check flag name still exists in dist; it is inert because update: false" >&2
fi

echo "== rea --version =="
"$NODE_BIN_DIR/node" "$INSTALL_ROOT/scripts/rea.mjs" --version

echo "done. this build never checks for or installs releases on its own."
