#!/usr/bin/env python3
"""arm64_disas.py — desensambla un rango del segmento __TEXT con Capstone.

Uso:
  python scripts/re/arm64_disas.py <binario> --offset 0x100000 --size 0x200

Trabaja sobre una ventana mmap (no carga los 171 MB). Útil para inspeccionar
puntualmente funciones candidatas localizadas con macho_triage.py.
"""
from __future__ import annotations

import argparse
import mmap
import os
import sys


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("binary")
    ap.add_argument("--offset", required=True, help="offset de archivo, ej. 0x100000")
    ap.add_argument("--size", default="0x200")
    ap.add_argument("--vaddr", default="0x0", help="vaddr base para imprimir")
    args = ap.parse_args()

    try:
        from capstone import CS_ARCH_ARM64, CS_MODE_ARM, Cs
    except ImportError:
        print("Falta capstone: pip install -r scripts/re/requirements-re.txt", file=sys.stderr)
        return 2

    off = int(args.offset, 0)
    size = int(args.size, 0)
    vaddr = int(args.vaddr, 0)
    total = os.path.getsize(args.binary)
    if off < 0 or size <= 0 or off + size > total:
        print(f"Rango inválido (binario: {total} bytes)", file=sys.stderr)
        return 2

    with open(args.binary, "rb") as f, mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ) as mm:
        code = bytes(mm[off : off + size])
    md = Cs(CS_ARCH_ARM64, CS_MODE_ARM)
    md.detail = False
    for ins in md.disasm(code, vaddr or off):
        print(f"{ins.address:#x}:\t{ins.mnemonic}\t{ins.op_str}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
