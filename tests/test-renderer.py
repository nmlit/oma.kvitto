#!/usr/bin/env python3
"""Synthetic tests. All renderer calls use OMA_KVITTO_OUT; no clipboard IO."""
import hashlib
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
sys.dont_write_bytecode = True
PLUGIN = Path(os.environ.get("OMA_KVITTO_TEST_PLUGIN", Path(__file__).resolve().parents[1]))
FONTS = PLUGIN / "fonts/atkinson-hyperlegible"
EXPECTED = {
    "Regular": "7fb917c89019896d0b52ee84b7cbb3304c18cb90b19a62f5e32712bd23e97669",
    "Bold": "5a3b0c8cc8ca545155150b4512a1fa248298df121c50d6557e651e61fbdab92f",
    "Italic": "021beda4d3c6edfc78872e436d74009f9a1bcb294331908fe5747c61d3dcc514",
    "BoldItalic": "7a46f1b0ef2f64b61065c1a6b5a11fcb9b019b44062d88ba121a083cc39e86bf",
}
def raster(data):
    init = b"\x1b@\x1bR\x05\x1bt\x10"
    assert data.startswith(init)
    pos, rows = len(init), []
    while data[pos:pos+4] != b"\x1dVB\0":
        assert data[pos:pos+4] == b"\x1dv0\0"
        width = int.from_bytes(data[pos+4:pos+6], "little")
        height = int.from_bytes(data[pos+6:pos+8], "little")
        assert width == 64 and 0 < height <= 128
        pos += 8
        rows.extend(data[pos+y*width:pos+(y+1)*width] for y in range(height))
        pos += width*height
    assert data[pos:] == b"\x1dVB\0"
    assert len(rows) >= round(80*180/25.4)
    assert all(row == bytes(64) for row in rows[-round(10*180/25.4):])
    return rows
class RendererTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="oma-kvitto-test-")
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)
        empty = self.dir / "empty-fonts"; empty.mkdir()
        self.fc = self.dir / "fontconfig.xml"
        self.fc.write_text(f"<fontconfig><dir>{empty}</dir><cachedir>{self.dir / 'cache'}</cachedir></fontconfig>")
    def env(self, no_fonts=False):
        env = os.environ.copy()
        env.update(OMA_KVITTO_OUT=str(self.dir / "output.bin"), OMA_KVITTO_DEV="/NOT-A-PRINTER", OMA_KVITTO_CUPS="NOT-A-QUEUE")
        if no_fonts: env.update(FONTCONFIG_FILE=str(self.fc), FONTCONFIG_PATH=str(self.dir))
        return env
    def render(self, text, font=None, size="30", image=None, no_fonts=False):
        env = self.env(no_fonts)
        args = ["bash", str(PLUGIN / "print.sh"), text]
        if font is not None: args += [font, str(size)]
        if image is not None: args += [str(image)]
        proc = subprocess.run(args, env=env, capture_output=True, timeout=30)
        self.assertEqual(proc.returncode, 0, proc.stderr.decode("utf-8", "replace"))
        self.assertEqual(proc.stderr, b"")
        return (self.dir / "output.bin").read_bytes()
    def test_upstream_hashes_and_license(self):
        for style, digest in EXPECTED.items():
            self.assertEqual(hashlib.sha256((FONTS / f"AtkinsonHyperlegible-{style}.ttf").read_bytes()).hexdigest(), digest)
        license = (FONTS / "OFL.txt").read_text()
        self.assertIn("Copyright 2020 Braille Institute of America, Inc.", license)
        self.assertIn("SIL OPEN FONT LICENSE Version 1.1", license)
    def test_default_and_named_font_without_system_fonts(self):
        env = self.env(True)
        self.assertEqual(subprocess.run(["fc-list"], env=env, capture_output=True, check=True).stdout, b"")
        self.assertEqual(subprocess.run(["fc-match", "-f", "%{file}", "Atkinson Hyperlegible"], env=env, capture_output=True).stdout, b"")
        for font in [None, "Atkinson Hyperlegible", str(FONTS / "AtkinsonHyperlegible-Regular.ttf")]:
            rows = raster(self.render("ÅÄÖ åäö 0123456789", font=font, no_fonts=True))
            self.assertTrue(any(any(row) for row in rows))
    def test_other_fonts_and_sizes(self):
        for font in ["monospace", "Noto Serif", "Atkinson Hyperlegible"]:
            for size in [6, 24, 30, 80]:
                raster(self.render("Åäö 100%\n  indrag\n@test \\ slut", font=font, size=size))
    def test_image_only_and_mixed(self):
        spec = importlib.util.spec_from_file_location("clip", PLUGIN / "clipboard-image.py")
        clip = importlib.util.module_from_spec(spec); spec.loader.exec_module(clip)
        source = self.dir / "source.png"
        subprocess.run(["magick", "-size", "320x160", "xc:none", "-fill", "black", "-draw", "rectangle 0,0 79,159", str(source)], check=True, capture_output=True)
        preview = clip.prepare(source, "png", self.dir)
        info = subprocess.run(["magick", "identify", "-format", "%w %h %k", str(preview)], check=True, capture_output=True).stdout
        self.assertEqual(info, b"512 256 2")
        for text in ["", "Åäö bild efter text"]:
            raster(self.render(text, font="Atkinson Hyperlegible", image=preview, no_fonts=True))
    def test_bad_image_fails_closed(self):
        bad = self.dir / "bad.png"; bad.write_bytes(b"not a PNG")
        proc = subprocess.run(["bash", str(PLUGIN / "print.sh"), "Åäö", "Atkinson Hyperlegible", "30", str(bad)], env=self.env(True), capture_output=True, timeout=30)
        self.assertNotEqual(proc.returncode, 0)
        self.assertFalse((self.dir / "output.bin").exists())
    def test_clipboard_mock_without_real_clipboard_access(self):
        import json
        mock = self.dir / "mock-bin"; mock.mkdir()
        source = self.dir / "synthetic.png"
        subprocess.run(["magick", "-size", "32x16", "xc:black", str(source)], check=True, capture_output=True)
        fake = mock / "wl-paste"
        fake.write_text('#!/usr/bin/env python3\nimport os,sys\nfrom pathlib import Path\nif sys.argv[1:]==["--list-types"]: print(os.environ["MOCK_MIME"])\nelse:\n assert sys.argv[1:]==["--no-newline","--type","image/png"]\n sys.stdout.buffer.write(Path(os.environ["MOCK_IMAGE"]).read_bytes())\n')
        fake.chmod(0o700)
        env = self.env(); env.update(PATH=str(mock)+":"+env["PATH"], MOCK_MIME="image/png", MOCK_IMAGE=str(source), XDG_RUNTIME_DIR=str(self.dir / "runtime"))
        helper = ["python3", str(PLUGIN / "clipboard-image.py")]
        result = json.loads(subprocess.run(helper, env=env, check=True, capture_output=True, timeout=20).stdout)
        self.assertEqual(result["kind"], "image")
        self.assertTrue(Path(result["path"]).exists())
        subprocess.run(helper+["--remove",result["path"]], env=env, check=True, capture_output=True)
        self.assertFalse(Path(result["path"]).exists())
        env["MOCK_MIME"]="text/plain"
        self.assertEqual(json.loads(subprocess.run(helper, env=env, check=True, capture_output=True).stdout), {"kind":"text"})
        env["MOCK_MIME"]="image/png"; source.write_bytes(b"not an image")
        result=subprocess.run(helper, env=env, capture_output=True, timeout=20)
        self.assertEqual(result.returncode,1)
        self.assertEqual(json.loads(result.stdout),{"kind":"error"})
        self.assertEqual(result.stderr,b"")
    @unittest.skipUnless(shutil.which("quickshell"), "quickshell required for headless QML test")
    def test_qml_fonts_and_existing_settings_without_system_fonts(self):
        source = (PLUGIN / "Overlay.qml").read_text()
        defaults = "\n".join(line for line in source.splitlines() if "property string printFont:" in line or "property int printSize:" in line)
        load_process = source[source.index("  Process {\n    id: loadProc"):source.index("  Process {\n    id: fontProc")]
        for saved, expected_font, expected_size in [(None,"Atkinson Hyperlegible",20),("Noto Serif\n37\n", "Noto Serif",37),("Atkinson Hyperlegible\n30\n", "Atkinson Hyperlegible",30)]:
            settings = self.dir / "settings.conf"
            if saved is not None: settings.write_text(saved)
            elif settings.exists(): settings.unlink()
            qml = self.dir / "probe.qml"
            # Resolve the real Overlay's relative FontLoader URLs in a fresh
            # package-like tree; no global/system font registration exists.
            local_fonts = self.dir / "fonts/atkinson-hyperlegible"
            local_fonts.mkdir(parents=True, exist_ok=True)
            for font_file in FONTS.glob("*.ttf"):
                shutil.copy2(font_file, local_fonts / font_file.name)
            font_lines = [line.strip() for line in source.splitlines() if line.strip().startswith("FontLoader {")]
            self.assertEqual(len(font_lines), 4)
            loaders = "\n".join(line.replace("id: bundledRegular; ", "").replace("FontLoader {", f"FontLoader {{ id: f{i};", 1) for i,line in enumerate(font_lines))
            qml.write_text('import QtQuick\nimport Quickshell\nimport Quickshell.Io\nShellRoot {\nid: root\n' + defaults + f'\nproperty string settingsFile: "{settings}"\n' + loaders + load_process + '''
Text { id: sample; text: "ÅÄÖ åäö"; font.family: f0.name; font.pixelSize: 30 }
Timer { interval: 600; running: true; onTriggered: {
''' + f'''if (root.printFont !== {expected_font!r} || root.printSize !== {expected_size} || ![f0,f1,f2,f3].every(f => f.status === FontLoader.Ready) || sample.implicitWidth <= 0) {{
 console.log("SYNTHETIC_PROBE_FAIL")
}} else console.log("SYNTHETIC_PROBE_PASS")
Qt.quit()
}} }}
}}
''')
            env=self.env(True);env.update(QT_QPA_PLATFORM="offscreen",QT_QUICK_BACKEND="software")
            proc=subprocess.run(["quickshell", "--no-color", "-p", str(qml)], env=env, capture_output=True, timeout=10)
            self.assertIn(b"SYNTHETIC_PROBE_PASS", proc.stdout+proc.stderr)
            self.assertNotIn(b"SYNTHETIC_PROBE_FAIL", proc.stdout+proc.stderr)
            if saved is not None: self.assertEqual(settings.read_text(),saved)
            else: self.assertFalse(settings.exists())
if __name__ == "__main__":
    unittest.main(verbosity=2)
