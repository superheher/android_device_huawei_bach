# The 141 lost properties

Audit trail for the `vendor_prop.mk` trap. Started after the BAH-L09 "no modem / no SIM"
report against `lineage_bach-userdebug 11 eng.root.20260617.204056` turned out to be one
of its casualties.

**Ledger: 141 declared · 59 now emitted · 82 deliberately not, each with a stated reason.**

---

## 1. What happened

`vendor_prop.mk` declares 141 properties and reaches a device through no route at all:

1. no makefile in this tree inherits it (zero call sites), and
2. even if one did, `PRODUCT_PROPERTY_OVERRIDES` lands in `/vendor/build.prop`, and this
   port ships a **prebuilt A10 vendor image** that overwrites that file wholesale.

On surdu's LOS 17.1 the same 141 lines were live: Android 10 routed
`PRODUCT_PROPERTY_OVERRIDES` into `ADDITIONAL_BUILD_PROPERTIES` → `/system/build.prop`.
Flashing the A11 system replaces that file, and the A11 build never re-emits any of them.

All 141 were verified present in a live `getprop` from a BAH-L09 running surdu's 17.1
(`Downloads/huawei/bach-live-dump/getprop_full.txt`), and absent from both

- `/vendor/build.prop` inside the shipping `vendor-20260830-fixed.img` (43 lines: surdu's
  original, plus the one `vendor.vidc.disable.split.mode=1` added by
  `vendor-fix/build_vendor_fixed.sh`), and
- `/system/build.prop` inside the shipping `system.img`.

### Why the modem report was the one that surfaced

`rild.libpath` is **not** a `persist.` property. The split matters:

| kind | behaviour |
|---|---|
| non-`persist.` | gone the moment they leave `build.prop`. Every flash, every boot. Deterministic. |
| `persist.` | gone too, in most cases. `PropertySet()` writes a `persist.` prop into `/data/property/persistent_properties` only when `persistent_properties_loaded == true`, and that is false during `PropertyLoadBootDefaults()`. So a prop that lived *only* in `build.prop` was never persisted to `/data`, and disappears with it. It survives an in-place 17.1 → 18.1 upgrade only if something wrote it at runtime — a HAL, the framework, a Settings toggle. Per prop, per device. |

Which is why user reports disagree, while `rild.libpath` failed for everyone identically.
To see what a given device still carries from 17.1:

```bash
adb shell strings /data/property/persistent_properties | grep -E "^persist\." | sort
```

---

## 2. The route, and its two constraints

`TARGET_SYSTEM_PROP := device/huawei/bach/system.prop` appends verbatim to
`/system/build.prop`. Already proven on A11 on this device — `ro.zygote`, the ART heap
block and the `debug.sf.*` block all ship that way and demonstrably take effect.

From `system/core/init/property_service.cpp`:

```
PropertyLoadBootDefaults():
    /system/etc/prop.default            → kInitContext
    /system/build.prop                  → kInitContext
    /system_ext/build.prop              → kInitContext
    /vendor/default.prop                → kVendorContext
    /vendor/build.prop                  → kVendorContext
    /odm/..., /product/build.prop
    then: for each accumulated (name,value) → PropertySet()   // internal, no SELinux gate
```

**Constraint 1 — you cannot override vendor.** Files accumulate into one map and the
*later* file wins on a duplicate key (`it->second = value;` plus an
`Overriding previous 'ro.' property` warning). `/vendor/build.prop` is read after
`/system/build.prop`. Harmless today — the shipping vendor `build.prop` defines none of
these — but anything that must beat a vendor value has to go through
`vendor-fix/build_vendor_fixed.sh` instead.

**Constraint 2 — namespace, in our favour.** `/system/build.prop` is parsed under
`kInitContext`, not `kVendorContext`. So `system.prop` may legitimately carry `vendor.*`
and `persist.vendor.*` names; a *vendor* build.prop could not carry system ones. Property
**reads** are not gated either way, so a vendor HAL blob reads a name set from
`/system/build.prop` exactly as it read it on 17.1.

---

## 3. Method: don't trust the grouping, find the reader

