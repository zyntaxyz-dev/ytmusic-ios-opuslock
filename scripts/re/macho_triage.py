#!/usr/bin/env python3
"""macho_triage.py — triaje estático del binario YouTubeMusic en Windows.

Lee SOLO por ventanas (mmap): headers Mach-O vía macholib (ligero),
inventario opcional con LIEF (quick), y búsqueda de strings de calidad
(itag, adaptiveFormats, streamingData, audioQuality, googlevideo).

Uso:
  python scripts/re/macho_triage.py "com.google.ios.youtubemusic-9.35-Decrypted/Payload/YouTubeMusic.app/YouTubeMusic" --out scripts/re/out

Nunca lee el binario completo en memoria ni modifica el .app.
"""
from __future__ import annotations

import argparse
import json
import mmap
import os
import re
import sys

PATTERNS = [
    r"itag",
    r"adaptiveFormats",
    r"streamingData",
    r"audioQuality",
    r"googlevideo",
    r"always.?high",
    r"HAMPlayer",
    r"NowPlaying",
    r"YTMAccountButton",
    r"YTMAvatarAccountView",
    r"setAccountMenuUpperButtons",
    r"YTIPlayerResponse",
    r"ytm_isAudioOnlyPlayable",
    r"allowAudioOnlyManualQualitySelection",
    r"YTMSettings",
    r"adaptiveFormatsArray",
]

CHUNK = 8 * 1024 * 1024


def header_info(path: str) -> dict:
    info: dict = {"path": path, "size": os.path.getsize(path)}
    try:
        from macholib.MachO import MachO

        m = MachO(path)
        headers = []
        for h in m.headers:
            headers.append(
                {
                    "magic": hex(h.MH_MAGIC),
                    "cputype": getattr(h.header, "cputype", None),
                    "ncmds": getattr(h.header, "ncmds", None),
                }
            )
        info["macholib_headers"] = headers
    except Exception as e:  # macholib ausente o binario atípico
        info["macholib_error"] = str(e)[:200]
    try:
        import lief  # type: ignore

        fb = lief.MachO.parse(path, config=lief.MachO.ParserConfig.quick)
        if fb is not None:
            b = fb.at(0)
            info["lief"] = {
                "cpu": str(b.header.cpu_type),
                "has_encryption_info": b.has_encryption_info,
                "encrypted": bool(b.encryption_info.encrypted)
                if b.has_encryption_info
                else None,
            }
    except Exception as e:
        info["lief_error"] = str(e)[:200]
    return info


def string_hits(path: str) -> dict[str, int]:
    rx = re.compile("|".join(f"(?:{p})" for p in PATTERNS), re.IGNORECASE)
    counts = {p: 0 for p in PATTERNS}
    with open(path, "rb") as f, mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ) as mm:
        n = len(mm)
        off = 0
        # Ventanas solapadas para no partir matches en bordes.
        while off < n:
            view = mm[off : off + CHUNK + 4096]
            text = view.decode("utf-8", errors="ignore")
            for m in rx.finditer(text):
                hit = m.group(0).lower()
                for p in PATTERNS:
                    if re.search(p, hit, re.IGNORECASE):
                        counts[p] += 1
                        break
            off += CHUNK
    return counts


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("binary")
    ap.add_argument("--out", default=os.path.join("scripts", "re", "out"))
    args = ap.parse_args()
    if not os.path.isfile(args.binary):
        print(f"No existe: {args.binary}", file=sys.stderr)
        return 2
    os.makedirs(args.out, exist_ok=True)
    report = header_info(args.binary)
    report["string_hits"] = string_hits(args.binary)
    dest = os.path.join(args.out, "macho_triage.json")
    with open(dest, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    print(json.dumps(report, indent=2))
    print(f"OK: {dest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
