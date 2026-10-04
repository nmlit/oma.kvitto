#!/usr/bin/env bash
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
DST="$HOME/.config/omarchy/plugins/oma.kvitto"
mkdir -p "$HOME/.config/omarchy/plugins"
rm -rf "$DST"
mkdir -p "$DST"
cp -a "$SRC/." "$DST/"
chmod +x "$DST/print.sh" "$DST/install.sh"
rm -f "$DST/oma.kvitto.zip" 2>/dev/null || true
omarchy plugin validate "$DST"
omarchy plugin enable oma.kvitto || true
if command -v omarchy >/dev/null 2>&1; then
  omarchy bar plugin add oma.kvitto --section right 2>/dev/null || true
fi
omarchy-shell shell rescanPlugins 2>/dev/null || true
echo "Klart. Starta om skalet:"
echo "  omarchy-restart-shell"
echo "Öppna sedan:"
echo "  omarchy-shell shell toggle oma.kvitto '{}'"
