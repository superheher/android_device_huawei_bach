#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2023 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#
# bach LineageOS 18.1 (Android 11) — system+boot only.
# The tablet keeps its existing LOS 17.1 /vendor (vndk 29) and 3.18 kernel
# (shipped prebuilt). Vendor-side packages return in the vendor-takeover phase.
#

VENDOR_PATH := device/huawei/bach

# Overlays
DEVICE_PACKAGE_OVERLAYS += \
    $(VENDOR_PATH)/overlay \
    $(VENDOR_PATH)/overlay-lineage

# AAPT
PRODUCT_CHARACTERISTICS := tablet
PRODUCT_AAPT_CONFIG := normal large xlarge hdpi xhdpi
PRODUCT_AAPT_PREF_CONFIG := xhdpi

# Dalvik heap (3 GB device): set in device/huawei/bach/system.prop, which the build
# auto-appends to /system/build.prop. NOT via the standard dalvik-heap.mk inherit or
# PRODUCT_PROPERTY_OVERRIDES — those land in /vendor/build.prop on this tree, which the
# prebuilt A10 vendor.img overwrites, so ART would clamp to ~16 MB and heavy apps OOM.

# A13-on-legacy bridge
PRODUCT_SHIPPING_API_LEVEL := 25
PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false
PRODUCT_EXTRA_VNDK_VERSIONS := 29

# Soong namespace
PRODUCT_SOONG_NAMESPACES += \
    $(VENDOR_PATH)

# Shims for A10-era vendor blobs (loaded into processes via TARGET_LD_SHIM_LIBS)
PRODUCT_PACKAGES += \
    libshim_fps \
    libshim_cutils \
    libshim_hwlog \
    libshim_camera \
    libshim_ui

# OEM unlock reporting
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    ro.oem_unlock_supported=1

# Rotation on lockscreen (tablet)
PRODUCT_PROPERTY_OVERRIDES += \
    lockscreen.rot_override=true

# VNDK-29 vendor runs old HALs; keep AOSP vendor-allowed property space sane
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    ro.vendor.qti.va_aosp.support=1

# Camera app (stock LOS camera too strict for this HAL)
PRODUCT_PACKAGES += \
    OpenCamera
