"""Locate FL Studio's user data folder wherever it lives.

FL's "user data folder" (Options > File settings) defaults to
<Documents>/Image-Line but is freely relocatable -- another drive
(D:/Image-Line) or a OneDrive-redirected Documents are both common.
Every filesystem assumption about that folder funnels through here so a
relocated install is found once, consistently, by all features.

Resolution order:
  1. FLSTUDIO_MCP_USER_DATA -- the Image-Line folder itself (an
     "FL Studio*" folder directly beneath one is also accepted).
  2. Windows: FL's own "Shared data" path from the registry. FL writes
     this itself, so it is authoritative -- and it is the only source
     that stays right when the user data folder has been relocated.
  3. <home>/Documents/Image-Line, <home>/OneDrive/Documents/Image-Line,
     <home>/Image-Line.
  4. Windows: <drive>:/Image-Line for each drive letter.

A candidate only counts if some "FL Studio*" folder beneath it contains a
NON-EMPTY Settings or Presets folder. The emptiness check matters: writing
a file under ~/Documents/Image-Line (the last-resort fallback below) would
otherwise create a folder that then wins resolution over the real one on
every later call -- a decoy of our own making.
"""

from __future__ import annotations

import os
import string
import sys
from pathlib import Path

ENV_USER_DATA = "FLSTUDIO_MCP_USER_DATA"


def _is_fl_dir(fl: Path) -> bool:
    for sub in ("Settings", "Presets"):
        d = fl / sub
        try:
            if d.is_dir() and any(d.iterdir()):
                return True
        except OSError:
            continue
    return False


def _registry_user_data() -> Path | None:
    """FL's own "Shared data" path (Windows only); None if unset/unusable."""
    if sys.platform != "win32":
        return None
    try:
        import winreg

        with winreg.OpenKey(winreg.HKEY_CURRENT_USER,
                            r"Software\Image-Line\Shared\Paths") as key:
            raw, _ = winreg.QueryValueEx(key, "Shared data")
    except (OSError, ImportError, ValueError):
        return None
    if not raw:
        return None
    p = Path(str(raw).strip().rstrip("\\/"))
    return p if _has_fl_studio(p) else None


def _has_fl_studio(root: Path) -> bool:
    try:
        return root.is_dir() and any(_is_fl_dir(fl) for fl in root.glob("FL Studio*"))
    except OSError:
        return False


def find_image_line_dir() -> Path | None:
    """The active Image-Line folder, or None (see module docstring for order)."""
    env = os.environ.get(ENV_USER_DATA)
    if env:
        p = Path(env)
        if _has_fl_studio(p):
            return p
        if p.name.startswith("FL Studio") and _is_fl_dir(p):
            return p.parent
    reg = _registry_user_data()
    if reg is not None:
        return reg
    home = Path.home()
    candidates = [
        home / "Documents" / "Image-Line",
        home / "OneDrive" / "Documents" / "Image-Line",
        home / "Image-Line",
    ]
    if sys.platform == "win32":
        candidates += [Path(f"{d}:\\Image-Line") for d in string.ascii_uppercase]
    for c in candidates:
        if _has_fl_studio(c):
            return c
    return None


def fl_studio_dirs():
    """"FL Studio*" folders under the active Image-Line dir, newest-name first."""
    root = find_image_line_dir()
    if root is not None:
        yield from sorted(root.glob("FL Studio*"), reverse=True)


def piano_roll_scripts_dir() -> str:
    """The live "Piano roll scripts" folder. Prefers the versionless "FL Studio"
    dir (FL 2025's layout); falls back to the standard Documents path so callers
    can still mkdir a fresh install."""
    root = find_image_line_dir()
    if root is not None:
        for fl in [root / "FL Studio", *sorted(root.glob("FL Studio *"), reverse=True)]:
            if (fl / "Settings").is_dir():
                return str(fl / "Settings" / "Piano roll scripts")
    return os.path.expanduser("~/Documents/Image-Line/FL Studio/Settings/Piano roll scripts")
