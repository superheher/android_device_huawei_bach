# `vendor-fix` — the two hardware-video-decode fixes

Two bugs in the reused prebuilt A10 `vendor.img` broke *all* hardware decode on `bach`, not just
H.265. Neither fits this tree's make files, so `build_vendor_fixed.sh` writes them into the
image. Diagnosed 2026-08-30.

## Bug 1 — OPB/DPB split mode kills all hardware decode

`libOmxVdec.so` uses split mode — linear NV12 output plus a UBWC-compressed DPB — which the
msm8937 venus firmware rejects, so every session dies at `start`:

```
set_prop 0x4000002 -> HFI prop 0x00001003 (UNCOMPRESSED_FORMAT_SELECT), payload 0x8002
-> HFI_EVENT_SESSION_ERROR, event id 4103 ("Unsupported bitstream")
-> Failed to prepare bufs -> allocateBuffer(...) = InsufficientResources
-> ACodec internalError -12 (NO_MEMORY) -> start failed
```

`NO_MEMORY` is a red herring: 1.7 GB was free. Reproducible 4/4, H.264 and H.265, 720p and 1080p.

**Fix:** `vendor.vidc.disable.split.mode=1`, QTI's own switch. Only split mode's DPB is rejected —
the display block does use UBWC.

## Bug 2 — `media_codecs.xml` advertises capability the firmware lacks

Entries claimed 4096x2160 / 1958400 blocks/s / 240 fps, copied from a larger SoC; the vendor's
own comment table in that same file and the firmware both cap at 1920x1088 @ 30. ExoPlayer
believed them and picked 1080p60 streams the display path cannot present — portrait panel, every
landscape frame rotated 270° through the MDSS rotator — so frames dropped and ABR flapped down.

**Fix** (decoders `avc` / `hevc` / `vp8` / `vp9`):

```
size              3840x2160 | 4096x2160        ->  1920x1088
blocks-per-second 972000 | 979200 | 1958400    ->  244800
bitrate           1-100000000                  ->  1-20000000
performance-point-3840x2160=24                 ->  performance-point-1920x1080=30
                                                +  performance-point-1280x720=60
```

`frame-rate` stays `1-240`; `blocks-per-second` alone decides — 1080p60 needs 489600 (denied),
720p60 needs 216000 (allowed).

**Trade-off:** a local 1080p60 file now resolves to `c2.android.avc.decoder` — honest, since
1080p60 is out of spec here. VLC still drove the hardware decoder and got faster (39.5 -> 48.5
fps): a 1920x1088 adaptive-playback ceiling allocates far smaller buffers.

## Why not a `.mk`

`PRODUCT_PROPERTY_OVERRIDES` land in `/vendor/build.prop`, which the prebuilt image overwrites
wholesale — the trap that dropped the ART heap props. `vendor_prop.mk` carries the split-mode
property but nothing inherits it. `media_codecs.xml` lives inside the image.

## Usage

```sh
./build_vendor_fixed.sh <pristine-vendor.img> <out.img> [media_codecs.xml]
```

No root, loop-mount or sudo: `debugfs` writes both files, `ea_set -f` restores their SELinux
contexts NUL-terminated as Android's ext4 writer does, `e2fsck -fn` closes.

## Verified on device (2026-08-30, flashed, cold boot, framework-chosen codec)

| clip | decoder | before | after |
|---|---|---|---|
| H.265 1080p30 | `OMX.qcom.video.decoder.hevc` | start failed | 300 frames, 56.6 fps |
| H.265 720p30  | `OMX.qcom.video.decoder.hevc` | start failed | 300 frames, 67.4 fps |
| H.264 1080p60 | `OMX.qcom.video.decoder.avc`  | start failed | 300 frames, 73.9 fps |

End-to-end, `dumpsys SurfaceFlinger --timestats`, one H.264 file with only timestamps rescaled
(`ffmpeg -itsscale`) so frame rate is the sole variable:

| clip | avgFPS | dropped |
|---|---|---|
| 1080p60 (before the XML fix) | 39.5 | 24 / 81 |
| 1080p60 (after the XML fix)  | 48.5 | 5 / 100 |
| 1080p30                      | 30.29 | 0 / 1018 |
| 1080p30 HEVC                 | 30.27 | 0 / 1013 |

ReVanced YouTube at 1080p, two runs: `droppedFrames=0`. Encoders keep the same inflated limits
**deliberately** — camera recording was hard-won. Measure end-to-end: fix 1 passed every isolated
benchmark while the app still stuttered.

## Reproducibility — read before the next publish

| image | sha256 |
|---|---|
| flashed + verified 2026-08-30 | `ab406417caee64722b082c37f876e77dc0b310ced9d0a1fa7ce35a98bd8af475` |
| this script vs pristine `/vendor` | `0ea1076215e10dc8b8b3f65af757329924ba643e94b5cfe8af79ec30fc32a4a3` |

They differ in one file, `build.prop`, and only in a comment — the flashed image carries the
first-draft "venus has no UBWC" wording. Functionally identical but not bit-reproducible here;
prefer publishing a rebuild. Input must be pristine `/vendor`: the 2026-08-30 backup, or
`vendor.img` from `lineage-18.1.0-bach-audittest.zip` plus the release's CIL allows (verified
2026-08-31 to differ in `vendor_sepolicy.cil` alone).

