"""Verify cross-platform fonts, restoring missing files from the tracked runtime ZIP."""

import hashlib
import pathlib
import re
import sys
import xml.etree.ElementTree as ET
import zipfile


def manifest_hash(data: bytes) -> str:
    # update_manifest.py hashes text files after CRLF normalization.
    if b"\0" not in data:
        data = re.sub(rb"\r\n?|\n", b"\r\n", data)
    return hashlib.sha1(data).hexdigest()


def main(root: pathlib.Path) -> None:
    manifest = ET.parse(root / "manifest.xml").getroot()
    fonts = [
        node
        for node in manifest.findall("File")
        if node.get("part") == "runtime"
        and (node.get("name") or "").startswith("SimpleGraphic/Fonts/")
    ]
    if not fonts:
        raise RuntimeError("manifest has no SimpleGraphic fonts")

    with zipfile.ZipFile(root / "runtime-win32.zip") as runtime_zip:
        for node in fonts:
            name = node.attrib["name"]
            expected = node.attrib["sha1"]
            target = root / "runtime" / name
            if target.is_file() and manifest_hash(target.read_bytes()) == expected:
                continue
            data = runtime_zip.read(name)
            if manifest_hash(data) != expected:
                raise RuntimeError(f"font checksum mismatch: {name}")
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
    print(f"Verified {len(fonts)} font files")


if __name__ == "__main__":
    main(pathlib.Path(sys.argv[1]))
