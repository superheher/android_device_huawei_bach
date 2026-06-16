# LineageOS 18.1 (Android 11) — Huawei MediaPad M3 Lite 10 (`bach`)

World-first **Android 11** port for `bach` (BAH-AL00 / L01 / L09 / W09), built on
**surdu_petru**'s LineageOS 17.1 ([Huawei-Dev](https://github.com/Huawei-Dev)). Branch: **`eleven`**.

> **Developer-stage port.** Boots and runs as a daily driver; all three camera functions work
> after a small set of `/vendor` overlays — read **How it installs** and
> **[docs/CAMERA.md](docs/CAMERA.md)** before flashing.

| Spec | |
|---:|:---|
| SoC | Qualcomm MSM8937, Snapdragon 435 (octa-core A53) / Adreno 505 |
| Display | 10.1″ IPS, 1200×1920 (16:10) |
| RAM/Storage | 3/4 GB · 32/64 GB + microSD |
| Cameras | 8 MP rear (AF, 1080p30) · 8 MP front |
| Battery | 6660 mAh |

## How it installs — **system + boot only**

This tree builds **`system` + `boot` only**. It deliberately **keeps the device's existing
LineageOS 17.1 `/vendor`** (A10 blobs, VNDK-29) and 3.18-kernel userspace **untouched**, so it is
flashed **over an existing LOS 17.1 install** (surdu_petru's) — not standalone. There is **no
vendor image and no blob extraction** here: the A10 vendor is reused, with a few A11-compat
overlays (see camera notes). Hence `BoardConfig.mk` keeps `PRODUCT_EXTRA_VNDK_VERSIONS := 29` and
the kernel ships prebuilt.

## Status

| Area | State |
|---|---|
| Boot / system / UI | stable daily driver |
| **Cameras (rear + front)** | live preview + **8 MP stills** + **1080p/30 video** — needs the kernel fix + the stats-blob patch + the `/vendor` overlays below |
| Wi-Fi / Bluetooth / sensors / touch | working |
| Audio | working, but speaker is **harsh at high volume** (uncalibrated TI TAS2560 smart-amps on a generic config) |

**Caveats**
- **SELinux is permissive** (`androidboot.selinux=permissive` in the kernel cmdline) — a bring-up
  shortcut; enforcing is a TODO.
- The camera `/vendor` overlays are applied by hand on the device for now; packaging them as a
  flashable vendor-overlay is a TODO.
- TWRP note: the system partition mounts at **`/system_root/system`**, not `/system`.

## Build

1. Init + sync a LineageOS 18.1 tree, then add `.repo/local_manifests/bach.xml`:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <manifest>
     <remote name="superheher" fetch="https://github.com/superheher" />
     <project name="android_device_huawei_bach" path="device/huawei/bach" remote="superheher" revision="eleven" />
     <project name="android_kernel_huawei_bach" path="kernel/huawei/bach" remote="superheher" revision="eleven" />
   </manifest>
   ```
   then `repo sync`.
2. `source build/envsetup.sh && breakfast bach && mka bacon`
   - Kernel ships **prebuilt** as `prebuilt/Image.gz-dtb` (the verified *v2fix* build) via
     `TARGET_PREBUILT_KERNEL`. To build from source instead, drop that line from `BoardConfig.mk`
     (source = the kernel repo above; `TARGET_KERNEL_CONFIG := bach_defconfig`).
3. Flash `system` + `boot` over an existing LOS 17.1 install, then apply the camera `/vendor`
   overlays + the stats-blob patch — see **[docs/CAMERA.md](docs/CAMERA.md)**.

## Camera — world-first on A11 (the hard part)

The closed **A8.1/A10** camera stack runs under A11 strict-Treble (on the reused A10 `/vendor`)
via a chain of `/vendor` overlays plus two original fixes. Full write-up, exact files and
root-cause in **[docs/CAMERA.md](docs/CAMERA.md)**. In short:

- **A11-compat `/vendor` overlays**: a minimal **stub `libandroid.so`**, VNDK-29 camera HIDL libs
  copied into `/vendor/lib`, the A10 `vendor.qti.hardware.camera.device@1.0.so`, VNDK-29 `libgui` /
  kept `libcrypto`.
- **Kernel fix** `isp: req_frm_ver2` (kernel repo) — fixes still-capture (was green/empty:
  "Invalid bufq").
- **Stats-blob 2-byte patch** (`patch-blobs.sh`) — neutralizes an **AEC use-after-free** that
  SIGSEGV-crashed the camera daemon in video mode (froze preview, broke recording). Enables
  1080p video + reliable preview.
- *(Optional)* `patches/frameworks_av-bach-jpeg-shim.patch` — capture-reliability shim; not
  required once the kernel fix is in.

## Credits

**surdu_petru** / [Huawei-Dev](https://github.com/Huawei-Dev) — original `bach` bring-up
(LOS 14 → 17.1). This Android 11 port stands on that work.
