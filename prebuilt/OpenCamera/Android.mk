# Open Camera (FOSS, GPLv3) — the camera app on bach. The stock LineageOS camera app
# is too strict for bach's A8.1/A10 HAL (won't preview), so Open Camera replaces it:
# LOCAL_OVERRIDES_PACKAGES drops the stock camera from the build, leaving Open Camera
# as the sole (and therefore default) camera for all camera intents.
LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)
LOCAL_MODULE := OpenCamera
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := APPS
LOCAL_MODULE_SUFFIX := $(COMMON_ANDROID_PACKAGE_SUFFIX)
# Install to system_ext (same partition as the stock Camera2 priv-app) so
# LOCAL_OVERRIDES_PACKAGES reliably drops it.
LOCAL_SYSTEM_EXT_MODULE := true
LOCAL_SRC_FILES := OpenCamera.apk
LOCAL_CERTIFICATE := PRESIGNED
LOCAL_DEX_PREOPT := false
LOCAL_OVERRIDES_PACKAGES := Snap Camera2 Aperture
include $(BUILD_PREBUILT)
