#!/usr/bin/env python3
"""Reject release feeds that advertise stale or mislabeled archives."""

import sys
import xml.etree.ElementTree as ET

SPARKLE = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"


def validate_appcast(path, version, archive_url, build_number=None):
    """`build_number` is the bundle version Sparkle compares. It defaults to the release version."""
    items = ET.parse(path).findall("./channel/item")
    if len(items) != 1:
        raise ValueError("The release feed must contain exactly one update.")
    item = items[0]
    expected = {"version": build_number or version, "shortVersionString": version}
    for key, value in expected.items():
        if item.findtext(SPARKLE + key) != value:
            raise ValueError(f"The update's {key} must be {value}.")
    enclosure = item.find("enclosure")
    if enclosure is None or enclosure.get("url") != archive_url:
        raise ValueError("The update must point to the current release archive.")
    if not enclosure.get(SPARKLE + "edSignature"):
        raise ValueError("The update archive must have a Sparkle signature.")
    if int(enclosure.get("length", "0")) <= 0:
        raise ValueError("The update archive must have a positive size.")


if __name__ == "__main__":
    validate_appcast(*sys.argv[1:])