The first pass through this list restored props by section heading and got two things
wrong within the hour — see §6. The second pass searched for each name instead:

```bash
# every file of the vendor image, against all lost names at once
tar xf bach-live-dump/vendor_full.tar -C vx          # 2547 files, 438 MB
LC_ALL=C grep -rHoaF -f props.txt vx/ | sort -u

# and, for framework-side candidates, the shipping system image
LC_ALL=C grep -acF "<name>" artifacts/los18-bach-a11-publish/system.img
```

A hit is not proof (a binary can compose a name at runtime) and a miss is not proof
either — but a miss in *both* images, for a name with no `vendor.*`-spelled counterpart,
is strong enough to leave the line out of a file whose whole point is that everything in
it is load-bearing.

---

## 4. What is now emitted (59)

| group | props | reader |
|---|---|---|
| RIL | `rild.libpath`, `rild.libargs`, `ril.subscription.types`, `ro.telephony.use_old_mnc_mcc_format`, `ro.telephony.call_ring.multiple` | `bin/hw/rild`, `lib64/libril-qc-qmi-1.so` |
| RIL behaviour | `persist.vendor.radio.{apm_sim_not_pwdn,custom_ecc,rat_on,sib16_support}` | `lib64/libril-qc-qmi-1.so` |
| Data | `persist.vendor.data.mode`, `persist.vendor.cne.feature` | `bin/qti`; `bin/cnd`, `lib{,64}/libcne.so` |
| USB | `persist.vendor.usb.config.extra`, `vendor.usb.rps_mask` | `etc/init/hw/init.qcom.usb.rc` (`${...}` expansion) |
| Display | `vendor.display.{disable_skip_validate,perf_hint_window,enable_default_color_mode}`, `ro.vendor.display.cabl` | `hwcomposer.msm8937.so`; `bin/mm-pp-dpps`, `libsdmextension.so` |
| Audio HAL | 13 names | `lib{,64}/hw/audio.primary.msm8937.so` |
| Audio post-proc | `persist.audio.dirac.speaker`, `vendor.audio.pp.asphere.enabled`, `vendor.audio.safx.pbe.enabled` | `soundfx/libdirac.so`, `libqcompostprocbundle.so`, `libqcbassboost.so` |
| Audio framework | `af.fast_track_multiplier`, `audio.deep_buffer.media`, `audio.offload.{video,min.duration.secs}` | AudioFlinger / AudioPolicyManager |
| Bluetooth | `vendor.qcom.bluetooth.soc`, `persist.bluetooth.a2dp_offload.disabled` | btconfigstore + `bluetooth@1.0-impl-qti`; AOSP BT stack |
| Misc | `ro.frp.pst`, `ro.vendor.extension_library`, `wifi.interface`, `drm.service.enabled`, `persist.vendor.delta_time.enable` | PDB service; 13 vendor binaries; wifi HAL; `drmserver`; `bin/time_daemon` |
| Graphics (earlier) | `ro.opengles.version`, `ro.surface_flinger.*`, `debug.sf.*`, `ro.config.*_vol_steps`, `sys.use_fifo_ui` | SurfaceFlinger, PackageManager |
| via vendor-fix | `vendor.vidc.disable.split.mode` | `libOmxVdec` / venus |

Two of these are bug fixes, not tunings — see §5.

---

## 5. Two real regressions found

**Modem dead (`rild.libpath`).** `/vendor/bin/hw/rild` is started with no `-l` argument
by `/vendor/etc/init/rild.legacy.rc`, so it resolves the RIL library from the property
alone. Unset, it takes the "assume no-ril case" branch:

```
RILD: **RILd param count=1**
RILD: RIL_Init starting sleep loop     ← no rilInit/RIL_register, and no dlopen error
```

RILJ never connects; `gsm.version.baseband` and `gsm.sim.state` stay empty while
`init.svc.ril-daemon` reads `running`.

**USB tethering dead (`persist.vendor.usb.config.extra`).** The vendor's
`init.qcom.usb.rc` builds the RNDIS composition by string concatenation:

