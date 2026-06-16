#!/bin/bash
# bach LOS18.1 — patch the AEC use-after-free in the proprietary mm-camera stats
# blob (fixes the daemon SIGSEGV that breaks video recording + freezes preview).
# Run AFTER extract-files.sh. The 2 bytes we own (our diff), not Qualcomm's code.
# 0x3f658: ldr r0,[r5,#0x38] (a8 6b) -> movs r0,#0 (00 20)  [r5 = dangling AEC port]
set -e
TOP="${ANDROID_BUILD_TOP:-$(cd "$(dirname "$0")/../../.." && pwd)}"
BLOB=$(find "$TOP/vendor/huawei/bach" -name libmmcamera2_stats_modules.so 2>/dev/null | head -1)
[ -z "$BLOB" ] && { echo "!! stats blob not found — run extract-files.sh first"; exit 1; }
cur=$(dd if="$BLOB" bs=1 skip=$((16#3f658)) count=2 2>/dev/null | od -An -tx1 | tr -d ' \n')
case "$cur" in
  a86b) printf '\x00\x20' | dd of="$BLOB" bs=1 seek=$((16#3f658)) count=2 conv=notrunc 2>/dev/null
        echo "OK: patched AEC UAF in $BLOB" ;;
  0020) echo "OK: already patched" ;;
  *)    echo "!! unexpected bytes '$cur' at 0x3f658 — blob mismatch, not patching"; exit 1 ;;
esac
