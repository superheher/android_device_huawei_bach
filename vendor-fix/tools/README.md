# Codec measurement harnesses

Headless MediaCodec probes for `bach`. They exist because every number in
`../README.md` was measured with them rather than read off a datasheet, and because
the equivalent harness from 2026-08-30 was described as "reusable, in scratchpad" and
was gone by the next session. Scratchpad is not storage.

## Building

Needs `javac`, `d8` from the Android build-tools, and any recent `android.jar`. The
device is API 30; compiling against a newer jar is fine as long as only older APIs are
used, which these do.

```sh
javac -source 8 -target 8 \
      -bootclasspath /opt/android-sdk/platforms/android-35/android.jar \
      -d . DecBench.java
/opt/android-sdk/build-tools/34.0.0/d8 --min-api 30 --output . *.class
adb push classes.dex /data/local/tmp/decbench.dex
```

Two traps, both hit in practice:

- **Pass every `*.class` to `d8`**, not just the main one. Anonymous and inner classes
  are separate files and a missing one fails at runtime, not at build time.
- **End `main` with `Runtime.getRuntime().halt(0)`.** Without it `app_process` hangs
  forever in `DestroyJavaVM`. Note this also hides exceptions thrown before the call:
  a harness that hangs is usually one that threw on a bad argument.

## Running

```sh
adb shell 'CLASSPATH=/data/local/tmp/decbench.dex app_process /data/local/tmp DecBench \
           /data/local/tmp/clip.mp4 OMX.qcom.video.decoder.avc'
```

## What each one does

| tool | question it answers |
|---|---|
| `DecList` | which video **decoders** does the framework expose, with size limits and whether 1080p30/60 are supported |
| `EncList` | same for **encoders** |
| `DecProbe` | of a named list of decoders, which are actually registered and which fail to instantiate |
| `EncOne` | can one named encoder `configure`+`start` at a given size, bitrate and frame rate (one per process, so a failure cannot contaminate the next) |
| `FmtProbe` | what `MediaExtractor` sees in a file, then `configure` and `start` reported as separate stages — the first thing to run when a clip fails and it is unclear whose fault it is |
| `LevelProbe` | which profiles and levels a decoder reports, straight from the hardware |
| `DecBench` | decoder throughput: feed a clip as fast as the codec accepts, count output buffers, report fps and blocks/s |
| `EncBench` | encoder throughput: same idea, byte-buffer input |
| `DecRate` | whether `KEY_OPERATING_RATE` changes anything (it does not, on this device) |

## Known limitation

`DecBench` throws `IllegalStateException` from `dequeueInputBuffer` on MPEG-4 part 2
and H.263 clips, while decoding AVC and HEVC fine and while `FmtProbe` shows the same
clips configuring and starting without complaint. So the fault is in the harness loop,
not in those decoders. Size limits for `mpeg4sw` and `h263sw` were therefore established
with `FmtProbe` (configure+start succeeds up to and beyond the declared maximum), which
is a weaker test than decoding and is recorded as such.

## Measuring anything with these

Three rules, each learned by getting it wrong here first:

1. **Repeat and alternate.** One run per condition is not a measurement. Two YouTube
   clips looked like a clean 2x apart on single runs; repeated and alternated, they were
   not. Four runs and a 0.3-2.5% spread is what a real number looks like.
2. **Vary one factor.** A model fitted to points that moved two variables at once is not
   evidence however well it fits — and it fits best exactly when it misleads. See the
   four wrong revisions catalogued in `../README.md`.
3. **Do not profile on the host to predict this device.** On x86 the hostile clip costs
   1.97x the plain one; on this Venus, content costs 1.27x and bitrate costs nothing at
   all, and doubling bitrate on x86 costs 1.21x where here it costs nothing. Software
   profiling ranks clips. It does not predict this hardware.

## Test vectors

Not committed — they are tens of megabytes and regenerable. What was used:

- AVC: `ffmpeg -f lavfi -i testsrc2=size=1920x1080:rate=60:duration=15 -c:v libopenh264`
- HEVC and VP8 need an encoder this host lacks; they were produced elsewhere (NVENC on
  an RTX 3060, and libvpx). Require **Main profile, 8-bit** for HEVC — this decoder
  cannot do Main10, and NVENC defaults toward 10-bit. Verify at the bitstream level
  (`ffmpeg -trace_headers`, check `general_profile_idc=1` and
  `bit_depth_luma_minus8=0`), not from ffprobe's `profile` field.
- A "hostile" clip that stays hostile: zooming Mandelbrot with `outer=iteration_count`
  for fine detail and sub-pixel motion, plus a `life` cellular automaton with rule
  **B1357/S1357** (Replicator). Plain `life` B3/S23 decays — per-frame YAVG difference
  falls from 14.8 to 6.6 over 900 frames, so the clip quietly gets easier and inflates
  the result.

## Shell note

The interactive shell here is zsh, where `"$var:rate=30"` is parsed as the parameter
modifier `:r` and silently eats it, producing `size=1920x1080ate=30`. Use `${var}`.
