import sys
from pathlib import Path

# Add project root to path
ROOT_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT_DIR))

from scripts.setup_typography import BANNER_LINES, setup_typography, is_already_patched


def test_banner_lines_structure():
    assert len(BANNER_LINES) == 13
    assert "DARK" in "".join(BANNER_LINES[:6]) or "██" in "".join(BANNER_LINES[:6])
    assert "✦  🌌  ✦" in BANNER_LINES[6]
    assert "MATTER" in "".join(BANNER_LINES[7:]) or "██" in "".join(BANNER_LINES[7:])


def test_is_already_patched_nonexistent(tmp_path):
    fake_exe = tmp_path / "nonexistent.exe"
    assert not is_already_patched(fake_exe)


def test_setup_typography_executes():
    # Calling setup_typography on current machine should return a boolean without unhandled exception
    res = setup_typography()
    assert isinstance(res, bool)
