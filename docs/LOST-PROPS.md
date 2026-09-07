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
| `persist.` | gone too, in most cases. `PropertySet()` writes a `persist.` prop into `/data/property/persistent_properties` only when `persistent_properties_loaded == true`, and that is false during `PropertyLoadBootDefaults()`. So a prop that lived *only* in `build.prop` was never persisted to `/data`, and disappears with it. It survives an in-place 17.1 → 18.1 upgrade only if something wrote it at runtime — a HAL, the framework, a Settings toggle. **Measured on the tablet 2026-09-06: `/data/property/persistent_properties` holds 18 entries in total, and not one of the 141 is among them.** They are all gone, not "gone per device". |

So the hedge that this varies per device turned out to be too generous to the `persist.`
half: on a real upgraded tablet none of them survived. What does live in `/data/property`
is what the framework wrote at runtime — `persist.sys.*`, `persist.sys.locale`,
`persist.camera.gyro.disable` from the camera debugging, and so on.

To check any other device:

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

Measured on the tablet, not just read off the source: `ro.bach.proproute.probe` was
written as `from-system` in `/system/build.prop` and `from-vendor` in
`/vendor/build.prop`, and after a cold boot it reads **`from-vendor`**.

**Constraint 2 — namespace is not a constraint at all.** `/system/build.prop` is parsed
under `kInitContext` and `/vendor/build.prop` under `kVendorContext`, but
`PropertyLoadBootDefaults()` funnels every accumulated pair through the internal
`PropertySet()`, which has no SELinux gate. Both files carry both namespaces.

Measured both directions on the tablet, because the guess in either direction is
plausible and both would have been wrong:

- all 44 props from `system.prop` — `vendor.*`, `persist.vendor.*`, `ro.vendor.*`
  included — land byte-exact from `/system/build.prop`;
- the same 44 land byte-exact from `/vendor/build.prop` with `system.prop` restored to
  its original, including the system-owned types `rild.libpath` (`default_prop`),
  `ro.frp.pst` (`exported_default_prop`) and `af.fast_track_multiplier`
  (`exported3_default_prop`). The modem came up on that run with the RIL props present
  **only** in `/vendor`.

So the two routes are interchangeable in capability, and the only real asymmetry is
Constraint 1. Choose by ownership and by cost: `system.prop` is free on every build,
`vendor-fix/build_vendor_fixed.sh` costs a vendor.img re-issue but wins conflicts.

Property **reads** are gated, which matters for checking your work — see the trap in §3.

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

> **Measurement trap, learned the hard way.** `getprop` run from a plain `adb shell` is in
> the `shell` SELinux domain, which cannot **read** vendor-owned property types. It returns
> an empty string and no error, and the denial only shows up in the audit log:
> ```
> avc: denied { read } for name="u:object_r:vendor_audio_prop:s0"
>      scontext=u:r:shell:s0 tcontext=u:object_r:vendor_audio_prop:s0 tclass=file
> ```
> Checking the 44 restored props that way said 16 of 44 had landed and produced a
> confident, wrong theory that `/system/build.prop` cannot set vendor-namespace names.
> Re-run after `adb root` (context `u:r:su:s0`): **44 of 44, values exact.** Always verify
> property state from a context that can read it.
>
> The same artifact bites `setenforce`. From a plain `adb shell` it returns
> `Permission denied`, which reads like a locked-down device and nearly justified flashing
> a permissive boot image to get write access to `/vendor`. From `u:r:su:s0` it just works,
> and no flash was needed. Check the context before concluding the device is the problem.

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

The mechanism is harsher than "expands to empty": init's `ExpandProps` treats an
undefined property as an **error** and aborts the whole command. Reproduced on the tablet:

```
init: Command 'setprop sys.usb.config rndis,${persist.vendor.usb.config.extra},adb'
  action=sys.usb.config=rndis,adb && sys.usb.configfs=0 (init.qcom.usb.rc:838)
  took 0ms and failed: property 'persist.vendor.usb.config.extra' doesn't exist
  while expanding 'rndis,${persist.vendor.usb.config.extra},adb'
```

