#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2018 The LineageOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

VENDOR_PATH := device/huawei/bach

TARGET_KERNEL_VERSION := 3.18

# Bootloader
TARGET_BOOTLOADER_BOARD_NAME := MSM8937
TARGET_NO_BOOTLOADER := true

# Platform
TARGET_BOARD_PLATFORM := msm8937
TARGET_BOARD_PLATFORM_GPU := qcom-adreno505
BUILD_BROKEN_DUP_RULES := true

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := cortex-a53

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a53

TARGET_USES_64_BIT_BINDER := true
TARGET_BOARD_SUFFIX := _64

# Assert
TARGET_OTA_ASSERT_DEVICE := bach,bah,BAH,CPN,cpn,msm8937,HwBAH-Q,HWCPN-Q

# ANT+
BOARD_ANT_WIRELESS_DEVICE := "vfs-prerelease"

# Audio
AUDIO_FEATURE_ENABLED_AAC_ADTS_OFFLOAD := true
AUDIO_FEATURE_ENABLED_ANC_HEADSET := true
AUDIO_FEATURE_ENABLED_ALAC_OFFLOAD := true
AUDIO_FEATURE_ENABLED_APE_OFFLOAD  := true
AUDIO_FEATURE_ENABLED_COMPRESS_VOIP := true
AUDIO_FEATURE_ENABLED_CUSTOMSTEREO := true
AUDIO_FEATURE_ENABLED_DEV_ARBI := true
AUDIO_FEATURE_ENABLED_EXTENDED_COMPRESS_FORMAT := true
AUDIO_FEATURE_ENABLED_EXTN_FORMATS := true
AUDIO_FEATURE_ENABLED_FM_POWER_OPT := true
AUDIO_FEATURE_ENABLED_FLAC_OFFLOAD := true
AUDIO_FEATURE_ENABLED_FLUENCE := true
AUDIO_FEATURE_ENABLED_HFP := true
AUDIO_FEATURE_ENABLED_KPI_OPTIMIZE := true
AUDIO_FEATURE_ENABLED_MULTI_VOICE_SESSIONS := true
AUDIO_FEATURE_ENABLED_PCM_OFFLOAD := true
AUDIO_FEATURE_ENABLED_PCM_OFFLOAD_24 := true
AUDIO_FEATURE_ENABLED_PROXY_DEVICE := true
AUDIO_FEATURE_ENABLED_VORBIS_OFFLOAD := true
AUDIO_FEATURE_ENABLED_WMA_OFFLOAD  := true
AUDIO_FEATURE_ENABLED_EXT_AMPLIFIER := false
AUDIO_FEATURE_ENABLED_SND_MONITOR := true
TARGET_USES_QCOM_MM_AUDIO := true
AUDIO_USE_LL_AS_PRIMARY_OUTPUT := true
BOARD_SUPPORTS_SOUND_TRIGGER := true
BOARD_USES_ALSA_AUDIO := true
USE_XML_AUDIO_POLICY_CONF := 1

AUDIO_FEATURE_ENABLED_SOURCE_TRACKING := true
AUDIO_FEATURE_ENABLED_AUDIOSPHERE := true
# AUDIO_FEATURE_ENABLED_DS2_DOLBY_DAP := true
AUDIO_FEATURE_ENABLED_SSR := true
#AUDIO_FEATURE_ENABLED_DTS_EAGLE := true

TARGET_ENABLE_QC_AV_ENHANCEMENTS := true

# Bluetooth
BOARD_BLUETOOTH_BDROID_BUILDCFG_INCLUDE_DIR := $(VENDOR_PATH)/bluetooth
BLUETOOTH_HCI_USE_MCT := true
QCOM_BT_USE_SMD_TTY := true

# Camera
BOARD_QTI_CAMERA_32BIT_ONLY := true
USE_DEVICE_SPECIFIC_CAMERA := true
TARGET_USES_QTI_CAMERA_DEVICE := true
TARGET_USES_QTI_CAMERA2CLIENT := true
# ThunderSoft face-beautify (libts_*_hal) are prebuilt blobs not declared as
# build modules; disabled for the A11 from-source HAL build (non-essential).
TARGET_TS_MAKEUP := false
# A11 from-source HAL: build camera3 (HAL3) path only — the camera2 framework/app
# uses device@3.x; HAL1 is a large extra surface (legacy API1) deferred for now.
TARGET_SUPPORT_HAL1 := false
TARGET_PROCESS_SDK_VERSION_OVERRIDE := \
	/vendor/bin/mm-qcamera-daemon=24

