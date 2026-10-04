#!/usr/bin/env bash
set -euo pipefail

PRINTER_DEV="${OMA_KVITTO_DEV:-/dev/usb/lp0}"
PRINTER_CUPS="${OMA_KVITTO_CUPS:-}"

text="${1:-}"
if [[ -z "$text" ]]; then
  echo "Ingen text att skriva ut" >&2
  exit 1
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

python3 - "$tmp" "$text" << 'PY'
import sys
out, text = sys.argv[1], sys.argv[2]
cols = 42
lines = []
for raw in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
    if raw == "":
        lines.append("")
        continue
    while len(raw) > cols:
        lines.append(raw[:cols])
        raw = raw[cols:]
    lines.append(raw)
body = ("\n".join(lines) + "\n").encode("cp1252", "replace")

# GS V Function B: mata till knivposition + n * (1/360 tum), sedan partial cut.
# n=213 -> 15 mm extra under sista textraden.
payload = (
    b"\x1b@"
    + b"\x1b\x52\x05"
    + b"\x1b\x74\x10"
    + body
    + b"\x1dV\x42\xd5"
)
open(out, "wb").write(payload)
PY

if [[ -n "$PRINTER_CUPS" ]]; then
  lp -d "$PRINTER_CUPS" -o raw "$tmp"
  exit $?
fi

if [[ ! -e "$PRINTER_DEV" ]]; then
  echo "Hittar inte $PRINTER_DEV" >&2
  exit 2
fi

if [[ ! -w "$PRINTER_DEV" ]]; then
  echo "Saknar skrivrättighet till $PRINTER_DEV" >&2
  ls -l "$PRINTER_DEV" >&2
  exit 3
fi

cat "$tmp" > "$PRINTER_DEV"
