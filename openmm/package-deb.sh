#!/usr/bin/env bash
# Package OpenMM 8.5.0 riscv64 build as Debian package(s).
# Two packages: libopenmm (runtime libs), libopenmm-dev (headers).

set -euo pipefail
WORK=~/riscv-hpc-port/openmm-port
BUILD="$WORK/build-riscv64"
SRC="$WORK/openmm"
INSTALL="$WORK/install-riscv64"
DIST="$WORK/dist"
VER=8.5.0
REV=1
ARCH=riscv64

mkdir -p "$DIST"

# 1. Install into staging dir
echo "=== Installing into $INSTALL ==="
rm -rf "$INSTALL"
DESTDIR="$INSTALL" ninja -C "$BUILD" install

# Confirm what got installed
echo "=== install tree (first 40 entries) ==="
find "$INSTALL" -type f | head -40
echo "..."
echo "total files: $(find "$INSTALL" -type f | wc -l)"

# 2. Build the runtime package (libs + plugins)
RUNTIME_PKG="$DIST/openmm-build/runtime"
rm -rf "$RUNTIME_PKG"
mkdir -p "$RUNTIME_PKG/DEBIAN" "$RUNTIME_PKG/usr/lib/riscv64-linux-gnu/openmm/plugins"

# Find install prefix from cmake (default $WORK/install-riscv64/usr/local)
PREFIX_DIR="$INSTALL/usr/local"
if [[ ! -d "$PREFIX_DIR" ]]; then
    # fallback to whatever ninja install used
    PREFIX_DIR=$(find "$INSTALL" -name "lib" -type d | head -1 | xargs dirname)
fi

# Copy *.so files to /usr/lib/riscv64-linux-gnu/
find "$PREFIX_DIR/lib" -maxdepth 1 -name "*.so*" -type f \
    -exec cp -av {} "$RUNTIME_PKG/usr/lib/riscv64-linux-gnu/" \;

# Copy plugins
if [[ -d "$PREFIX_DIR/lib/plugins" ]]; then
    cp -av "$PREFIX_DIR/lib/plugins/"* \
        "$RUNTIME_PKG/usr/lib/riscv64-linux-gnu/openmm/plugins/" 2>/dev/null || true
fi

# Control file
INSTALLED_SIZE=$(du -ks "$RUNTIME_PKG/usr" | cut -f1)
cat > "$RUNTIME_PKG/DEBIAN/control" << CTRL
Package: libopenmm
Version: $VER-$REV
Section: science
Priority: optional
Architecture: $ARCH
Maintainer: trg-rgb <tanmaygulhane12@gmail.com>
Installed-Size: $INSTALLED_SIZE
Depends: libc6 (>= 2.34), libstdc++6 (>= 13), libgcc-s1 (>= 4.0)
Description: OpenMM molecular dynamics library — riscv64 build
 OpenMM 8.5.0 cross-compiled for riscv64 from upstream commit f99249f.
 CPU and Reference platforms only (no GPU). Built with GCC 15.2.0,
 -march=rv64gcv -mabi=lp64d. The CPU platform's portable Fvec path
 auto-vectorizes to RVV 1.0 under -O3.
CTRL

dpkg-deb --build --root-owner-group "$RUNTIME_PKG" \
    "$DIST/libopenmm_${VER}-${REV}_${ARCH}.deb"

# 3. Build the dev package (headers + .so symlinks)
DEV_PKG="$DIST/openmm-build/dev"
rm -rf "$DEV_PKG"
mkdir -p "$DEV_PKG/DEBIAN" "$DEV_PKG/usr/include" "$DEV_PKG/usr/lib/riscv64-linux-gnu"

cp -av "$PREFIX_DIR/include/"* "$DEV_PKG/usr/include/" 2>/dev/null || true

# .so symlinks (not the SONAME files themselves)
find "$PREFIX_DIR/lib" -maxdepth 1 -name "*.so" -type l \
    -exec cp -av {} "$DEV_PKG/usr/lib/riscv64-linux-gnu/" \; 2>/dev/null || true

INSTALLED_SIZE_DEV=$(du -ks "$DEV_PKG/usr" | cut -f1)
cat > "$DEV_PKG/DEBIAN/control" << CTRL
Package: libopenmm-dev
Version: $VER-$REV
Section: libdevel
Priority: optional
Architecture: $ARCH
Maintainer: trg-rgb <tanmaygulhane12@gmail.com>
Installed-Size: $INSTALLED_SIZE_DEV
Depends: libopenmm (= $VER-$REV)
Description: OpenMM molecular dynamics library — riscv64 headers
 Headers and .so symlinks for developing against OpenMM 8.5.0 on riscv64.
CTRL

dpkg-deb --build --root-owner-group "$DEV_PKG" \
    "$DIST/libopenmm-dev_${VER}-${REV}_${ARCH}.deb"

# 4. Verify & hash
echo
echo "=== .deb files produced ==="
ls -la "$DIST"/*.deb
echo
echo "=== dpkg-deb --info for runtime package ==="
dpkg-deb --info "$DIST/libopenmm_${VER}-${REV}_${ARCH}.deb"
echo
echo "=== SHA256 ==="
sha256sum "$DIST"/*.deb
