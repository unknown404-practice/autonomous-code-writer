#!/usr/bin/env python3
"""
Dark Matter - Custom TUI Typography Setup Script
Configures the Docker CLI Agent plugin with Dark Matter block typography.
"""

import os
import sys
import struct
import shutil
from pathlib import Path

# Target block typography for Dark Matter TUI banner
BANNER_LINES = [
    "          ██████╗   █████╗  ██████╗ ██╗  ██╗ ",
    "          ██╔══██╗ ██╔══██╗ ██╔══██╗██║ ██╔╝ ",
    "          ██║  ██║ ███████║ ██████╔╝█████╔╝  ",
    "          ██║  ██║ ██╔══██║ ██╔══██╗██╔═██╗  ",
    "          ██████╔╝ ██║  ██║ ██║  ██║██║  ██╗ ",
    "          ╚═════╝  ╚═╝  ╚═╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ",
    "                         ✦  🌌  ✦",
    "    ███╗   ███╗ █████╗ ████████╗████████╗███████╗██████╗ ",
    "    ████╗ ████║██╔══██╗╚══██╔══╝╚══██╔══╝██╔════╝██╔══██╗",
    "    ██╔████╔██║███████║   ██║      ██║   █████╗  ██████╔╝",
    "    ██║╚██╔╝██║██╔══██║   ██║      ██║   ██╔══╝  ██╔══██╗",
    "    ██║ ╚═╝ ██║██║  ██║   ██║      ██║   ███████╗██║  ██║",
    "    ╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝      ╚═╝   ╚══════╝╚═╝  ╚═╝"
]

TABLE_OFFSET = 0x7DE5F60
DEST_RAW = 0x789BD58
DEST_VA = 0x14789DD58

CANDIDATE_SOURCES = [
    Path(os.environ.get("ProgramFiles", r"C:\Program Files")) / "Docker" / "cli-plugins" / "docker-agent.exe",
    Path(os.environ.get("ProgramFiles", r"C:\Program Files")) / "Docker" / "Docker" / "resources" / "cli-plugins" / "docker-agent.exe",
]


def is_already_patched(exe_path: Path) -> bool:
    try:
        with open(exe_path, "rb") as f:
            f.seek(DEST_RAW)
            header = f.read(20)
            return b"\xe2\x96\x88" in header  # Unicode block char '█'
    except Exception:
        return False


def setup_typography() -> bool:
    if sys.platform != "win32":
        # Non-Windows platforms
        return True

    user_plugins = Path(os.path.expanduser("~")) / ".docker" / "cli-plugins"
    user_plugins.mkdir(parents=True, exist_ok=True)
    target_exe = user_plugins / "docker-agent.exe"

    if target_exe.exists() and is_already_patched(target_exe):
        return True

    # Find stock source binary
    source_exe = None
    for cand in CANDIDATE_SOURCES:
        if cand.exists():
            source_exe = cand
            break

    if not source_exe and not target_exe.exists():
        return False

    if not target_exe.exists() or not is_already_patched(target_exe):
        if source_exe:
            shutil.copyfile(source_exe, target_exe)

    try:
        with open(target_exe, "r+b") as f:
            # 1. Write banner lines to reserved space in .data section
            curr_raw = DEST_RAW
            curr_va = DEST_VA
            slice_entries = []

            for line in BANNER_LINES:
                b = line.encode("utf-8")
                f.seek(curr_raw)
                f.write(b)
                slice_entries.append((curr_va, len(b)))
                curr_raw += len(b)
                curr_va += len(b)

            # 2. Update slice pointer / length table
            for i, (ptr, length) in enumerate(slice_entries):
                f.seek(TABLE_OFFSET + i * 16)
                f.write(struct.pack("<QQ", ptr, length))

            # 3. Clear DYNAMIC_BASE (0x0040) and HIGH_ENTROPY_VA (0x0020) in PE Optional Header
            f.seek(0x3C)
            pe_offset = struct.unpack("<I", f.read(4))[0]
            dll_char_offset = pe_offset + 4 + 20 + 70
            f.seek(dll_char_offset)
            dll_char = struct.unpack("<H", f.read(2))[0]
            new_char = dll_char & ~0x60
            f.seek(dll_char_offset)
            f.write(struct.pack("<H", new_char))

        return True
    except Exception as e:
        print(f"Warning: Could not customize TUI banner: {e}", file=sys.stderr)
        return False


if __name__ == "__main__":
    success = setup_typography()
    sys.exit(0 if success else 1)