## Post-flash verification of the decoder declaration (2026-09-06)

Two YouTube videos with identical formats (both itag 299, `avc1.64002A`,
1920x1080@60; bitrates 5.79 and 5.22 Mbps), three alternating runs each, measured
with `dumpsys SurfaceFlinger --timestats`:

| run | "Format exceeds" warning | frames | dropped | avgFPS |
|---|---|---|---|---|
| old #1 | none | 706 | 37 | 44.05 |
| new #1 | none | 1860 | 0 | 62.43 |
| old #2 | none | 1615 | 66 | 53.78 |
| new #2 | none | 1742 | 119 | 58.20 |
| old #3 | none | 1575 | 70 | 52.36 |
| new #3 | none | 1739 | 123 | 58.05 |

The warning is gone in all six runs — the player is no longer operating on a
declaration it had decided to ignore.

The higher-bitrate video improved from ~30-47 fps to ~44-54. The lower-bitrate one
stayed inside its previous spread (62.5 / 58.1 before). Alternating the order was
necessary: single runs before the change gave 30.5 and 62.5, which looked like a
clean two-fold difference and was not.

Neither reaches a clean 60 — both now drop 4-7% of frames. That is the expected
trade: the display path (portrait 1200x1920 panel, every landscape frame rotated
270 degrees through the MDSS rotator) is what limits 1080p60, not the decoder. The
difference is that the player can now see those drops in its own feedback and adapt,
instead of being handed a number it ignored.

### What this decoder is limited by

**Content, not bitrate.** Established by holding one variable while moving the other.

Bitrate, same content throughout, four alternating runs each:

| clip | bitrate | runs | mean |
|---|---|---|---|
| busy 8M | 8.105 Mbit/s | 79.7 / 79.5 / 79.6 / 79.6 | 79.6 |
| busy 12M | 12.177 Mbit/s | 72.9\* / 79.3 / 79.5 / 79.5 | 79.4 |
| busy 16M | 16.228 Mbit/s | 81.2 / 81.0 / 81.2 / 81.1 | 81.1 |

\* first run of a freshly pushed file; the three that follow agree to 0.3%.

Doubling the bitrate moves throughput by +1.9%. A bitrate-bound decoder would have
halved, to roughly 40 fps.

Content, at comparable bitrate:

| clip | bitrate | mean |
|---|---|---|
| plain (`testsrc2`) | 6.085 Mbit/s | 101.0 |
| busy (fractal zoom + cellular automaton + noise) | 8.105 Mbit/s | 79.6 |

Since bitrate has been shown not to matter across 8-16 Mbit/s, this 1.27x is the
content. The one codec comparison in the set, same content and bitrate: **HEVC costs
1.256x AVC per frame** (busy 8M: hevc 79.6, avc 100.5).

**Consequence for the declaration:** worst-case content decodes at ~80 fps against the
60 that 1080p60 needs, and that margin does *not* erode with bitrate anywhere in the
tested range. The declaration is sound, with more room than any earlier revision of
this section claimed.

#### How this section was wrong four times

Kept because the traps are distinct and the last one is the interesting one.

1. "Synthetic clips overstate headroom" — a guess, never tested.
2. "Throughput is content-independent" — from one run per clip (75.7 plain, 75.9 busy).
   One run is not a measurement.
3. "The 1.27x gap is content" — right conclusion, but plain and busy differed in *two*
   variables, picture and bitrate, so the data did not support it.
4. "The gap is bitrate, not content" — this looked rigorous. Computing bitstream
   throughput instead of fps gave 10.24 vs 10.74 Mbit/s, flat within 4.8%, and a
   two-point model predicted a 60 fps ceiling at 11.2 Mbit/s. Both points fit. It was
   still wrong: two points cannot separate two explanations that both pass through
   them. The model predicted 55.6 fps at 12 Mbit/s and 42.8 at 16; measurement gave
   79.4 and 81.1, off by 43% and 90%.

The rule that would have prevented all four: **vary one factor and hold the rest.** A
model fitted to points that move two variables at once is not evidence, however well it
fits — and the better it fits, the more convincing the error looks.

### The DCVS explanation, and why it is dead

hevc measured 75.7 fps before the declarations were flashed and 101.0 after, while avc
-- whose declaration did not change in that flash -- measured 99.1 before and 100.5
after. Commit 75152ed floated the idea that `blocks-per-second` might feed Venus DCVS
and set the video clock, rather than only informing the player's choice, which would
have made 75.7 a genuinely throttled measurement instead of a single-sample artefact.

Testable without undoing the flash: set `KEY_OPERATING_RATE` explicitly and vary it on
the same clip and decoder.

    rate=none 100.4    rate=60  100.8
    rate=15   100.5    rate=120 101.7
    rate=30   101.0    rate=240 100.8

A 16x range of requested rates moves throughput by 1.3%, which is run-to-run noise. If
the clock followed the requested rate, `rate=15` would have throttled it. **The DCVS
explanation is falsified.** The pre-flash 75.7 goes back to being what it always was:
one sample, taken once.

Worth keeping as a pattern: the hypothesis was cheap to kill because it predicted
something specific and checkable that did not require reverting anything.
