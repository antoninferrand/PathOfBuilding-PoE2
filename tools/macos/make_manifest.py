"""Write the small, bundle-local manifest used by the manual-update macOS app."""

import argparse
import pathlib
import xml.etree.ElementTree as ET


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=pathlib.Path)
    parser.add_argument("destination", type=pathlib.Path)
    parser.add_argument("--branch", choices=("dev", "master"), default="dev")
    args = parser.parse_args()

    version = ET.parse(args.source).getroot().find("Version")
    if version is None or not version.get("number"):
        raise RuntimeError("source manifest has no version number")

    root = ET.Element("PoBVersion")
    ET.SubElement(
        root,
        "Version",
        number=version.attrib["number"],
        platform="macos-arm64",
        branch=args.branch,
    )
    ET.indent(root, "\t")
    args.destination.parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(root).write(args.destination, encoding="UTF-8", xml_declaration=True)
    print(version.attrib["number"])


if __name__ == "__main__":
    main()
