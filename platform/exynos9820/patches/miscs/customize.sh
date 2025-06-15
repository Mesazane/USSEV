echo "Enabling updateable APEX images"
SET_PROP "vendor" "ro.apex.updatable" "true"

echo "Enabling IncrementalFS"
SET_PROP "vendor" "ro.incremental.enable" "yes"

echo "Disabling A2DP Offload"
SET_PROP "system" persist.bluetooth.a2dp_offload.disabled "true"

echo "Setting SF flags"
SET_PROP "vendor" "debug.sf.latch_unsignaled" "1"
SET_PROP "vendor" "debug.sf.high_fps_late_app_phase_offset_ns" "0"
SET_PROP "vendor" "debug.sf.high_fps_late_sf_phase_offset_ns" "0"

echo "Disabling HFR"
SET_PROP "vendor" "debug.sf.show_refresh_rate_overlay_render_rate" "true"
SET_PROP "vendor" "ro.surface_flinger.game_default_frame_rate_override" "60"
SET_PROP "vendor" "ro.surface_flinger.enable_frame_rate_override" "false"
SET_PROP "vendor" "ro.surface_flinger.use_content_detection_for_refresh_rate" "false"

echo "Enable Vulkan"
SET_PROP "vendor" "ro.hwui.use_vulkan" "true"
SET_PROP "vendor" "debug.hwui.use_hint_manager" "true"

# Encryption
LINE="$(sed -n "/^\/dev\/block\/by-name\/userdata/=" "$WORK_DIR/vendor/etc/fstab.exynos9820")"

echo "Setting /data to F2FS"
OLD_FLAGS="noatime,nosuid,nodev,noauto_da_alloc,discard,journal_checksum,data=ordered,errors=panic"
NEW_FLAGS="noatime,nosuid,nodev,discard,usrquota,grpquota,fsync_mode=nobarrier,reserve_root=32768,resgid=5678"
sed -i "${LINE}s|ext4|f2fs|g" "$WORK_DIR/vendor/etc/fstab.exynos9820" \
    && sed -i "${LINE}s|$OLD_FLAGS|$NEW_FLAGS|g" "$WORK_DIR/vendor/etc/fstab.exynos9820"

echo "Switching to FBE v2"
FBE_V1="fileencryption=ice"
FBE_V2="fscompress,fileencryption=aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized,metadata_encryption=aes-256-xts,keydirectory=/metadata/vold/metadata_encryption"
sed -i "${LINE}s|resgid=5678|resgid=5678,inlinecrypt|g" "$WORK_DIR/vendor/etc/fstab.exynos9820" \
    && sed -i "${LINE}s|$FBE_V1|$FBE_V2|g" "$WORK_DIR/vendor/etc/fstab.exynos9820"

SET_PROP "vendor" "ro.crypto.allow_encrypt_override" --delete
SET_PROP "vendor" "ro.crypto.metadata_init_delete_all_keys.enabled" "true"
SET_PROP "vendor" "ro.crypto.dm_default_key.options_format.version" "2"
SET_PROP "vendor" "ro.crypto.volume.metadata.method" "dm-default-key"
SET_PROP "vendor" "ro.crypto.volume.options" "::v2"

# Samsung ODE
ENTRIES="
ODE
keydata
keyrefuge
"
for e in $ENTRIES; do
    sed -i "/${e}/d" "$WORK_DIR/vendor/etc/fstab.exynos9820"
done

# Add /metadata
echo "Adding /metadata in /vendor/etc/fstab.exynos9820"
MISC="/dev/block/by-name/misc\t/misc\temmc\tdefaults\tdefaults,first_stage_mount"
METADATA="/dev/block/by-name/by-name/metadata\t/metadata\text4\tnoatime,nosuid,nodev,noauto_da_alloc,discard,journal_checksum,data=ordered,errors=panic,sync\twait,first_stage_mount,formattable,check"

sed -i "\|${MISC}|a ${METADATA}" "$WORK_DIR/vendor/etc/fstab.exynos9820"

# For some reason we are missing 2 permissions here: android.hardware.security.model.compatible and android.software.controls
# First one is related to encryption and second one to SmartThings Device Control
echo "Patching vendor permissions"
sed -i '$d' "$WORK_DIR/vendor/etc/permissions/handheld_core_hardware.xml"
{
    echo ""
    echo "    <!-- Indicate support for the Android security model per the CDD. -->"
    echo "    <feature name=\"android.hardware.security.model.compatible\"/>"
    echo ""
    echo "    <!--  Feature to specify if the device supports controls.  -->"
    echo "    <feature name=\"android.software.controls\"/>"
    echo "</permissions>"
} >> "$WORK_DIR/vendor/etc/permissions/handheld_core_hardware.xml"
