#!/system/bin/sh
# bach LOS18.1 — apply the camera-daemon AEC use-after-free fix to /vendor IN PLACE.
# This ROM is system+boot only: /vendor is the existing LOS17.1 vendor (not rebuilt),
# so patch it on the device. Run as root:
#   adb push patch-blobs.sh /data/local/tmp/ && adb root && \
#   adb shell 'sh /data/local/tmp/patch-blobs.sh' && adb reboot
# Fix: /vendor/lib/libmmcamera2_stats_modules.so @ 0x3f658
#   a8 6b (ldr r0,[r5,#0x38], r5 = dangling AEC port) -> 00 20 (movs r0,#0)
B=/vendor/lib/libmmcamera2_stats_modules.so
mount -o rw,remount /vendor 2>/dev/null
cur=$(dd if=$B bs=1 skip=$((0x3f658)) count=2 2>/dev/null | od -An -tx1 | tr -d ' \n')
case "$cur" in
  a86b) printf '\x00\x20' | dd of=$B bs=1 seek=$((0x3f658)) count=2 conv=notrunc 2>/dev/null
        echo "patched OK — reboot to apply" ;;
  0020) echo "already patched" ;;
  *)    echo "unexpected bytes '$cur' at 0x3f658 — blob mismatch, not patching"; exit 1 ;;
esac
