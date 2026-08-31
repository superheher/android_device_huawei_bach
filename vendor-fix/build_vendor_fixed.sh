#!/bin/bash
# Rebuild the bach vendor image with the two hw-video-decode fixes. debugfs only:
# no root, no loop-mount, no sudo. Full diagnosis in README.md.
#
#   ./build_vendor_fixed.sh <pristine-vendor.img> <out.img> [media_codecs.xml]
#
# 1  vendor.vidc.disable.split.mode=1 -> /build.prop (venus rejects split mode's
#    UBWC DPB, HFI SESSION_ERROR 4103 => ALL hw decode dies)
# 2  /etc/media_codecs.xml limits corrected to the real 1920x1088 / 244800 / 20 Mbps
#    (shipped entries claimed 4096x2160 / 1958400 / 240fps, from a bigger SoC)
set -e
SRC="${1:?pristine vendor.img}"; OUT="${2:?output img}"
HERE=$(cd "$(dirname "$0")" && pwd)
XML="${3:-$HERE/media_codecs.xml}"
[ -f "$XML" ] || { echo "missing $XML"; exit 1; }
cp -f "$SRC" "$OUT"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
# SELinux values are stored NUL-terminated by Android's ext4 writer; match that.
printf 'u:object_r:vendor_configs_file:s0\0' > "$TMP/ctx_cfg"
printf 'u:object_r:vendor_file:s0\0'        > "$TMP/ctx_file"

# --- Fix 1: build.prop ---
debugfs -R "dump /build.prop $TMP/build.prop" "$OUT" 2>/dev/null
if ! grep -q '^vendor.vidc.disable.split.mode=' "$TMP/build.prop"; then
  cat >> "$TMP/build.prop" <<'EOP'

# bach: msm8937 venus rejects the UBWC DPB used by OPB/DPB split mode
# (HFI SESSION_ERROR 4103 "Unsupported bitstream") -> all hw video decode fails.
vendor.vidc.disable.split.mode=1
EOP
fi
debugfs -w -R "rm /build.prop" "$OUT" >/dev/null 2>&1
debugfs -w -R "write $TMP/build.prop build.prop" "$OUT" >/dev/null 2>&1
debugfs -w -R "ea_set -f $TMP/ctx_file /build.prop security.selinux" "$OUT" >/dev/null 2>&1

# --- Fix 2: media_codecs.xml ---
debugfs -w -R "rm /etc/media_codecs.xml" "$OUT" >/dev/null 2>&1
debugfs -w -R "write $XML etc/media_codecs.xml" "$OUT" >/dev/null 2>&1
debugfs -w -R "ea_set -f $TMP/ctx_cfg /etc/media_codecs.xml security.selinux" "$OUT" >/dev/null 2>&1

echo "=== verify ==="
debugfs -R "dump /build.prop $TMP/v1" "$OUT" 2>/dev/null; tail -1 "$TMP/v1"
debugfs -R "dump /etc/media_codecs.xml $TMP/v2" "$OUT" 2>/dev/null
grep -c '1920x1088' "$TMP/v2" | sed 's/^/1920x1088 occurrences: /'
debugfs -R "ea_get /build.prop security.selinux" "$OUT" 2>/dev/null | grep security
debugfs -R "ea_get /etc/media_codecs.xml security.selinux" "$OUT" 2>/dev/null | grep security
e2fsck -fn "$OUT" 2>&1 | tail -2
echo "OK -> $OUT"
