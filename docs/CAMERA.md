# Camera bring-up — `bach` on LineageOS 18.1 (Android 11)

Both cameras do **live preview + 8 MP stills + 1080p/30 video**. The hard part: the device runs
the **closed A8.1/A10 camera stack under Android 11** (the ROM is system+boot only and keeps the
existing LOS 17.1 `/vendor`, VNDK-29). A11 strict-Treble linker namespaces break that stack, so it
needs the overlays below **plus two original fixes**. Everything here is applied to the existing
A10 `/vendor` as root (`mount -o rw,remount /vendor`); none of it rebuilds vendor.

> Packaging these overlays into a flashable vendor add-on is a TODO — today they are applied by
> hand. Back up each replaced file (`*.real` / `*.bak`) before overwriting.

## 1. `/vendor` overlays — make the A10 stack load under A11

- **stub `/vendor/lib/libandroid.so`** — the closed `libmmcamera2_stats_modules.so` imports NDK
  Sensor/Looper APIs; the real `libandroid` drags in ~84 libs (impossible in the vendor namespace).
  A hand-built stub exports only the ~16 symbols the stats module uses (`ASensorManager_*`,
  `ASensor_*`, `ASensorEventQueue_*`, `ALooper_*`). It **must** return a non-NULL sensor manager +
  a valid opaque default-sensor + a valid opaque event-queue (NULL manager → ISP never streams;
  NULL sensor/queue → it leaks one metadata buffer per frame → 3A stalls after ~20 frames). Keep
  the original as `libandroid.so.real`.
- **VNDK-29 camera HIDL libs copied into `/vendor/lib`** — the camera provider loads in
  cameraserver's `sphal` namespace, which only reaches VNDK-SP, not VNDK-core. Copy from the
  VNDK-29 apex: `android.hardware.camera.device@{1.0,3.2,3.3,3.4,3.5}.so`, `camera.provider@2.4.so`,
  `graphics.allocator@{2.0,3.0}.so`, `libcamera_metadata.so`, `libexif.so`, `libfmq.so`,
  `libjpeg.so`, `libyuv.so`, `libbinder.so` **and `libbinderthreadstate.so` together** (a `/vendor`
  libbinder can't resolve libbinderthreadstate via the namespace link).
- **A10 `vendor.qti.hardware.camera.device@1.0.so`** — pull from the LOS 17.1 OTA; the A11 build
  needs an A11-only `libhidlbase` symbol absent from VNDK-29, the A10 one resolves cleanly.
- **VNDK-29 `libgui.so`** (the on-device one was the *system* variant referencing a symbol absent
  from VNDK libbinder) and keep **`libcrypto.so`** in `/vendor/lib` (OMX JPEG encoder dlopen).

After these: `qcamerasvr` runs, the provider loads, `dumpsys media.camera` = 2 devices, both
stream live preview.

## 2. Kernel fix — still-capture (in the kernel repo; shipped in `boot`)

`drivers/media/platform/msm/camera_v2/isp/msm_isp_axi_util.c`. The A11 daemon sends
`UPDATE_STREAM_REQUEST_FRAMES_VER2` filling the **union member `req_frm_ver2`**
`{stream_handle, user_stream_id, frame_id, buf_index}`, but the stock 3.18 handler read it as
`update_info[]` `{stream_handle, output_format, user_stream_id, frame_id}` — only `stream_handle`
aligns, so the fields scrambled: `frame_id` got `buf_index` (tiny → treated as a *stale* frame →
empty buffer) and `user_stream_id` got the real `frame_id` (→ selected the unregistered SHARED
bufq → "Invalid bufq"). Result: green/empty snapshots. **Fix:** parse `req_frm_ver2` for the VER2
case and pass the correct `user_stream_id` + `frame_id`. Commit: `isp: parse req_frm_ver2 …`.

## 3. Stats-blob patch — video recording + reliable preview (`patch-blobs.sh`)

The closed `libmmcamera2_stats_modules.so` (in the camera **daemon** `mm-qcamera-daemon`) sends an
AEC update on every SOF by walking a port list. In **video mode** a dangling port (use-after-free)
makes it **SIGSEGV a few frames into preview** — `aec_port_send_aec_update` → `aec_port_send_event`
— which freezes preview on the last frame and puts the camera2 session into permanent ERROR, so
recording never starts. Both crash paths (preview thread `CAM_MctBus`, recording thread
`CAM_AECAWB`) fault at the **same instruction**:

```
0x3f658:  6ba8   ldr r0, [r5, #0x38]      ; r5 = dangling AEC port  → SEGV at r5+0x38
```

The loaded value is only sign-extended, ÷256, and stored to a telemetry global (the function is an
AF/AEC diagnostic snapshot, not a control path), so we can safely **skip the dereference**:

```
patch  file-offset 0x3f658:  a8 6b  →  00 20   (movs r0, #0)
```

`patch-blobs.sh` applies exactly this to the on-device `/vendor` blob (it verifies the original
bytes first). Verified: preview no longer crashes, **5/5 clean 1080p/30 recordings**, exposure
correct, autofocus intact (the zeroed field really is dead telemetry), survives reboot. This is
HAL-independent — it works with the stock A10 `camera.msm8937.so` (no from-source HAL needed).

## 4. Optional `libcameraservice` JPEG shim (`patches/frameworks_av-bach-jpeg-shim.patch`)

Belt-and-braces for capture: in `Camera3OutputUtils.returnOutputBuffers`, if a BLOB (JPEG) stream
buffer comes back `STATUS_ERROR` with a valid gralloc buffer + listener, flip it to `STATUS_OK` and
deliver it — the A10 HAL intermittently mis-flags the (now-valid, thanks to the kernel fix) buffer.
Gated by `persist.bach.jpeg.shim` (default on). **Not required** once the kernel fix is in; it only
removes a rare "capture error on unknown request" hiccup.

## Debug notes

- USER builds compile out `ALOGV`, so `Camera3-Device`/`-OutputStream` verbose logs never appear;
  the daemon's own `<HAL>`/`mm-camera` INFO logs do. Kernel ISP messages: `logcat -b kernel`
  (`/dev/kmsg` is drained by logd; `dmesg`/dynamic-debug unavailable on this kernel).
- Repeated `ctl.restart cameraserver` or HAL swaps wedge the VFE40 ISP (reset timeout) — **reboot**
  to recover and before measuring preview smoothness.
- `persist.camera.hal.debug=4` slows the pipeline enough to break the shutter — keep camera debug
  **off** for functional capture tests.
