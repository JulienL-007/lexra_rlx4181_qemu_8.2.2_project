#!/bin/sh
# build-qemu.sh - reproduce build/qemu-system-mips (the rtl8196e
# machine) from the repo form: pristine QEMU 8.2.2 + the fork patch.
#
#   1. fetch qemu-8.2.2.tar.xz from download.qemu.org if absent
#   2. extract it if neither qemu/ nor qemu-8.2.2/ exists
#   3. apply patches/001-rtl8196e-fork.patch if not yet applied
#      (the patch's paths are rooted at qemu-8.2.2/: it is applied
#      at -p1 before the tree takes its working name qemu/, or at
#      -p2 directly inside an existing qemu/)
#   4. configure build/ for mips-softmmu only and ninja the binary
#
# Safe to re-run: each step skips work already done.
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
QVER=8.2.2
PATCH_FILE="$HERE/patches/001-rtl8196e-fork.patch"

if [ ! -f "$HERE/qemu-$QVER.tar.xz" ]; then
  echo "Downloading pristine QEMU $QVER ..."
  curl -fsSL -o "$HERE/qemu-$QVER.tar.xz" \
    "https://download.qemu.org/qemu-$QVER.tar.xz"
fi
if [ ! -d "$HERE/qemu" ] && [ ! -d "$HERE/qemu-$QVER" ]; then
  echo "Extracting ..."
  tar --no-same-owner -C "$HERE" -xf "$HERE/qemu-$QVER.tar.xz"
fi
if [ -d "$HERE/qemu-$QVER" ]; then
  if patch -p1 -d "$HERE" --dry-run -R < "$PATCH_FILE" >/dev/null 2>&1; then
    echo "Fork patch already applied."
  else
    echo "Applying patches/001-rtl8196e-fork.patch ..."
    patch -p1 -d "$HERE" < "$PATCH_FILE"
  fi
  mv "$HERE/qemu-$QVER" "$HERE/qemu"
elif patch -p2 -d "$HERE/qemu" --dry-run -R < "$PATCH_FILE" >/dev/null 2>&1; then
  echo "Fork patch already applied."
else
  echo "Applying patches/001-rtl8196e-fork.patch ..."
  patch -p2 -d "$HERE/qemu" < "$PATCH_FILE"
fi
mkdir -p "$HERE/build"
if [ ! -f "$HERE/build/build.ninja" ]; then
  echo "Configuring (target: mips-softmmu) ..."
  (cd "$HERE/build" && "$HERE/qemu/configure" --target-list=mips-softmmu)
fi
echo "Building qemu-system-mips ..."
(cd "$HERE/build" && ninja qemu-system-mips)
ls -la "$HERE/build/qemu-system-mips"
