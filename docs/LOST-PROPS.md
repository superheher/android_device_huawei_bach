# The 141 lost properties

Audit trail for the `vendor_prop.mk` trap. Written after the BAH-L09 "no modem / no SIM"
report (2026-06-17 build) turned out to be one of its casualties.

**Status: 20 of 141 covered, 121 still lost.**

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

| kind | count still lost | behaviour |
|---|---:|---|
| non-`persist.` | 84 | gone the moment they leave `build.prop`. Every flash, every boot. Deterministic. |
| `persist.` | 37 | re-set from `build.prop` each boot **only if** they are still in `build.prop`. `PropertySet()` writes a `persist.` prop into `/data/property/persistent_properties` only when `persistent_properties_loaded == true`, which is false during `PropertyLoadBootDefaults()` — so a prop that lived *only* in `build.prop` was never persisted to `/data` and is now simply gone too. It survives only if something wrote it at runtime on 17.1 (a HAL, the framework, a Settings toggle). |

So the `persist.` half fails **per-prop and per-device**, which is why user reports are
inconsistent, while `rild.libpath` killed the modem for everyone the same way.

To find out which `persist.` props a given device still carries from 17.1:

```bash
adb shell strings /data/property/persistent_properties | grep -E "^persist\." | sort
```

---

## 2. The route, and its two constraints

`TARGET_SYSTEM_PROP := device/huawei/bach/system.prop` appends verbatim to
`/system/build.prop`. This is already proven on A11 on this device — `ro.zygote`,
the ART heap block and the `debug.sf.*` / `sys.use_fifo_ui` block all ship that way and
demonstrably take effect.

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

**Constraint 1 — you cannot override vendor.** Files are accumulated into one map and the
*later* file wins on a duplicate key (`it->second = value;` plus an
`Overriding previous 'ro.' property` warning). `/vendor/build.prop` is read after
`/system/build.prop`. For bach this is currently harmless: the shipping vendor
`build.prop` defines none of the 121. Anything that must beat a vendor value has to go
through `vendor-fix/build_vendor_fixed.sh` instead.

**Constraint 2 — namespace, in our favour.** `/system/build.prop` is parsed under
`kInitContext`, not `kVendorContext`. So `system.prop` may legitimately carry
`vendor.*` / `persist.vendor.*` names; a *vendor* build.prop could not carry system ones.
(Verified in the lineage-20 source; A11's `LoadProperties` has no per-line permission
check at all, so it is at least as permissive.)

Property **reads** are not gated either way, so a vendor HAL blob reads a name set from
`/system/build.prop` exactly as it read it on 17.1.

---

## 3. Already covered (20)

| via | props |
|---|---|
| `system.prop` — graphics block | `ro.opengles.version`, `ro.surface_flinger.*` (5), `debug.sf.early_*` (4), `debug.sf.latch_unsignaled`, `debug.sf.enable_gl_backpressure`, `ro.config.media_vol_steps`, `ro.config.vc_call_vol_steps`, `sys.use_fifo_ui` |
| `system.prop` — radio block (this change) | `rild.libpath`, `ril.subscription.types`, `ro.telephony.use_old_mnc_mcc_format`, `ro.telephony.call_ring.multiple` |
| `vendor-fix/build_vendor_fixed.sh` | `vendor.vidc.disable.split.mode` |

`rild.libargs=-d /dev/smd0` was added in the same block. Note it is **not** in
`vendor_prop.mk` at all — it was live on 17.1 from somewhere else in surdu's tree, so it
is not counted in the 141 but was equally lost.

The ART heap block in `system.prop` is also not part of the 141: those came from the
`dalvik-heap.mk` inherit, which hit the same `/vendor` trap independently.

---

## 4. Restore plan

Confidence is stated per group. "Reads it" means the consumer is a blob or framework
component actually present on this build; where that is an inference from surdu's tree
rather than something checked, it says so.

### Tier A — restore next, real consumer present

**A1. Data path (6).** The natural follow-on to the RIL fix: `rild.libpath` gets SIM
detection, these get data calls. `BOARD_USES_QCNE := true` in `BoardConfig.mk` means cnd
is expected to run.

```
ro.vendor.use_data_netmgrd=true
persist.data.netmgrd.qos.enable=true
persist.vendor.data.mode=concurrent
persist.vendor.cne.feature=1
persist.vendor.dpm.feature=0
persist.vendor.sys.cnd.iwlan=1
```

**A2. RIL behaviour (5).** Read by `libril-qc-qmi-1.so` during init.

```
persist.vendor.radio.apm_sim_not_pwdn=1
persist.vendor.radio.custom_ecc=1
persist.vendor.radio.rat_on=combine
persist.vendor.radio.sib16_support=1
persist.data.iwlan.enable=true
```