```
on property:sys.usb.config=rndis
    setprop sys.usb.config rndis,${persist.vendor.usb.config.extra}

on property:sys.usb.config=rndis,none && property:sys.usb.configfs=0
    write .../functions rndis   /   write .../enable 1   /   setprop sys.usb.state rndis
```

An undefined property expands to empty in an init rc, so `sys.usb.config` becomes
`rndis,` — matching no trigger. The composition is never written and tethering silently
does nothing. This device is on the legacy path (`sys.usb.configfs=0` in the live dump),
which is exactly what those triggers gate on.

### Open lead: the clean-flash speaker regression

`README.md` attributes "a clean flash has the raw harsh-at-high-volume treble" to
BachSpeakerEQ being wiped with `/data`. The prop loss has the same clean-flash signature
and has never been tested. `soundfx/libdirac.so` — Huawei's speaker voicing on this
tablet — reads `persist.audio.dirac.speaker`, which this build sets nowhere.

A hypothesis, not a finding: libdirac may need more than one prop, and an effect that no
`audio_effects.conf` entry instantiates will not run whatever the property says. Settled
in one command while the loaner is here:

```bash
adb shell su -c 'setprop persist.audio.dirac.speaker true; killall audioserver'
```

`persist.vendor.audio.speaker.prot.enable` is ruled out of this question: the HAL blob
does not read it.

---

## 6. What is not emitted (82), and why

**Already set by the vendor itself (2) — never lost.**
`net.tcp.2g_init_rwnd` is `setprop`-ed by `init.qcom.rc`.
`vendor.gralloc.enable_fb_ubwc` is derived by `init.qcom.early_boot.sh`, which probes the
MDP and raises it only when `/sys/class/graphics/fb0/mdp/caps` reports ubwc — pre-setting
it from build.prop would force framebuffer UBWC on hardware the probe deliberately
excluded, while `vendor.gralloc.disable_ubwc` stayed 1.

**Held back for camera stability (5).** `camera.lowpower.record.enable`,
`persist.camera.{HAL3.enabled,is_type}`, `vidc.enc.dcvs.extra-buff-count` are read by
`lib/hw/camera.msm8937.so`; `persist.camera.gyro.android` by
`lib/libmmcamera2_stats_modules.so`. Those are precisely the two blobs the current camera
result rests on — the patched stats module and the A10 HAL, at 5/5 clean 1080p/30
recordings. `LOS18-CAMERA-STATUS.md` records that `persist.camera.*` levers were probed
during that work and did not help, and `docs/CAMERA.md` notes `persist.camera.hal.debug`
breaking the shutter outright. Restore only behind a camera test cycle.

