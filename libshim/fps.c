/*
 * Copyright (C) 2015 The CyanogenMod Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

void _ZN7android16IKeystoreService11asInterfaceERKNS_2spINS_7IBinderEEE()
{
    return;
}

/*
 * Huawei liblog power-logging extension imported by the closed
 * fingerprint.msm8937.so blob; absent from AOSP liblog, so the fps_hal
 * process crash-loops with "cannot locate symbol __android_logPower_print".
 * It is diagnostic-only, so a no-op stub satisfies the dynamic linker and
 * lets the fingerprint HAL load and run.
 */
int __android_logPower_print(int prio, const char* tag, const char* fmt, ...)
{
    (void)prio;
    (void)tag;
    (void)fmt;
    return 0;
}



