#!/usr/bin/env bash
set -euo pipefail

PRINTER_DEV="${OMA_KVITTO_DEV:-/dev/usb/lp0}"
PRINTER_CUPS="${OMA_KVITTO_CUPS:-}"
# OMA_KVITTO_STRECK=0 stänger av de lodräta strecken (ren textutskrift som förut).
# OMA_KVITTO_OUT=fil skriver ESC/POS-datan till en fil i stället för skrivaren (test).
# OMA_KVITTO_FONT=sökväg/namn väljer typsnitt för grafikläget (standard: paketerad Atkinson Hyperlegible).

text="${1:-}"
image="${4:-}"
if [[ -z "$text" && -z "$image" ]]; then
  echo "Ingen text att skriva ut" >&2
  exit 1
fi

tmp="$(mktemp)"
work="$(mktemp -d)"
trap 'rm -f "$tmp"; rm -rf "$work"' EXIT

magick_bin=""
if [[ "${OMA_KVITTO_STRECK:-1}" != "0" || -n "$image" ]]; then
  if command -v magick >/dev/null 2>&1; then
    magick_bin="magick"
  fi
fi

plugin_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bundled_font="$plugin_dir/fonts/atkinson-hyperlegible/AtkinsonHyperlegible-Regular.ttf"
font="${2:-${OMA_KVITTO_FONT:-Atkinson Hyperlegible}}"
size="${3:-${OMA_KVITTO_SIZE:-20}}"
if [[ -n "$magick_bin" ]]; then
  case "$font" in
    "Atkinson Hyperlegible")
      # Always use the shipped TTF, even if fontconfig has no system fonts.
      if [[ ! -r "$bundled_font" ]]; then
        echo "oma.kvitto: paketerad Atkinson-font saknas; ingen utskrift skickades" >&2
        exit 1
      fi
      font="$bundled_font"
      ;;
    *)
      # Preserve explicit file paths and other installed font choices.
      if [[ ! -f "$font" ]] && command -v fc-match >/dev/null 2>&1; then
        font="$(fc-match -f '%{file}' "$font" 2>/dev/null || true)"
      fi
      ;;
  esac
fi

python3 - "$tmp" "$text" "$magick_bin" "$font" "$work" "$size" "$image" << 'PY'
import subprocess
import sys

out, text, magick, font, work, size, image = sys.argv[1:8]

INIT = b"\x1b@" + b"\x1b\x52\x05" + b"\x1b\x74\x10"
# GS V Function B: mata till knivposition + n * (1/360 tum), sedan partial cut.
# n=213 -> 15 mm extra under sista raden.
CUT = b"\x1dV\x42\x00"  # mata till kniven och skär

# TM-T88V, 80 mm papper: 512 punkter bred utskrift, 180 dpi (≈7,09 punkter/mm).
WIDTH = 512
DPMM = 180 / 25.4
TAIL = round(10 * DPMM)    # 10 mm tomt efter sista raden
TEXT_X = 8                 # liten sidomarginal
TEXT_W = WIDTH - 2 * TEXT_X
POINTSIZE = max(6, min(80, int(float(size or 20))))


def wrap(cols):
    import textwrap
    lines = []
    for raw in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        raw = raw.replace("\t", "    ")
        if raw.strip() == "":
            lines.append("")
            continue
        indent = raw[:len(raw) - len(raw.lstrip(" "))]
        lines += textwrap.wrap(raw, cols, subsequent_indent=indent,
                               break_long_words=True, break_on_hyphens=False,
                               drop_whitespace=True) or [""]
    return lines


def text_payload():
    body = ("\n".join(wrap(42)) + "\n").encode("cp1252", "replace")
    return INIT + body + b"\x1bJ" + bytes([round(10 / 25.4 * 180)]) + CUT


def read_pbm(path):
    data = open(path, "rb").read()
    fields, pos = [], 0
    while len(fields) < 3:
        while data[pos:pos + 1].isspace():
            pos += 1
        if data[pos:pos + 1] == b"#":
            while data[pos:pos + 1] not in (b"\n", b""):
                pos += 1
            continue
        start = pos
        while not data[pos:pos + 1].isspace():
            pos += 1
        fields.append(data[start:pos])
    pos += 1
    if fields[0] != b"P4":
        raise ValueError("oväntat bildformat")
    w, h = int(fields[1]), int(fields[2])
    stride = (w + 7) // 8
    rows = [int.from_bytes(data[pos + y * stride:pos + (y + 1) * stride], "big") for y in range(h)]
    # Ta bort utfyllnadsbitar så att varje rad är exakt w bitar.
    pad = stride * 8 - w
    rows = [r >> pad for r in rows]
    return w, h, rows