**Held back for encoder stability (3).** `vendor.vidc.enc.{disable_bframes,disable_pframes,
narrow.searchrange}` are read by `lib{,64}/libOmxVenc.so`. Recording is verified working
*without* them; changing the encoder configuration under a validated result needs a
reason better than "17.1 had it". (`vendor.vidc.enc.disable.pq` is not restorable at all —
the encoder's only `disable`-prefixed names are the two above.)

**Held as documented experiments (5).** `debug.stagefright.omx_default_rank` and
`.sw-audio` force OMX above Codec2 and would reorder the whole codec list; with the
corrected `media_codecs.xml` limits now shipping, this is the one group worth actually
measuring rather than assuming. `media.stagefright.thumbnail.prefer_hw_codecs` interacts
with those same limits. `dalvik.vm.{dex2oat,image-dex2oat}-filter=speed` are legacy names —
A11 selects the compiler filter via `pm.dexopt.*` — and `speed` would inflate `/data` on a
`WITH_DEXPREOPT=false` build.

**Declared but never read (12).** Present only in `etc/selinux/vendor_property_contexts`
(a label declaration) or `etc/perf/perfconfigstore.xml` (a list the perf HAL manages), in
no binary: `persist.vendor.qti.telephony.vt_cam_interface`,
`ro.vendor.qualcomm.bt.hci_transport`, `vendor.camera.aux.packagelist`,
`vendor.mm.enable.qcom_parser`, `vendor.video.disable.ubwc`,
`ro.vendor.qti.am.reschedule_service`, `ro.vendor.qti.sys.fw.{bservice_enable,
empty_app_percent,use_trim_settings,trim_cache_percent,trim_empty_percent,
trim_enable_memory}`. The `qti.sys.fw` set needs QTI's ActivityManager patches, which
LineageOS does not carry.

**Effectively unset already (1).** `ro.vendor.use_data_netmgrd` appears once, as
`on property:ro.vendor.use_data_netmgrd=false / stop vendor.netmgrd`. Unset and `true`
are the same thing; netmgrd runs either way.

**No reader anywhere (54).** No match in the vendor image or the system image. Notable
members, since some look important:

- wrong spelling for this vendor — `persist.data.iwlan.enable` (netmgrd reads
  `persist.vendor.data.iwlan.enable`; deliberately *not* substituted, since that would
  switch IWLAN on for the first time rather than restore a baseline, on a build with no
  IMS stack), `sdm.debug.disable_skip_validate`, `sdm.debug.disable_rotator_split`,
  `sdm.perf_hint_window`, `ro.qualcomm.cabl`, `debug.gralloc.gfx_ubwc_disable` — each has
  a `vendor.*`-spelled counterpart found in the same binary
- no such component here — `persist.vendor.dpm.feature` (no `bin/dpmd`),
  `vendor.audio.dolby.ds2.*` (no Dolby library), `persist.ts.{postmakeup,rtmakeup}`
  (`TARGET_TS_MAKEUP := false`), `vendor.camera.hal1.packagelist`
  (`TARGET_SUPPORT_HAL1 := false`), `persist.vendor.btstack.*` (QTI BT stack; this build
  runs AOSP's), `persist.dbg.{volte,vt}_avail_ovr` (no IMS)
- removed from AOSP long before A11 — `media.stagefright.enable-*`,
  `media.stagefright.audio.sink`, `mmp.enable.3g2`, `media.msm8956hw`, `debug.egl.hw`,
  `debug.sf.hw`, `dev.pm.dyn_samplingrate`, `debug.media.codec2`
- inert leftovers — `DEVICE_PROVISIONED` (the real flag is
  `Settings.Global.device_provisioned`), `persist.sys.fflag.override.*` (an A9 Settings
  feature flag), `persist.data.qmi.adb_logmask`, the WFD/virtual-display group,
  `ro.gps.agps_provider`, `ro.vendor.qti.{core_ctl_min_cpu,core_ctl_max_cpu}`,
  `ro.vendor.qti.sys.fw.bg_apps_limit`

---

## 7. Housekeeping

`vendor_prop.mk` stays as the upstream record; its header points here. The two live
routes:

- system-context **and** vendor-namespace props → `system.prop` (`kInitContext`)
- anything that must **override** a value already in `/vendor/build.prop` →
  `vendor-fix/build_vendor_fixed.sh` (costs a vendor.img re-issue)

Regression check against any future build, from the repo root:

```bash
comm -23 \
  <(grep -oE '^[[:space:]]+[A-Za-z0-9_.-]+=' vendor_prop.mk | tr -d ' =' | sort -u) \
  <(cat system.prop <(debugfs -R 'dump /build.prop /dev/stdout' "$VENDOR_IMG" 2>/dev/null) \
    | grep -oE '^[A-Za-z0-9_.-]+=' | tr -d '=' | sort -u)
```

It should print the 82 of §6 and nothing else. A name appearing that is not in that list
means a prop was dropped without a reason being recorded.

## 8. On-device verification still owed

Nothing in this file has been tested on hardware — the tree is the only thing that
changed. In rough order of risk:

1. **Modem** — `getprop gsm.version.baseband`, `gsm.sim.state`, then a data call.
2. **USB tethering** — `sys.usb.state` should reach `rndis` when tethering is enabled.
3. **Display** — boot, wallpaper, rotation, video playback (the `disable_skip_validate`
   and CABL changes).
4. **Audio** — speaker treble on a clean flash, mic recording (fluence), offload playback.
5. **Bluetooth** — A2DP to a headset, with offload now explicitly disabled.