# Charger
BOARD_CHARGER_DISABLE_INIT_BLANK := true
BOARD_CHARGER_ENABLE_SUSPEND := true
BACKLIGHT_PATH := /sys/class/leds/lcd-backlight/brightness
BOARD_HEALTHD_CUSTOM_CHARGER_RES := $(VENDOR_PATH)/charger/images

# Cne
BOARD_USES_QCNE := true

# Display
TARGET_SCREEN_DENSITY := 320

# DRM
TARGET_ENABLE_MEDIADRM_64 := true

# Encryption
TARGET_PROVIDES_KEYMASTER := true
TARGET_HW_DISK_ENCRYPTION := true

# Filesystem
TARGET_FS_CONFIG_GEN := $(VENDOR_PATH)/prebuilts/config.fs

# GPS
USE_DEVICE_SPECIFIC_GPS := true
BOARD_VENDOR_QCOM_GPS_LOC_API_HARDWARE := default
LOC_HIDL_VERSION := 3.0

# GPU
TARGET_ADDITIONAL_GRALLOC_10_USAGE_BITS ?= 0
TARGET_ADDITIONAL_GRALLOC_10_USAGE_BITS += | (1 << 21)
TARGET_USES_COLOR_METADATA := true
MAX_EGL_CACHE_KEY_SIZE := 12*1024
MAX_EGL_CACHE_SIZE := 2048*1024
MAX_VIRTUAL_DISPLAY_DIMENSION := 4096
OVERRIDE_RS_DRIVER := libRSDriver_adreno.so
TARGET_FORCE_HWC_FOR_VIRTUAL_DISPLAYS := true
TARGET_USES_GRALLOC1 := true
TARGET_USES_HWC2 := true
TARGET_USES_ION := true
TARGET_USES_NEW_ION_API :=true
TARGET_USES_C2D_COMPOSITION := true
TARGET_CONTINUOUS_SPLASH_ENABLED := true
BOARD_USES_ADRENO := true

# HIDL
DEVICE_FRAMEWORK_MANIFEST_FILE := $(VENDOR_PATH)/prebuilts/framework_manifest.xml
DEVICE_MANIFEST_FILE := $(VENDOR_PATH)/prebuilts/manifest.xml
DEVICE_MATRIX_FILE := $(VENDOR_PATH)/prebuilts/compatibility_matrix.xml

# Init
# libinit_bach disabled for build #1 (A10-era API)

# Kernel
BOARD_KERNEL_BASE := 0x80000000
BOARD_KERNEL_PAGESIZE := 2048
BOARD_KERNEL_CMDLINE := androidboot.hardware=qcom ehci-hcd.park=3 androidboot.bootdevice=7824900.sdhci lpm_levels.sleep_disabled=1 slub_min_objects=12 androidboot.selinux=permissive
BOARD_KERNEL_CMDLINE += loop.max_part=7
BOARD_MKBOOTIMG_ARGS := --kernel_offset 0x00008000 --ramdisk_offset 0x01000000
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb
# Build #1: prebuilt kernel from surdu's LOS17 boot.img (source build comes later)
TARGET_PREBUILT_KERNEL := device/huawei/bach/prebuilt/Image.gz-dtb
TARGET_NO_KERNEL := false
# Kernel source (symlinked at kernel/huawei/bach -> los20/kernel-src) is present
# so the camera stack can pull generated_kernel_headers (msm camera UAPI). This
# drives defconfig + headers_install; the boot image still uses the prebuilt above.
TARGET_KERNEL_CONFIG := bach_defconfig

# Malloc
MALLOC_SVELTE := true

# Media
BOARD_SECCOMP_POLICY := $(VENDOR_PATH)/seccomp
TARGET_USES_MEDIA_EXTENSIONS := true

# Partitions
BOARD_BOOTIMAGE_PARTITION_SIZE     := 83886080
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_CACHEIMAGE_PARTITION_SIZE    := 268435456
BOARD_FLASH_BLOCK_SIZE := 131072
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 83886080
BOARD_SYSTEMIMAGE_PARTITION_SIZE   := 3154116608
BOARD_USERDATAIMAGE_PARTITION_SIZE := 25732005376 #(25732038144 - 32768 )
BOARD_VENDORIMAGE_PARTITION_SIZE   := 771751936
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
TARGET_COPY_OUT_VENDOR := vendor
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

# Power
TARGET_USES_INTERACTION_BOOST := true

# Qualcomm support
BOARD_USES_QCOM_HARDWARE := true

# Recovery
TARGET_RECOVERY_FSTAB := $(VENDOR_PATH)/rootdir/fstab.qcom

# RIL
TARGET_PROVIDES_QTI_TELEPHONY_JAR := true
TARGET_USES_OLD_MNC_FORMAT := true