**A3. Display / SDM (9).** `disable_skip_validate` is the notable one — it is a
correctness workaround on legacy SDM targets, not a tuning; without it the composer may
skip validation it actually needs. The UBWC pair is worth reading against the video work
in `SESSION-2026-08-30-bach-hw-video-decode.md`: `debug.gralloc.gfx_ubwc_disable=0` and
`vendor.gralloc.enable_fb_ubwc=1` *enable* UBWC for the display block, which is
consistent with the deliberate decision not to set `vendor.video.disable.ubwc=1`.

```
sdm.debug.disable_skip_validate=1
vendor.display.disable_skip_validate=1
sdm.debug.disable_rotator_split=1
sdm.perf_hint_window=50
vendor.display.perf_hint_window=50
vendor.display.enable_default_color_mode=1
vendor.gralloc.enable_fb_ubwc=1
debug.gralloc.gfx_ubwc_disable=0
ro.qualcomm.cabl=2 + ro.vendor.display.cabl=2
```

**A4. Audio HAL (32).** The whole block is read by the same A10 `audio.primary` blob that
ran on 17.1, so every one of these is now at the blob's compiled-in default instead of
surdu's value.

> **Open lead — the clean-flash speaker regression.** `README.md` attributes "a clean
> flash has the raw harsh-at-high-volume treble" to BachSpeakerEQ being wiped. The prop
> loss has the *same* clean-flash signature and is untested. `persist.audio.dirac.speaker=true`
> is the specific suspect (Dirac is Huawei's speaker tuning path), with the fluence trio and
> `persist.vendor.audio.speaker.prot.enable=false` behind it. Caveat: for some of these the
> HAL's own default may already equal surdu's value, in which case restoring changes
> nothing. Cheap to settle on the loaner:
> ```bash
> adb shell su -c 'setprop persist.audio.dirac.speaker true; \
>                  setprop persist.vendor.audio.fluence.speaker true; \
>                  killall audioserver'
> ```
> and listen. If that is the cause, the fix is a prop block, not a bundled app.

Full list: `af.fast_track_multiplier`, `audio.deep_buffer.media`,
`audio.offload.min.duration.secs`, `audio.offload.video`,
`persist.vendor.audio.fluence.{voicecall,speaker,voicerec}`,
`persist.vendor.audio.speaker.prot.enable`, `persist.vendor.btstack.enable.splita2dp`,
`persist.vendor.audio.hw.binder.size_kbyte`, `vendor.audio.dolby.ds2.{enabled,hardbypass}`,
`vendor.audio.flac.sw.decoder.24bit`, `ro.vendor.audio.sdk.{fluencetype,ssr}`,
`vendor.audio_hal.period_size`, `vendor.audio.hw.aac.encoder`,
`vendor.audio.offload.{buffer.size.kb,gapless.enabled,multiple.enabled,passthrough,track.enable}`,
`vendor.audio.playback.mch.downsample`, `vendor.audio.parser.ip.buffer.size`,
`vendor.audio.pp.asphere.enabled`, `vendor.audio.safx.pbe.enabled`,
`vendor.audio.use.sw.{alac,ape}.decoder`, `vendor.audio.tunnel.encode`,
`vendor.voice.conc.fallbackpath`, `vendor.voice.path.for.pcm.voip`,
`persist.audio.dirac.speaker`.

**A5. Bluetooth (4).** BT works today, so the HAL is finding its transport elsewhere — but
`persist.bluetooth.a2dp_offload.disabled=true` is the one to check on a *clean-flashed*
device, because if offload is not disabled and the vendor cannot do it, BT audio breaks.

```
vendor.qcom.bluetooth.soc=smd
ro.vendor.qualcomm.bt.hci_transport=smd
persist.bluetooth.a2dp_offload.disabled=true
persist.vendor.btstack.a2dp_offload_cap=sbc-aptx-aptxtws-aptxhd-aac-ldac-aptxadaptive
```

**A6. Singles (4).**

| prop | why |
|---|---|
| `ro.frp.pst=/dev/block/bootdevice/by-name/config` | `PersistentDataBlockService` is disabled without it — factory reset protection / OEM unlock state |
| `ro.gps.agps_provider=1` | AGPS |
| `ro.vendor.extension_library=libqti-perfd-client.so` | the framework's perf-hint client; without it no perfd integration at all |
| `wifi.interface=wlan0` | Wi-Fi works, so low risk, but it is free |

**A7. Camera (11).** Worth reading against `docs/CAMERA.md` before restoring — this tree
builds the camera HAL from source with `TARGET_SUPPORT_HAL1 := false` and
`TARGET_TS_MAKEUP := false`, so some of surdu's values now describe a configuration that
no longer exists.

- likely still meaningful: `persist.camera.HAL3.enabled=1`, `persist.camera.is_type=1`,
  `persist.camera.gyro.android=1`, `persist.camera.pip_disable=1`,
  `persist.vendor.camera.display.{umax=1920x1080,lmax=1280x720}`,
  `camera.lowpower.record.enable=1`, `vendor.camera.aux.packagelist=org.lineageos.snap`
- likely moot here: `vendor.camera.hal1.packagelist` (HAL1 not built),
  `persist.ts.postmakeup` / `persist.ts.rtmakeup` (ThunderSoft blobs not built)

**A8. Video encode (5).** Camcorder path; sits next to the decode work already done.
`vendor.vidc.enc.{disable_bframes,disable_pframes,disable.pq,narrow.searchrange}`,
`vidc.enc.dcvs.extra-buff-count=2`.

### Tier B — verify before restoring

| prop(s) | doubt |
|---|---|
| `ro.vendor.qti.sys.fw.*` (6: `bservice_enable`, `bg_apps_limit`, `use_trim_settings`, `empty_app_percent`, `trim_*`), `ro.vendor.qti.am.reschedule_service` | these are read by QTI's ActivityManager/PackageManager patches, which LineageOS does not carry. Expected to be inert on a stock LOS 18.1 framework — confirm before spending a line on them |
| `ro.vendor.qti.core_ctl_{min,max}_cpu` | consumed by the perf HAL / core_ctl; on an 8×A53 single-cluster msm8937 the effect is marginal |
| `debug.stagefright.omx_default_rank=0`, `debug.stagefright.omx_default_rank.sw-audio=1`, `debug.media.codec2=2` | genuinely relevant to the codec work: they force OMX above Codec2. The A10 vendor ships OMX only, so the default ranking may already do the right thing — but this is the one Tier B group worth actually measuring |
| `media.stagefright.thumbnail.prefer_hw_codecs=true` | interacts with the corrected `media_codecs.xml` limits; test with the thumbnailer |
| `vendor.mm.enable.qcom_parser=4176895` | extractors moved to APEX on A11; probably inert |
| `dalvik.vm.dex2oat-filter=speed`, `dalvik.vm.image-dex2oat-filter=speed` | legacy names; A11 selects the compiler filter via `pm.dexopt.*`. On a `WITH_DEXPREOPT=false` build `speed` would also inflate `/data`. Probably skip |
| `persist.vendor.delta_time.enable=true` | QTI time services; consumer not confirmed on this build |

### Tier C — no consumer on this build, document and drop (23)

Restore only if something specific regresses. Grouped by reason:

- **removed from AOSP long before A11** — `media.stagefright.enable-{player,http,aac,qcp,scan}`,
  `media.stagefright.audio.sink`, `mmp.enable.3g2`, `media.msm8956hw`, `debug.egl.hw`,
  `debug.sf.hw`, `dev.pm.dyn_samplingrate`, `net.tcp.2g_init_rwnd`, `drm.service.enabled`
- **no IMS stack on this build** (no `qti-telephony-*.jar`, so no VoLTE/VT) —
  `persist.dbg.volte_avail_ovr`, `persist.dbg.vt_avail_ovr`,
  `persist.vendor.qti.telephony.vt_cam_interface`
- **no WFD / virtual-display stack** — `persist.sys.wfd.virtual`,
  `persist.demo.hdmirotationlock`, `debug.sf.enable_hwc_vds`, `persist.hwc.enable_vds`
- **inert or cosmetic** — `DEVICE_PROVISIONED` (the real flag is
  `Settings.Global.device_provisioned`; the prop is a CM-era leftover),
  `persist.sys.fflag.override.settings_network_and_internet_v2` (an A9 Settings feature
  flag, gone in A11), `persist.data.qmi.adb_logmask` (logging only),
  `persist.vendor.usb.config.extra` + `vendor.usb.rps_mask` (USB works)

---

## 5. Housekeeping

`vendor_prop.mk` should stay in the tree as the upstream record, but its header should
point here, and the two live routes should be stated once:

- system-context **and** vendor-namespace props → `system.prop` (`kInitContext`, cannot
  collide with vendor today)
- anything that must **override** a value already in `/vendor/build.prop` →
  `vendor-fix/build_vendor_fixed.sh` (costs a vendor.img re-issue)

Regression check to run against any future build, from the repo root:

```bash
# every name declared in vendor_prop.mk that reaches neither route
comm -23 \
  <(grep -oE '^[[:space:]]+[A-Za-z0-9_.-]+=' vendor_prop.mk | tr -d ' =' | sort -u) \
  <(cat system.prop <(debugfs -R 'dump /build.prop /dev/stdout' "$VENDOR_IMG" 2>/dev/null) \
    | grep -oE '^[A-Za-z0-9_.-]+=' | tr -d '=' | sort -u)
```
