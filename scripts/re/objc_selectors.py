#!/usr/bin/env python3
"""objc_selectors.py — verifica qué selectores/clases ObjC existen COMPILADOS
en el binario (secciones __objc_methname / __objc_classname).

Distingue "el símbolo existe" (strings sueltos) de "hay un método real".
Clave para OpusLock: los accessors GPB @dynamic NO aparecen en methname.

Uso:
  .venv-re/Scripts/python scripts/re/objc_selectors.py <binario> [--out dir]
"""
from __future__ import annotations

import argparse
import json
import os
import sys

SELECTORS = [
    # Pill / player-response
    "streamingData",
    "adaptiveFormatsArray",
    "adaptiveFormats",
    "itag",
    "url",
    "mimeType",
    "allowAudioOnlyManualQualitySelection",
    "ytm_isAudioOnlyPlayable",
    "ytm_audioOnlyUpsell",
    # Menú cuenta (probado: funciona)
    "setAccountMenuUpperButtons:lowerButtons:",
    "initWithTitle:identifier:icon:actionBlock:",
    "_viewControllerForAncestor",
    # Núcleo anterior
    "replaceCurrentItemWithPlayerItem:",
]
CLASSES = [
    "YTIPlayerResponse",
    "YTMSettings",
    "YTMSettingsImpl",
    "YTMAvatarAccountView",
    "YTMAccountButton",
    "HAMPlayer",
]


def methnames(path: str) -> set[str]:
    import lief  # type: ignore

    fb = lief.MachO.parse(path, config=lief.MachO.ParserConfig.quick)
    if fb is None:
        raise RuntimeError("LIEF no pudo parsear el binario")
    b = fb.at(0)
    names: set[str] = set()
    for seg in b.segments:
        for sec in seg.sections:
            if sec.name in ("__objc_methname", "__objc_classname"):
                names.update(s.decode("utf-8", "ignore") for s in bytes(sec.content).split(b"\x00") if s)
    return names


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("binary")
    ap.add_argument("--out", default=os.path.join("scripts", "re", "out"))
    args = ap.parse_args()
    names = methnames(args.binary)
    report = {
        "methname_count": len(names),
        "selectors": {s: (s in names) for s in SELECTORS},
        "classes": {c: (c in names) for c in CLASSES},
    }
    os.makedirs(args.out, exist_ok=True)
    dest = os.path.join(args.out, "objc_selectors.json")
    with open(dest, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    for s, ok in report["selectors"].items():
        print(("OK   " if ok else "FALTA"), "sel ", s)
    for c, ok in report["classes"].items():
        print(("OK   " if ok else "FALTA"), "cls ", c)
    print(f"({report['methname_count']} nombres en methname/classname)")
    print(f"OK: {dest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
