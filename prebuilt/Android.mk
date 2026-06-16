# Discover prebuilt modules nested under prebuilt/ (e.g. OpenCamera).
# The device-root Android.mk uses all-makefiles-under, which only scans one
# level deep, so prebuilt/<module>/Android.mk would otherwise be missed.
LOCAL_PATH := $(call my-dir)
include $(call all-makefiles-under,$(LOCAL_PATH))
