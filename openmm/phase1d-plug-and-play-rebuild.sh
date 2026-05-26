#!/usr/bin/env bash
# phase1d-plug-and-play-rebuild.sh
#
# Rebuilds OpenMM .debs so dpkg-i + ldconfig is enough — no env var needed.
# Adds a 4th hunk to the upstream patch (Platform.cpp) so the runtime
# default plugin directory is configurable at build time via the new
# OPENMM_DEFAULT_PLUGIN_DIR CMake option. Then reconfigures with
# CMAKE_INSTALL_PREFIX=/usr (clean staging) and the new option pointed
# at the Debian multiarch plugins path.

set -euo pipefail

WORK="${WORK:-$HOME/riscv-hpc-port/openmm-port}"
SRC="$WORK/openmm"
BUILD="$WORK/build-riscv64"
INSTALL="$WORK/install-riscv64"
DIST="$WORK/dist"
LOGS="$WORK/logs"
JOBS="${JOBS:-6}"

log() { printf '\n=== %s ===\n' "$*"; }

# ---------- 1. Apply the new 4th hunk (Platform.cpp) ----------
log "Patching Platform.cpp for runtime-configurable plugin path"
PLATFORM=$SRC/olla/src/Platform.cpp
if grep -q OPENMM_DEFAULT_PLUGIN_DIR "$PLATFORM"; then
    echo "  Platform.cpp already patched — skipping"
else
    python3 - <<'PY'
import re
p = '/root/placeholder'   # replaced below
PY
    # In-place sed with a multi-line replacement is fragile. Use python for safety.
    python3 - "$PLATFORM" <<'PY'
import sys, re
path = sys.argv[1]
with open(path) as f:
    src = f.read()
old = '''    if (dir == NULL)
        directory = "/usr/local/openmm/lib/plugins";
    else'''
new = '''    if (dir == NULL)
#ifdef OPENMM_DEFAULT_PLUGIN_DIR
        directory = OPENMM_DEFAULT_PLUGIN_DIR;
#else
        directory = "/usr/local/openmm/lib/plugins";
#endif
    else'''
if old not in src:
    print("ERROR: expected old text not found in Platform.cpp; aborting", file=sys.stderr)
    sys.exit(1)
with open(path, 'w') as f:
    f.write(src.replace(old, new, 1))
print("  patched OK")
PY
fi

# ---------- 2. Extend the CMakeLists patch (3 extra lines) ----------
log "Adding OPENMM_DEFAULT_PLUGIN_DIR option to top-level CMakeLists.txt"
CML=$SRC/CMakeLists.txt
if grep -q "OPENMM_DEFAULT_PLUGIN_DIR" "$CML"; then
    echo "  CMakeLists.txt already patched — skipping"
else
    python3 - "$CML" <<'PY'
import sys
path = sys.argv[1]
with open(path) as f:
    src = f.read()
old = '''if ("${TARGET_ARCH}" MATCHES "riscv64")
    set(RISCV64 ON)
    add_definitions(-D__RISCV64__=1)
endif()'''
new = '''if ("${TARGET_ARCH}" MATCHES "riscv64")
    set(RISCV64 ON)
    add_definitions(-D__RISCV64__=1)
endif()

# Optional override of the runtime default plugin directory baked into
# libOpenMM. Useful for cross-builds where the install destination
# differs from the runtime location (e.g. Debian .deb to a multiarch path).
if(OPENMM_DEFAULT_PLUGIN_DIR)
    add_definitions(-DOPENMM_DEFAULT_PLUGIN_DIR="${OPENMM_DEFAULT_PLUGIN_DIR}")
endif()'''
if old not in src:
    print("ERROR: expected old text not found in CMakeLists.txt; aborting", file=sys.stderr)
    sys.exit(1)
with open(path, 'w') as f:
    f.write(src.replace(old, new, 1))
print("  patched OK")
PY
fi

# ---------- 3. Reconfigure with /usr prefix + new plugin path ----------
log "Reconfiguring cmake with CMAKE_INSTALL_PREFIX=/usr + plugin path override"
cd "$BUILD"
cmake "$SRC" \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DOPENMM_DEFAULT_PLUGIN_DIR=/usr/lib/riscv64-linux-gnu/openmm/plugins \
    2>&1 | tee "$LOGS/phase1d-reconfigure.log" | tail -20

# ---------- 4. Incremental rebuild (only Platform.cpp.o and its dependents) ----------
log "Incremental rebuild (ninja -j$JOBS)"
ninja -j"$JOBS" 2>&1 | tee "$LOGS/phase1d-rebuild.log" | tail -10

# ---------- 5. Reinstall to fresh DESTDIR ----------
log "Reinstalling to fresh $INSTALL with DESTDIR"
rm -rf "$INSTALL"
DESTDIR="$INSTALL" ninja install 2>&1 | tail -10

# Verify the tree looks right
log "Sanity-check install tree"
ls -la "$INSTALL/usr/" 2>/dev/null
ls -la "$INSTALL/usr/lib/" 2>/dev/null | head -15
ls -la "$INSTALL/usr/lib/plugins/" 2>/dev/null | head -10

# Verify the baked plugin path is now /usr/lib/riscv64-linux-gnu/openmm/plugins
log "Verifying baked plugin path inside libOpenMM.so"
strings "$INSTALL/usr/lib/libOpenMM.so" | grep -E "lib/.*plugin|local/openmm" | head -5 || echo "  (no match — investigate)"

# ---------- 6. Repackage ----------
log "Repackaging (removing old .debs first)"
rm -f "$DIST"/*.deb
"$WORK/package-deb.sh" 2>&1 | tee "$LOGS/phase1d-package.log" | tail -30

# ---------- 7. Diff against old SHA256s ----------
log "New SHA256 fingerprints"
sha256sum "$DIST"/*.deb

log "Done. Update the issue with new SHA256s. Old hashes were:"
echo "  c3df1f1da5a7c59d1b47ba4766e06dbc34f2316c65e2165ee1e62ecbd1750a71  libopenmm_8.5.0-1_riscv64.deb"
echo "  28d2a2c2a034f1fc828a26f806b3cd4da5b4f85efff50a964977f28702d795e2  libopenmm-dev_8.5.0-1_riscv64.deb"
