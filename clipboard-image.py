#!/usr/bin/env python3
"""User-triggered MIME-specific paste. Never outputs clipboard data or errors containing it."""
import json
import os
from pathlib import Path
import resource
import shutil
import subprocess
import sys
import tempfile

FORMATS = {"image/png": "png", "image/jpeg": "jpeg", "image/webp": "webp", "image/bmp": "bmp", "image/tiff": "tiff"}

def base_dir():
    base = Path(os.environ.get("XDG_RUNTIME_DIR", str(Path.home() / ".cache"))) / "oma.kvitto" / "images"
    base.mkdir(parents=True, exist_ok=True, mode=0o700)
    return base

def remove(path):
    path = Path(path)
    base = base_dir().resolve()
    if path.name == "preview.png" and path.parent.parent.resolve() == base and path.parent.name.startswith("paste-") and not path.parent.is_symlink():
        shutil.rmtree(path.parent, ignore_errors=True)

def prepare(source, kind, directory):
    out = Path(directory) / "preview.png"
    subprocess.run(["magick", "-limit", "memory", "128MiB", "-limit", "map", "256MiB", "-limit", "disk", "256MiB", "-limit", "width", "32768", "-limit", "height", "32768", kind + ":" + str(source) + "[0]", "-auto-orient", "-background", "white", "-alpha", "remove", "-alpha", "off", "-resize", "512x", "-colorspace", "Gray", "-dither", "FloydSteinberg", "-remap", "pattern:gray50", str(out)], check=True, timeout=15, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    dims = subprocess.run(["magick", "identify", "-format", "%w %h", str(out)], check=True, timeout=3, capture_output=True).stdout.decode().split()
    if len(dims) != 2 or int(dims[0]) != 512 or int(dims[1]) > 16384:
        raise ValueError("dimensions")
    out.chmod(0o600)
    return out

def file_limit():
    resource.setrlimit(resource.RLIMIT_FSIZE, (32 * 1024 * 1024, 32 * 1024 * 1024))

def main():
    os.umask(0o077)
    # Never inherit a verbose Wayland wire log when clipboard is involved.
    os.environ.pop("WAYLAND_DEBUG", None)
    if len(sys.argv) == 3 and sys.argv[1] == "--remove":
        remove(sys.argv[2]); return
    directory = None
    try:
        types = subprocess.run(["wl-paste", "--list-types"], check=True, timeout=3, capture_output=True).stdout.decode("utf-8", "replace").splitlines()
        mime = next((m for m in FORMATS if m in types), None)
        if mime is None:
            print(json.dumps({"kind": "text"})); return
        directory = Path(tempfile.mkdtemp(prefix="paste-", dir=base_dir()))
        source = directory / "source"
        with source.open("wb") as stream:
            subprocess.run(["wl-paste", "--no-newline", "--type", mime], stdout=stream, stderr=subprocess.DEVNULL, check=True, timeout=5, preexec_fn=file_limit)
        out = prepare(source, FORMATS[mime], directory)
        source.unlink()
        print(json.dumps({"kind": "image", "path": str(out)}))
    except Exception:
        if directory:
            shutil.rmtree(directory, ignore_errors=True)
        print(json.dumps({"kind": "error"}))
        sys.exit(1)

if __name__ == "__main__":
    main()
