"""Locate FL Studio's user data folder wherever it lives.

FL's "user data folder" (Options > File settings) defaults to
<Documents>/Image-Line but is freely relocatable -- another drive
(D:/Image-Line) or a OneDrive-redirected Documents are both common.
Every filesystem assumption about that folder funnels through here so a
relocated install is found once, consistently, by all features.

Resolution order:
  1. FLSTUDIO_MCP_USER_DATA -- the Image-Line folder itself (an
     "FL Studio*" folder directly beneath one is also accepted).
  2. <home>/Documents/Image-Line, <home>/OneDrive/Documents/Image-Line,
     <home>/Image-Line.
  3. Windows: <drive>:/Image-Line for each drive letter.

A candidate only counts if some "FL Studio*" folder beneath it contains
Settings or Presets -- this skips stale or unrelated folders (e.g. one
left behind by FL Studio Mobile).
"""

from __future__ import annotations

import os
import string
import sys
from pathlib import Path

ENV_USER_DATA = "FLSTUDIO_MCP_USER_DATA"


def _is_fl_dir(fl: Path) -> bool:
    return (fl / "Settings").is_dir() or (fl / "Presets").is_dir()


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
