# LineageOS 18.1 (Android 11) — Huawei MediaPad M3 Lite 10 (`bach`)

[![GitHub all releases](https://img.shields.io/github/downloads/superheher/android_device_huawei_bach/total?label=downloads&logo=github&color=success)](https://github.com/superheher/android_device_huawei_bach/releases)

Unofficial **Android 11** port for `bach` (BAH-AL00 / L01 / L09 / W09), built on
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
| **Cameras (rear + front)** | live preview + **8 MP stills** + **1080p/30 video**, via the bundled **Open Camera** (needs the kernel fix + stats-blob patch + `/vendor` overlays below) |
| Wi-Fi / Bluetooth / sensors / touch | working |
| Audio | working. **Speaker:** a clean flash has the raw harsh-at-high-volume treble — the de-harsh fix is a separate rootless app (BachSpeakerEQ), **not yet bundled** in the ROM, so it must be installed and is wiped by a clean reflash. |

**Caveats**
- **SELinux is enforcing** since the `20260618` release (`androidboot.selinux=enforcing`). Earlier
  builds ran permissive as a bring-up shortcut. Two device allows carry the reused A10 vendor:
  `vndservicemanager → cameraserver` (binder) and the Huawei sensor HAL's oeminfo socket.
- The camera `/vendor` overlays are **bundled** since `20260618` — the release is a self-contained
  system + boot + vendor zip, clean-installable from a full wipe. No hand-application needed.
- TWRP note: the system partition mounts at **`/system_root/system`**, not `/system`.

## Build

1. Init + sync a LineageOS 18.1 tree, then add `.repo/local_manifests/bach.xml`:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <manifest>
     <remote name="superheher" fetch="https://github.com/superheher" />
     <project name="android_device_huawei_bach" path="device/huawei/bach" remote="superheher" revision="eleven" />
     <project name="android_kernel_huawei_bach" path="kernel/huawei/bach" remote="superheher" revision="eleven-cve" />
   </manifest>
   ```
   then `repo sync`.
2. `source build/envsetup.sh && breakfast bach && mka bacon`
   - Kernel ships **prebuilt** as `prebuilt/Image.gz-dtb` (the verified *v2fix* build) via
     `TARGET_PREBUILT_KERNEL`. To build from source instead, drop that line from `BoardConfig.mk`
     (source = the kernel repo above; `TARGET_KERNEL_CONFIG := bach_defconfig`).

   > **Known issue — the from-source system image does not boot.** Since June 2026 a build from
   > this tree hangs on the boot splash, in both permissive and enforcing variants. The boot
   > ramdisk is byte-identical to the last known-good build and the vendor is unchanged, so the
   > regression is in `system`; the cause is still unidentified and a full `m clobber` rebuild is
   > the next experiment. **Published releases are therefore hand-assembled** from the last
   > system image proven to boot — see `publish*/BUILD_PROVENANCE.md`. A consequence worth
   > knowing: `system.prop` cannot reach a released device, so its properties are routed through
   > `/vendor/build.prop` instead (both files deliver every namespace; `/vendor` wins duplicates).
3. Flash the release zip in TWRP — it is self-contained (system + boot + vendor) and installs
   over an existing build keeping `/data`, or from a full wipe. The camera `/vendor` overlays and
   the stats-blob patch are already inside it; **[docs/CAMERA.md](docs/CAMERA.md)** documents what
   they are and why.

## Camera (the hard part)

**App vs. stack:** the fixes here are at the camera **stack** level (kernel + HAL/daemon), so any
app benefits. But the stock LineageOS camera app is too strict for this old HAL — it won't even
preview — so **[Open Camera](https://opencamera.org.uk/) (FOSS) is bundled as the camera app** and
replaces the stock one (via `LOCAL_OVERRIDES_PACKAGES`), so it's the sole, default camera.

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
