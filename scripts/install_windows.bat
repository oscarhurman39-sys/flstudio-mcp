@echo off
REM ============================================================================
REM  flstudio-mcp -- Windows installer
REM    [1] controller script  -> FL Settings\Hardware\FLStudioMCP\
REM    [2] MCP server          -> pip install -e .
REM    [3] note-bridge script  -> seeds MCP_Apply.pyscript in Piano roll scripts\
REM    [4] loopMIDI port check
REM
REM  Finds FL's user data folder (Image-Line) automatically: standard Documents,
REM  OneDrive-redirected Documents, or <drive>:\Image-Line. If yours is somewhere
REM  else, pass it as the first argument or set FLSTUDIO_MCP_USER_DATA:
REM    scripts\install_windows.bat "D:\Image-Line"
REM  (FL shows the folder under Options > File settings > User data folder.)
REM ============================================================================
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "REPO_ROOT=%SCRIPT_DIR%.."

set "FL_SETTINGS="
if not "%~1"=="" (
  if exist "%~1\FL Studio\Settings\Hardware" (
    set "FL_SETTINGS=%~1\FL Studio\Settings"
  ) else (
    echo   "%~1" does not look like an Image-Line folder: no FL Studio\Settings\Hardware inside.
    exit /b 1
  )
)
if not defined FL_SETTINGS if defined FLSTUDIO_MCP_USER_DATA if exist "%FLSTUDIO_MCP_USER_DATA%\FL Studio\Settings\Hardware" set "FL_SETTINGS=%FLSTUDIO_MCP_USER_DATA%\FL Studio\Settings"
if not defined FL_SETTINGS if exist "%USERPROFILE%\Documents\Image-Line\FL Studio\Settings\Hardware" set "FL_SETTINGS=%USERPROFILE%\Documents\Image-Line\FL Studio\Settings"
if not defined FL_SETTINGS if exist "%USERPROFILE%\OneDrive\Documents\Image-Line\FL Studio\Settings\Hardware" set "FL_SETTINGS=%USERPROFILE%\OneDrive\Documents\Image-Line\FL Studio\Settings"
if not defined FL_SETTINGS for %%D in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do if not defined FL_SETTINGS if exist "%%D:\Image-Line\FL Studio\Settings\Hardware" set "FL_SETTINGS=%%D:\Image-Line\FL Studio\Settings"

if not defined FL_SETTINGS (
  echo   Could not find FL Studio's user data folder ^(Image-Line^).
  echo   If FL Studio has never been opened on this machine, open it once and re-run.
  echo   Otherwise find the folder in FL Studio under Options ^> File settings ^>
  echo   "User data folder", then re-run with it as an argument, e.g.:
  echo     scripts\install_windows.bat "D:\Image-Line"
  exit /b 1
)
for %%I in ("%FL_SETTINGS%\..\..") do set "IMAGE_LINE=%%~fI"
set "FLSTUDIO_MCP_USER_DATA=%IMAGE_LINE%"
set "HW_TARGET=%FL_SETTINGS%\Hardware\FLStudioMCP"

echo.
echo   FL user data folder: %IMAGE_LINE%

echo.
echo [1/4] Installing FL Studio controller script...
if not exist "%HW_TARGET%" mkdir "%HW_TARGET%"
copy /Y "%REPO_ROOT%\fl_controller\FLStudioMCP\device_FLStudioMCP.py" "%HW_TARGET%\" >nul
if errorlevel 1 ( echo   Copy failed. Aborting. & exit /b 1 )
echo   Installed to %HW_TARGET%

echo.
echo [2/4] Installing the MCP server (editable)...
set "PY=python"
where python >nul 2>nul
if errorlevel 1 set "PY=py"
where %PY% >nul 2>nul
if errorlevel 1 (
  echo   Python not found ^(tried "python" and the "py" launcher^).
  echo   Install Python 3.12 from python.org, ticking "Add python.exe to PATH",
  echo   then open a NEW terminal and re-run this script.
  exit /b 1
)
echo   Using interpreter: %PY%
pushd "%REPO_ROOT%"
%PY% -m pip install --upgrade pip >nul
%PY% -m pip install -e .
if errorlevel 1 ( echo   pip install failed. See output above. & popd & exit /b 1 )
popd
where fl-studio-mcp-daemon >nul 2>nul
if errorlevel 1 (
  echo   NOTE: "fl-studio-mcp-daemon" is not on PATH. Python's Scripts folder is:
  %PY% -c "import sysconfig; print('     ' + sysconfig.get_path('scripts'))"
  echo   Add that folder to PATH, or launch the daemon and the Claude Desktop
  echo   "command" entry via its full path ^(fl-studio-mcp-daemon.exe / fl-studio-mcp.exe^).
)

echo.
echo [3/4] Seeding the note-bridge pyscript (MCP_Apply)...
%PY% -c "import os, fl_studio_mcp.pyscript_gen as g; os.makedirs(g.PIANO_ROLL_SCRIPTS_DIR, exist_ok=True); print('   seeded ' + g.write_apply_script([], mode='append'))"
if errorlevel 1 echo   Note: could not pre-seed MCP_Apply (FL Piano roll scripts folder missing?). Non-fatal -- the daemon writes it on the first note-write.

echo.
echo [4/4] Checking loopMIDI ports...
%PY% -c "import mido; names=set(mido.get_output_names())|set(mido.get_input_names()); req=('FLStudioMCP RX','FLStudioMCP TX'); missing=[n for n in req if not any(n.lower() in x.lower() for x in names)]; print('   All required ports present.') if not missing else print('   MISSING ports: %s -- create them in loopMIDI.' % missing)"

echo.
echo ============================================================================
echo  Done. Next steps (see README for detail):
echo ============================================================================
echo   1. loopMIDI: if a port was MISSING above, create EXACTLY these two and re-run:
echo        "FLStudioMCP RX"   and   "FLStudioMCP TX"
echo        ( https://www.tobias-erichsen.de/software/loopmidi.html )
echo   2. FL Studio ^> Options ^> MIDI Settings:
echo        Input  ^> "FLStudioMCP RX": Enable, Controller type = FLStudioMCP, Port = 42
echo        Output ^> "FLStudioMCP TX": Enable, Port = 42  (the SAME number)
echo        View ^> Script output should show  [FLStudioMCP] Ready
echo   3. Start the bridge daemon and keep it running:
echo        fl-studio-mcp-daemon
echo   4. Register with Claude Desktop  (%%APPDATA%%\Claude\claude_desktop_config.json):
echo        "fl-studio": { "command": "fl-studio-mcp", "env": { "FLSTUDIO_MCP_TRANSPORT": "tcp" } }
echo   5. Each session: open the Piano roll, and from its Scripting menu run "MCP_Apply"
echo        once (this arms note-writing). Then ask Claude to call fl_ping.
echo.
echo  Optional audio features:   pip install -e ".[audio]"      (tempo/key + melody)
echo                             pip install -e ".[audio,audio-accurate]"  (+ CREPE)
echo.
echo  Detected FL user data folder: %IMAGE_LINE%
echo  The daemon/server auto-detect it the same way; if you ever move it or have
echo  more than one, set FLSTUDIO_MCP_USER_DATA to the Image-Line folder to pin it.
echo.
endlocal
