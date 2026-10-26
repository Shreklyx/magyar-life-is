#!/usr/bin/env python3
"""Clickteam Install Creator (2.x) telepítő kicsomagolása, futtatás nélkül.

Ezzel készült a mac/fajlok mappa a LISHUN-5.0.exe-ből:

    python3 tools/extract_clickteam.py LISHUN-5.0.exe kimenet/

A telepítő felépítése: a PE fájl után jön az adatrész ("wwgT)H" aláírás),
benne blokkok (2 bájt azonosító, 2 bájt típus, 4 bájt méret). A 0x143A blokk
a fájllista, a 0x7F7F blokk a tömörített fájlok (zlib vagy bzip2).
"""
import bz2
import os
import struct
import sys
import zlib

SIGNATURE = b"wwgT)H"
BLOCK_FILE_LIST = 0x143A
BLOCK_FILE_DATA = 0x7F7F


def overlay_offset(exe):
    pe = struct.unpack_from("<I", exe, 0x3C)[0]
    sections = struct.unpack_from("<H", exe, pe + 6)[0]
    opt_size = struct.unpack_from("<H", exe, pe + 20)[0]
    table = pe + 24 + opt_size
    end = 0
    for i in range(sections):
        raw_size, raw_ptr = struct.unpack_from("<II", exe, table + i * 40 + 16)
        end = max(end, raw_ptr + raw_size)
    return end


def unpack(method, data):
    if method == 0:
        return data
    if method == 1:
        return zlib.decompress(data)
    if method == 2:
        return bz2.decompress(data)
    raise ValueError("ismeretlen tömörítés: %d" % method)


def read_blocks(exe):
    pos = overlay_offset(exe)
    if exe[pos:pos + len(SIGNATURE)] != SIGNATURE:
        raise ValueError("nem Clickteam Install Creator telepítő")
    pos += len(SIGNATURE)
    blocks = {}
    while pos + 8 <= len(exe):
        block_id, _, size = struct.unpack_from("<HHI", exe, pos)
        if block_id == BLOCK_FILE_DATA:
            # A méret nem tartalmazza az adatrész elején lévő 4 bájtos
            # hosszmezőt, ezért itt a fájl végéig olvasunk.
            blocks[block_id] = exe[pos + 8 + 4:]
            break
        data = exe[pos + 8:pos + 8 + size]
        blocks[block_id] = unpack(data[4], data[5:])
        pos += 8 + size
    return blocks


def list_files(file_list):
    pos = 4
    while pos < len(file_list):
        size, _, kind = struct.unpack_from("<HHI", file_list, pos)
        if size == 0:
            break
        entry = file_list[pos:pos + size]
        name_at = 64 if kind == 0 else 40
        name = entry[name_at:].split(b"\0")[0].decode("cp1250")
        usize, offset, csize = struct.unpack_from("<III", entry, 24)
        yield name, offset, csize, usize
        pos += size


def main():
    if len(sys.argv) != 3:
        sys.exit("használat: extract_clickteam.py TELEPITO.exe KIMENETI_MAPPA")
    exe = open(sys.argv[1], "rb").read()
    out = sys.argv[2]
    blocks = read_blocks(exe)
    data = blocks[BLOCK_FILE_DATA]
    count = 0
    for name, offset, csize, usize in list_files(blocks[BLOCK_FILE_LIST]):
        chunk = data[offset:offset + csize]
        content = unpack(chunk[0], chunk[1:])
        if len(content) != usize:
            raise ValueError("hibás méret: %s" % name)
        parts = [p for p in name.split("\\") if p not in ("", ".", "..")]
        path = os.path.join(out, *parts)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as f:
            f.write(content)
        count += 1
    print("%d fájl kicsomagolva ide: %s" % (count, out))


if __name__ == "__main__":
    main()
