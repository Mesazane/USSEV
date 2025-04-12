MODEL=$(echo -n "$TARGET_FIRMWARE" | cut -d "/" -f 1)
REGION=$(echo -n "$TARGET_FIRMWARE" | cut -d "/" -f 2)

# S25 Ultra OneUI 7 -> SoundBooster 2060
# S20 Series -> SoundBooster 1050
echo "Replacing SoundBooster"
DELETE_FROM_WORK_DIR "system" "system/lib64/lib_SoundBooster_ver2060.so"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/lib_SoundBooster_ver1050.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/libsamsungSoundbooster_plus_legacy.so" 0 0 644 "u:object_r:system_lib_file:s0"

echo "Replacing GameDriver"
DELETE_FROM_WORK_DIR "system" "system/priv-app/GameDriver-SM8750"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/priv-app/GameDriver-EX9830/GameDriver-EX9830.apk" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/priv-app/DevGPUDriver-EX9830/DevGPUDriver-EX9830.apk" 0 0 644 "u:object_r:system_file:s0"

echo "Replacing Hotword"
DELETE_FROM_WORK_DIR "product" "priv-app/HotwordEnrollmentXGoogleEx6_WIDEBAND_LARGE"
DELETE_FROM_WORK_DIR "product" "priv-app/HotwordEnrollmentYGoogleEx6_WIDEBAND_LARGE"
if [ -d "$FW_DIR/${MODEL}_${REGION}/system/system/app/HotwordEnrollmentOKGoogleEx3CORTEXM4" ]; then
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "product" "priv-app/HotwordEnrollmentOKGoogleEx3CORTEXM4/HotwordEnrollmentOKGoogleEx3CORTEXM4.apk" 0 0 644 "u:object_r:system_file:s0"
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "product" "priv-app/HotwordEnrollmentXGoogleEx3CORTEXM4/HotwordEnrollmentXGoogleEx3CORTEXM4.apk" 0 0 644 "u:object_r:system_file:s0"
fi

echo "Downgrading VaultKeeper JNI"
ADD_TO_WORK_DIR "dm3qxxx" "system" "system/lib64/libvkjni.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "dm3qxxx" "system" "system/lib64/libvkmanager.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "dm3qxxx" "system" "system/lib64/vendor.samsung.hardware.security.vaultkeeper@2.0.so" 0 0 644 "u:object_r:system_lib_file:s0"
DELETE_FROM_WORK_DIR "system" "system/lib64/vendor.samsung.hardware.security.vaultkeeper-V1-ndk.so"
