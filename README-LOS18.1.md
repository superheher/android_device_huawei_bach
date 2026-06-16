# LineageOS 18.1 (Android 11) — Huawei MediaPad M3 Lite 10 (bach)

World-first A11 port for **bach**, built on surdu_petru's LineageOS 17.1
([Huawei-Dev](https://github.com/Huawei-Dev), `ten` branch). This is the **`eleven`** branch.

## Repositories
| | repo | branch |
|---|---|---|
| device | `superheher/android_device_huawei_bach` | `eleven` |
| kernel | `superheher/android_kernel_huawei_bach`  | `eleven` |

## Build
1. Init + sync a LineageOS 18.1 tree. Add `.repo/local_manifests/bach.xml`:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <manifest>
     <remote name="superheher" fetch="https://github.com/superheher" />
     <project name="android_device_huawei_bach" path="device/huawei/bach" remote="superheher" revision="eleven" />
     <project name="android_kernel_huawei_bach" path="kernel/huawei/bach" remote="superheher" revision="eleven" />
   </manifest>
   ```
   then `repo sync`.
2. **Proprietary blobs** are not redistributed here. Extract the A10 blobs from a device
   running surdu_petru's LOS17.1 (they are reused on A11): run `device/huawei/bach/extract-files.sh`
   against the connected device (or copy from his vendor tree).
3. **Camera fix (required for video + reliable capture):** after blobs are in place, run
   `./device/huawei/bach/patch-blobs.sh` — a 2-byte patch to `libmmcamera2_stats_modules.so`
   that neutralizes an AEC use-after-free which otherwise crashes the camera daemon in video mode.
4. *(Optional)* capture-reliability shim:
   `cd frameworks/av && git apply $ANDROID_BUILD_TOP/device/huawei/bach/patches/frameworks_av-bach-jpeg-shim.patch`
   — catches an intermittent BLOB-buffer error flag. Not required (the kernel fix already makes capture work).
5. `source build/envsetup.sh && breakfast bach && mka bacon`

The kernel ships **prebuilt** (`prebuilt/Image.gz-dtb`, the fixed v2fix build) via `TARGET_PREBUILT_KERNEL`;
to build it from source instead, remove that line from `BoardConfig.mk` (source is the kernel repo above).

## Camera (A11) — working
Both cameras: live preview + 8MP stills + **1080p/30fps video**. The video/capture fixes are the
kernel `req_frm_ver2` parse (in the kernel repo) + the stats-blob AEC-UAF patch (`patch-blobs.sh`).

## Credits
**surdu_petru** / Huawei-Dev — original bach bring-up (LOS 14–17.1). This A11 port extends that work.
