# [
KERNELSU_ZIP="https://github.com/ExtremeXT/990_upstream_v2/releases/download/v0.5/ExtremeKRNL-Nexus-${TARGET_CODENAME}.zip"
KERNELSU_MANAGER_APK="https://github.com/KernelSU-Next/KernelSU-Next/releases/download/v1.0.5/KernelSU_Next_v1.0.5_12430-release.apk"

REPLACE_KERNEL_BINARIES()
{
    [ -d "$TMP_DIR" ] && rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR"

    echo "Downloading $(basename "$KERNELSU_ZIP")"
    curl -L -s -o "$TMP_DIR/krnl.zip" "$KERNELSU_ZIP"

    echo "Extracting kernel binaries"
    rm -f "$WORK_DIR/kernel/"*.img
    unzip -q -j "$TMP_DIR/krnl.zip" \
        "files/boot.img" "files/dtbo.img" \
        -d "$WORK_DIR/kernel"

    rm -rf "$TMP_DIR"
}

ADD_MANAGER_APK_TO_PRELOAD()
{
    # https://github.com/tiann/KernelSU/issues/886
    local APK_PATH="system/preload/KernelSU-Next/com.rifsxd.ksunext-mesa==/base.apk"

    echo "Adding KernelSU-Next.apk to preload apps"
    mkdir -p "$WORK_DIR/system/$(dirname "$APK_PATH")"
    curl -L -s -o "$WORK_DIR/system/$APK_PATH" -z "$WORK_DIR/system/$APK_PATH" "$KERNELSU_MANAGER_APK"

    sed -i "/system\/preload/d" "$WORK_DIR/configs/fs_config-system" \
        && sed -i "/system\/preload/d" "$WORK_DIR/configs/file_context-system"
    while read -r i; do
        FILE="$(echo -n "$i"| sed "s.$WORK_DIR/system/..")"
        [ -d "$i" ] && echo "$FILE 0 0 755 capabilities=0x0" >> "$WORK_DIR/configs/fs_config-system"
        [ -f "$i" ] && echo "$FILE 0 0 644 capabilities=0x0" >> "$WORK_DIR/configs/fs_config-system"
        FILE="$(echo -n "$FILE" | sed 's/\./\\./g')"
        echo "/$FILE u:object_r:system_file:s0" >> "$WORK_DIR/configs/file_context-system"
    done <<< "$(find "$WORK_DIR/system/system/preload")"

    rm -f "$WORK_DIR/system/system/etc/vpl_apks_count_list.txt"
    while read -r i; do
        FILE="$(echo "$i" | sed "s.$WORK_DIR/system..")"
        echo "$FILE" >> "$WORK_DIR/system/system/etc/vpl_apks_count_list.txt"
    done <<< "$(find "$WORK_DIR/system/system/preload" -name "*.apk" | sort)"
}
# ]

REPLACE_KERNEL_BINARIES
ADD_MANAGER_APK_TO_PRELOAD
