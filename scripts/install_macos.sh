#!/usr/bin/env bash
# ============================================================================
# FLStudioMCP -- macOS installer (v0.2 -- MIDI transport)
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# FL's user data folder (Image-Line) is relocatable (FL: Options > File
# settings > "User data folder"). Pass it as $1 or set FLSTUDIO_MCP_USER_DATA
# if it isn't in one of the usual spots.
IMAGE_LINE="${1:-${FLSTUDIO_MCP_USER_DATA:-}}"
if [[ -z "$IMAGE_LINE" ]]; then
  for c in "$HOME/Documents/Image-Line" "$HOME/Image-Line"; do
    if [[ -d "$c/FL Studio/Settings/Hardware" ]]; then IMAGE_LINE="$c"; break; fi
  done
fi
if [[ -z "$IMAGE_LINE" || ! -d "$IMAGE_LINE/FL Studio/Settings/Hardware" ]]; then
  echo "  Could not find FL Studio's user data folder (Image-Line)."
  echo "  If FL Studio has never been opened on this machine, open it once and re-run."
  echo "  Otherwise find it in FL Studio (Options > File settings > 'User data"
  echo "  folder') and re-run with it as an argument:"
  echo "    ./scripts/install_macos.sh \"/path/to/Image-Line\""
  exit 1
fi
export FLSTUDIO_MCP_USER_DATA="$IMAGE_LINE"
FL_HARDWARE="$IMAGE_LINE/FL Studio/Settings/Hardware"
TARGET="$FL_HARDWARE/FLStudioMCP"

echo
echo "  FL user data folder: $IMAGE_LINE"

echo
echo "[1/4] Installing FL Studio controller script..."
mkdir -p "$TARGET"
cp "$REPO_ROOT/fl_controller/FLStudioMCP/device_FLStudioMCP.py" "$TARGET/"
echo "  Installed to $TARGET"

echo
echo "[2/4] Installing the MCP server (editable)..."
if ! command -v python3 >/dev/null 2>&1; then
  echo "  python3 not found. Install Python 3.10+ and re-run."
  exit 1
fi
cd "$REPO_ROOT"
python3 -m pip install --upgrade pip >/dev/null
python3 -m pip install -e .

echo
echo "[3/4] Seeding the note-bridge pyscript (MCP_Apply)..."
if ! python3 - <<'PYEOF'
import os

import fl_studio_mcp.pyscript_gen as g

os.makedirs(g.PIANO_ROLL_SCRIPTS_DIR, exist_ok=True)
print("  Seeded " + g.write_apply_script([], mode="append"))
PYEOF
then
  echo "  Note: Could not pre-seed MCP_Apply. Non-fatal -- the daemon will write it on first note-write."
fi

echo
echo "[4/4] Checking for IAC Driver ports..."
python3 - <<'PYEOF'
import mido
names = set(mido.get_output_names()) | set(mido.get_input_names())
rx, tx = "FLStudioMCP RX", "FLStudioMCP TX"
missing = [n for n in (rx, tx) if not any(n.lower() in x.lower() for x in names)]
if not missing:
    print("  All required ports present.")
else:
    print(f"  Missing ports: {missing}")
PYEOF

cat <<EOF

Done.

Next steps:
  1. If the port check above said any port is MISSING:
     - Open 'Audio MIDI Setup'.
     - Window > Show MIDI Studio.
     - Double-click IAC Driver. Tick 'Device is online'.
     - Under 'Ports', add two ports named exactly:
         FLStudioMCP RX
         FLStudioMCP TX
     - Apply, then re-run this installer.
  2. Open FL Studio.
  3. Options > MIDI Settings:
       Input list  > click 'FLStudioMCP RX', tick Enable, Controller type=FLStudioMCP, Port=42.
       Output list > click 'FLStudioMCP TX', tick Enable, Port=42 (SAME number).
  4. View > Script output should show '[FLStudioMCP] Ready. ...'.
  5. Run: python3 scripts/test_bridge.py

IMPORTANT (macOS Accessibility):
  Note writing simulates Cmd+Opt+Y to trigger FL Studio's "Run last script again"
  command. Grant Accessibility permission to the application running the MCP
  server or daemon, for example Terminal, iTerm, Claude Desktop, or Cursor:

    System Settings > Privacy & Security > Accessibility
EOF
