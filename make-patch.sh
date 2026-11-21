#!/bin/sh
# make-patch.sh - the patch <-> state proof for the QEMU fork.
#
# The repo form of the emulator is: pristine QEMU 8.2.2 (fetched
# from download.qemu.org) + patches/001-rtl8196e-fork.patch (the
# rtl8196e machine, the Lexra RLX4181 CPU support and the LOPI
# interrupt lines). The working form is the qemu/ tree. This script
# proves the two forms are the same thing, and can regenerate the
# patch from the tree.
#
#   make-patch.sh          check: apply the patch to a fresh
#                          pristine extract and diff it against
#                          qemu/ - exit 0 iff identical (build
#                          noise excluded: __pycache__, build/,
#                          *.pyc, subprojects/.wraplock, the
#                          qemu-iotests scratch/ output dir).
#   make-patch.sh regen    rewrite patches/001-rtl8196e-fork.patch
#                          from pristine -> qemu/.
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
QVER=8.2.2
SRC="$HERE/qemu"
PATCH_FILE="$HERE/patches/001-rtl8196e-fork.patch"
TARBALL=""

for cand in "$HERE/qemu-$QVER.tar.xz" "/tmp/qemu-$QVER.tar.xz"; do
  if [ -f "$cand" ]; then TARBALL="$cand"; break; fi
done
if [ -z "$TARBALL" ]; then
  TARBALL="$HERE/qemu-$QVER.tar.xz"
  echo "Downloading pristine QEMU $QVER ..."
  curl -fsSL -o "$TARBALL" "https://download.qemu.org/qemu-$QVER.tar.xz"
fi
if [ ! -d "$SRC" ]; then
  echo "ERROR: $SRC not found - run build-qemu.sh first" >&2
  exit 1
fi

EXCLUDES="-x __pycache__ -x build -x *.pyc -x .wraplock -x scratch -x .git"

WORK="$HERE/.make-patch-work"
rm -rf "$WORK"
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT

echo "Extracting pristine QEMU $QVER ..."
tar --no-same-owner -C "$WORK" -xf "$TARBALL"
PRISTINE="$WORK/qemu-$QVER"

MODE="${1:-check}"
case "$MODE" in
check)
  echo "Applying patches/001-rtl8196e-fork.patch ..."
  patch -p1 -d "$WORK" < "$PATCH_FILE" >/dev/null
  echo "Diffing patched pristine vs $SRC ..."
  # diff exit codes: 0 = identical, 1 = differences, 2 = trouble
  # (e.g. the stock tree's dangling X11IncludeHack symlink, present
  # identically on both sides). Content decides: a non-empty
  # diff.out is a difference; an empty one is a match.
  rc=0
  # shellcheck disable=SC2086
  diff -r --no-dereference $EXCLUDES "$PRISTINE" "$SRC" > "$WORK/diff.out" 2> "$WORK/diff.err" || rc=$?
  if [ -s "$WORK/diff.out" ]; then
    echo "DIFFERENCES FOUND:" >&2
    head -50 "$WORK/diff.out" >&2
    trap - EXIT
    cp "$WORK/diff.out" "$HERE/make-patch-diff.txt"
    echo "Full diff saved to make-patch-diff.txt" >&2
    exit 1
  elif [ "$rc" -le 1 ]; then
    echo "PATCH = STATE: the shipped patch reproduces the fork tree exactly."
  else
    echo "diff reported trouble with no content differences:" >&2
    cat "$WORK/diff.err" >&2
    exit 1
  fi
  ;;
regen)
  echo "Generating combined patch -> $PATCH_FILE ..."
  # shellcheck disable=SC2086
  diff -ruN --no-dereference $EXCLUDES "$PRISTINE" "$SRC" 2>/dev/null \
    | sed -e "s|^--- $PRISTINE|--- a/qemu-$QVER|" \
          -e "s|^+++ $SRC|+++ b/qemu-$QVER|" \
          -e "s|^diff -ruN .* $PRISTINE/\(.*\) $SRC/.*|diff -ruN a/qemu-$QVER/\1 b/qemu-$QVER/\1|" \
    > "$PATCH_FILE" || true
  echo "Wrote $PATCH_FILE ($(wc -l < "$PATCH_FILE") lines)."
  ;;
*)
  echo "usage: $0 [check|regen]" >&2
  exit 2
  ;;
esac