# Root (build2: restored WITH rootfs labels via sepolicy/buildfix/file_contexts.
# In build1 these were stripped because they were unlabeled in the system file_contexts
# (bach vendor sepolicy dropped) → e2fsdroid "searching for label /cust" then /firmware.)
BOARD_ROOT_EXTRA_FOLDERS += \
    cust \
    log \
    persist \
    produce \
    version
BOARD_ROOT_EXTRA_SYMLINKS += \
    /vendor/firmware_mnt:/firmware \
    /mnt/vendor/persist:/persist \
    /vendor/dsp:/dsp

# ---- Android 11 (LOS18.1) forward-port ----
BOARD_VNDK_VERSION := current
BOARD_SHIPPING_API_LEVEL := 25
PRODUCT_FULL_TREBLE_OVERRIDE := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_USES_BUILD_COPY_HEADERS := true
# system+boot only: existing device vendor (A10, vndk29) stays untouched
# ---------------------------------------------

# bach: force ro.zygote=zygote64_32 into /system/build.prop (the build didn't emit it;
# without it init imports nothing for zygote → boot hangs at the LOS animation forever).
TARGET_SYSTEM_PROP := device/huawei/bach/system.prop

# SELinux
include device/qcom/sepolicy-legacy-um/SEPolicy.mk
# build2: minimal private sepolicy dir = ONLY file_contexts (rootfs labels for the bach
# root mount points). No .te, so it avoids the gallery_app types that got the old private
# dir dropped. Lets e2fsdroid label /cust,/firmware,/dsp,/persist,/log,/produce,/version.
# A11 (lineage-18.1) uses BOARD_PLAT_PRIVATE_SEPOLICY_DIR (renamed to
# SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS only in A12+); system/sepolicy/Android.mk maps it to
# SYSTEM_EXT_PRIVATE_POLICY. Append our file_contexts-only buildfix dir.
BOARD_PLAT_PRIVATE_SEPOLICY_DIR += device/huawei/bach/sepolicy/buildfix
# build1: private sepolicy dropped (gallery_app & co. not in LOS20)
# build1: bach vendor sepolicy dropped (LOS17-internal types; device keeps its own vendor-partition policy)
SELINUX_IGNORE_NEVERALLOWS := true

# Shims (vendor-lib only). NOTE: the LOS linker injects shims per-NAMESPACE at load
# time (bionic/linker/linker.cpp, -DLD_SHIM_LIBS). Shimming a SYSTEM lib that loads in
# many namespaces (libcutils, libui) is fatal on this GSI-style A11 port: restricted
# APEX namespaces (e.g. com_android_adbd) can't see /system/lib*/libshim_*.so, so
# system_server died at SystemServer.run() loading libandroid_servers -> libcutils.
# Those system shims only served Huawei vendor blobs, which use VNDK libcutils/libui
# (not /system), so they were useless here AND crashed boot. Removed 2026-06-15.
TARGET_LD_SHIM_LIBS += \
    /vendor/lib64/hw/fingerprint.hw.ex.so|libshim_fps.so \
    /vendor/lib64/hw/fingerprint.msm8937.so|libshim_fps.so \
    /vendor/lib/libmmcamera_ppeiscore.so|libshim_camera.so \
    /vendor/lib/libhwlog.so|libshim_hwlog.so \
    /vendor/lib64/libhwlog.so|libshim_hwlog.so

# Thermal
TARGET_USES_CUSTOM_THERMAL := true

# Vendor Security patch level
VENDOR_SECURITY_PATCH := 2021-06-05

# Vold
TARGET_USE_CUSTOM_LUN_FILE_PATH := /sys/devices/soc/78db000.usb/msm_hsusb/gadget/lun%d/file

# WiFi
ENABLE_VENDOR_IMAGE := true
BOARD_HAS_QCOM_WLAN := true
BOARD_HOSTAPD_DRIVER := NL80211
BOARD_HOSTAPD_PRIVATE_LIB := lib_driver_cmd_qcwcn
BOARD_WLAN_DEVICE := qcwcn
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_WPA_SUPPLICANT_PRIVATE_LIB := lib_driver_cmd_qcwcn
PRODUCT_VENDOR_MOVE_ENABLED := true
TARGET_DISABLE_WCNSS_CONFIG_COPY := true
WIFI_DRIVER_FW_PATH_AP := "ap"
WIFI_DRIVER_FW_PATH_STA := "sta"
WIFI_HIDL_FEATURE_DISABLE_AP_MAC_RANDOMIZATION := true
WPA_SUPPLICANT_VERSION := VER_0_8_X

# Inherit the common proprietary files
-include vendor/huawei/bach/BoardConfigVendor.mk
