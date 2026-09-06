# storage-probe

A ~120-line native probe that reports, for one directory, which filesystem
primitives an app can actually use there. Written for the "Couldn't save offline
map" report, to answer whether bach's storage stack can do what an app needs when
it commits a large dataset — without needing the app.

## Build and run

```bash
NDK=/opt/android-sdk/ndk/23.2.8568313
$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android30-clang -O1 -o probe probe.c
adb push probe /data/local/tmp/ && adb shell chmod 755 /data/local/tmp/probe
adb shell /data/local/tmp/probe /storage/emulated/0/Android/data/<pkg>/files
```

Run it inside a real app's mount namespace to get the app's view of the mount
topology rather than the global one — the two differ on Android 11:

```bash
adb shell nsenter -t $(adb shell pidof <pkg>) -m -- /data/local/tmp/probe <dir>
```

Note that Android 11 isolates app data dirs per namespace, so from app A's
namespace you can only reach app A's own `/data/user/0/...`.

## Measured on bach, 2026-09-06

BAH-L09, `lineage_bach-userdebug 11 eng.root.20260617.204056`, enforcing.

| primitive | `/data` (f2fs) | `Android/data` (sdcardfs nested in FUSE) | `/storage/emulated/0` (FUSE) |
|---|---|---|---|
| ftruncate | OK | OK | OK |
| **fallocate** | OK | **ENOTSUP** | **ENOTSUP** |
| fallocate KEEP_SIZE | OK | **ENOTSUP** | **ENOTSUP** |
| pwrite | OK | OK | OK |
| fsync / fdatasync | OK | OK | OK |
| **mmap MAP_SHARED RW** | OK | OK | OK |
| msync(MS_SYNC) | OK | OK | OK |
| flock LOCK_EX | OK | OK | **ENOSYS** |
| fcntl F_SETLK | OK | OK | OK |
| rename | OK | OK | OK |
| **link (hardlink)** | OK | **EPERM** | **ENOSYS** |
| open O_DIRECT | OK | OK | OK |

Plus, separately: a 128 MB sequential write with `conv=fsync` into `Android/data`
completed at 106 MB/s, and renaming the containing directory into place worked.

## What this settles

Everything SQLite needs in order to commit — a shared writable `mmap` for the WAL
`-shm` file, POSIX `fcntl` locks, `fsync`, `rename` — works on `Android/data`.
So "the storage stack cannot commit a database there" is not the explanation for
the offline-map failure.

Two primitives do fail there, `fallocate` and `link`. Both are ordinary FUSE
emulated-storage limitations on Android 11 rather than anything specific to this
port, and neither fits the reporter's Android 10 data point, since Q served
`/storage/emulated` from sdcardfs where `fallocate` passes through to the lower
filesystem.

The useful next step is a differential: run this on the failing BAH-W09 and on the
working FDR-A05L. Identical matrices rule storage out for that report as well; a
difference — most plausibly `fallocate`, if one device serves emulated storage
from sdcardfs and the other from FUSE — is the thing to chase.