`sys.usb.config` therefore stays at `rndis,adb`, which matches no further trigger, the
gadget `functions` node is never rewritten and `sys.usb.state` never becomes `rndis`.
This device is on the legacy path (`sys.usb.configfs=0`), exactly what those triggers gate
on.

### Closed: the clean-flash speaker lead was wrong

An earlier revision of this file proposed that the lost `persist.audio.dirac.speaker`
explained what `README.md` attributes to BachSpeakerEQ being wiped with `/data` — the
harsh treble after a clean flash. Tested on the tablet and **falsified**:

- `/vendor/etc/audio_effects.xml` declares the dirac library and its effect uuid, but the
  file has **no `<postprocess>` section at all**. Its only binding is `<preprocess>`
  attaching `aec` and `ns` to `voice_communication`. Nothing binds dirac to an output.
- `libdirac.so` has **zero mappings** in `audioserver`. It never loads.

So the property cannot be shaping the default speaker voicing, and README.md's original
explanation stands. `persist.vendor.audio.speaker.prot.enable` was already ruled out — the
HAL blob does not read it. The dirac line stays in `system.prop` only because the reader is
real and any app can instantiate the effect by uuid.

---

## 6. What is not emitted (82), and why

**Already set by the vendor itself (2) — never lost.**
`net.tcp.2g_init_rwnd` is `setprop`-ed by `init.qcom.rc`.
`vendor.gralloc.enable_fb_ubwc` is derived by `init.qcom.early_boot.sh`, which probes the
MDP and raises it only when `/sys/class/graphics/fb0/mdp/caps` reports ubwc. Confirmed on
the tablet: `mdp/caps` **does** contain `ubwc`, and at runtime `enable_fb_ubwc=1` with
`disable_ubwc=0` — already correct, with no help from us. Restoring it here would have been
a redundant line on this hardware and a wrong one on any bach variant whose MDP does not
advertise ubwc, where it would force framebuffer UBWC on while `disable_ubwc` stayed 1.

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

## 6b. How these actually ship (20260907)

The tree says `system.prop`, but a released device gets them from `/vendor/build.prop`.

That is not a preference — the from-source system image has not booted since June
(`publish/BUILD_PROVENANCE.md`), so releases carry the proven Jun17 audittest system
unchanged, and nothing appended to `system.prop` can reach a user. The `20260907` OTA
therefore adds the 44-property block to the vendor image instead, with
`publish-20260907/build_vendor_radio.sh` — `debugfs` only, no sudo, no loop mount, in the
same style as `vendor-fix/build_vendor_fixed.sh`.

Measured on the tablet, with `/system/build.prop` restored to the untouched original so the
properties could only come from vendor: **44/44 byte-exact after a cold boot into enforcing**,
modem up, USB tethering reconfiguring the gadget. Constraint 1 makes this safe to leave in
place: `/vendor` wins duplicates, so once a from-source system boots and `system.prop` starts
emitting these again, the identical vendor values win harmlessly. Remove the vendor block at
that point — it is a source↔ship divergence, and it is recorded as one in
`publish-20260907/BUILD_PROVENANCE.md`.

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

## 8. On-device verification (2026-09-06)

Run on the BAH-L09 loaner (serial XMRNU18409101576) against the reporter's exact build,
`eng.root.20260617.204056`. The 44 new `system.prop` lines were appended to the device's
`/system/build.prop` behind a marker fence and the tablet cold-booted, so this exercises
the real `TARGET_SYSTEM_PROP` path and not a runtime `setprop`.

Note the tablet boots an **enforcing** kernel cmdline (`androidboot.selinux=enforcing`),
from the 2026-06-18 enforcing session — not the permissive cmdline in the published
`artifacts/los18-bach-a11-publish/boot.img`. Everything below therefore holds under
enforcing.

**Delivery.** 44 of 44 props set after a cold boot, values byte-exact against the tree,
0 mismatches. Boot completed in ~25 s, `surfaceflinger` / `audioserver` / `system_server`
all up, crash buffer empty, no init property errors.

**Modem — fixed, and to parity with 17.1.** Before: `rild.libpath` empty and the `rild`
process parked in `hrtimer_nanosleep`, i.e. literally the `sleep(UINT32_MAX)` of the
no-ril branch. After:

| | before | after |
|---|---|---|
| `rild` process state | `hrtimer_nanosleep` | `binder_ioctl` |
| radio log | `RIL_Init starting sleep loop` | `RIL_Init argc = 5 clientId = 0` |
| `gsm.version.baseband` | empty | `00022` |
| `gsm.sim.state` | empty | `LOADED` |
| `gsm.version.ril-impl` | empty | `Qualcomm RIL 1.0` |
| `gsm.sim.operator.alpha` | empty | `Tele2` |

Every value matches the 17.1 live dump exactly. RILJ is up and scanning — a WCDMA cell at
level 4 in `RIL_REQUEST_GET_CELL_INFO_LIST`.

One thing the fix cannot deliver here: the SIM does not register
(`registrationState=DENIED rejectCause=13`, "roaming not allowed", a Russian Tele2 SIM on
an MCC 257 network). That is **not** a regression — the 17.1 dump shows the same,
`gsm.operator.numeric` empty and `gsm.network.type=Unknown`. So a data call could not be
exercised, and the data-path props (`persist.vendor.data.mode`, `persist.vendor.cne.feature`)
remain delivered-but-unexercised.

**USB tethering — regression and fix both reproduced.** With the prop absent, init aborts
the command outright (§5) and the gadget is never reconfigured: `functions=ffs`,
`sys.usb.state=adb`, no `rndis0`. With it present from `build.prop`: `sys.usb.config`
resolves to `rndis,none,adb`, `sys.usb.state=rndis,adb`, `functions=rndis_qc,ffs` and
`/sys/class/net/rndis0` appears. Zero expansion failures on the second run.

**Still not exercised.** Display (`disable_skip_validate`, CABL) and audio (fluence,
offload) are delivered and the system is stable with them, but no A/B was run — the UI
boots and renders, which is not the same as measuring composition or listening for a
change. Bluetooth A2DP untested. The camera and encoder groups were deliberately not
restored, so nothing to test there.

**Vendor route — verified, and no flash was needed.** A second run put all 44 props in
`/vendor/build.prop` only, with `/system/build.prop` restored to its original, and cold
booted back into enforcing. Result: 44 of 44 byte-exact, the modem up on RIL props living
only in `/vendor`, zero crashes, zero `Could not set` failures from init. `/vendor` was
then restored byte-for-byte from its backup (hash-checked) and the stray backup removed,
so the partition is pristine at its original 43 lines.

Getting write access to `/vendor` needed `setenforce 0` plus
`nsenter -t 1 -m -- mount -o remount,rw /vendor`, both of which work from `u:r:su:s0`.
The earlier "device is locked down, this needs a permissive boot flashed" conclusion was
the §3 context artifact again.

**Boot image on this tablet matches nothing on disk.** While preparing for that flash,
every boot artifact in the tree was hash-compared against the partition over its own
length — `artifacts/los18-bach-a11*/`, `at_boot_*.img`, `cur_boot.img`, `new_boot*.img`,
`fresh_permissive_boot.img`, `boot-good-backup.img`. None matched. The running boot is a
build that was flashed and not kept, so an 80 MB dump of `mmcblk0p35` is preserved at
`artifacts/boot-as-flashed-20260906/` with restore instructions. Its cmdline carries
`androidboot.selinux=enforcing`, which is why `README.md`'s "SELinux is permissive" no
longer describes this device even though it still describes the published `boot.img`.

**Device left in this state**, deliberately, so the tablet behaves like the fixed build:
`/system/build.prop` carries the 44 lines between
`# BEGIN device-tree system.prop verification` and `# END`, with the original saved as
`/system/build.prop.claude-bak`. To revert:

```bash
adb root && adb shell 'mount -o rw,remount / && cp /system/build.prop.claude-bak /system/build.prop && mount -o ro,remount /'
adb reboot
```

`persist.vendor.usb.config.extra=none` was also set at runtime during the test, so it now
exists in `/data/property/persistent_properties` as well as in `build.prop`. Same value
either way; a Format Data clears the `/data` copy.