def magick_cmd(*args):
    cmd = [magick, "-background", "white", "-fill", "black", "+antialias"]
    if font:
        cmd += ["-font", font]
    cmd += ["-pointsize", str(POINTSIZE)] + list(args)
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)


def raster_payload():
    if not text:
        return compose_raster(0, 0, [])
    probe = f"{work}/probe.pbm"
    # Mät genomsnittlig teckenbredd på vanlig text (inte bara M), så att
    # proportionella typsnitt inte bryts för tidigt.
    sample = "Det här är en helt vanlig mening med åäö, siffror 0123456789."
    magick_cmd("label:" + sample, "-threshold", "50%", probe)
    pw, line_h, _ = read_pbm(probe)
    cols = max(10, int(TEXT_W * len(sample) / pw * 0.95))

    while True:
        # En label per rad, staplade med -append. Texten skickas som argument
        # (inte @fil, som ofta spärras av ImageMagicks policy), så % och \\
        # escapas och en inledande @ neutraliseras.
        labels = []
        for line in wrap(cols):
            esc = line.replace("\\", "\\\\").replace("%", "%%")
            # Inledande blanksteg trimmas av ImageMagick; byt mot hårda mellanslag.
            stripped = esc.lstrip(" ")
            esc = "\u00a0" * (len(esc) - len(stripped)) + stripped
            if esc.startswith("@"):
                esc = "\\" + esc
            if esc.strip():
                labels.append("label:" + esc)
            else:  # tom rad: vit ruta med samma höjd som en textrad
                labels += ["-size", f"1x{line_h}", "xc:white", "+size"]
        img = f"{work}/text.pbm"
        magick_cmd(*labels, "-gravity", "NorthWest", "-append", "-threshold", "50%", img)
        tw, th, trows = read_pbm(img)
        if tw <= TEXT_W or cols <= 10:
            break
        cols -= 2  # en rad blev för bred: bryt lite tidigare och försök igen
    if tw > TEXT_W:  # klipp om typsnittet ändå blev för brett
        trows = [r >> (tw - TEXT_W) for r in trows]
        tw = TEXT_W

    return compose_raster(tw, th, trows)


def compose_raster(tw, th, trows):
    iw, ih, irows = 0, 0, []
    if image:
        img = f"{work}/image.pbm"
        # Prepared preview is already 512px monochrome; revalidate/re-render
        # so the public print entry point also enforces white alpha + dithering.
        subprocess.run([magick, "-limit", "memory", "128MiB",
                        "-limit", "map", "256MiB", "-limit", "disk", "256MiB",
                        "-limit", "width", "32768", "-limit", "height", "32768",
                        "png:" + image + "[0]", "-background", "white",
                        "-alpha", "remove", "-alpha", "off",
                        "-resize", "512x", "-colorspace", "Gray",
                        "-dither", "FloydSteinberg", "-remap", "pattern:gray50", img],
                       check=True, timeout=15, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        iw, ih, irows = read_pbm(img)
        if iw != WIDTH or ih > 16384:
            raise ValueError("bilden är för hög eller har fel bredd")
    image_y = th + (8 if th and ih else 0)
    height = max(image_y + ih + TAIL, round(80 * DPMM))  # minst 80 mm
    full = (1 << WIDTH) - 1
    text_shift = WIDTH - TEXT_X - tw

    rows = []
    for y in range(height):
        r = 0
        if y < th:
            r |= trows[y] << text_shift
        if image_y <= y < image_y + ih:
            r |= irows[y - image_y] << (WIDTH - iw)
        rows.append((r & full).to_bytes(WIDTH // 8, "big"))

    # GS v 0: rasterbild, skickas i band om 128 rader.
    xb = WIDTH // 8
    raster = b""
    for start in range(0, height, 128):
        band = rows[start:start + 128]
        n = len(band)
        raster += b"\x1dv0\x00" + bytes([xb & 0xFF, xb >> 8, n & 0xFF, n >> 8]) + b"".join(band)
    return INIT + raster + CUT


payload = None
if magick:
    try:
        payload = raster_payload()
    except Exception as exc:
        if image:
            print("oma.kvitto: bilden kunde inte renderas; ingen utskrift skickades", file=sys.stderr)
            sys.exit(1)
        err = getattr(exc, "stderr", b"") or b""
        msg = err.decode("utf-8", "replace").strip() if isinstance(err, bytes) else str(err)
        print(f"oma.kvitto: grafikläget misslyckades ({msg or exc}), skriver ren text", file=sys.stderr)
if payload is None:
    if image:
        print("oma.kvitto: ImageMagick krävs för bilder; ingen utskrift skickades", file=sys.stderr)
        sys.exit(1)
    payload = text_payload()
open(out, "wb").write(payload)
PY

if [[ -n "${OMA_KVITTO_OUT:-}" ]]; then
  cp "$tmp" "$OMA_KVITTO_OUT"
  exit 0
fi

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
