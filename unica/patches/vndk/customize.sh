if [[ "$SOURCE_VNDK_VERSION" != "$TARGET_VNDK_VERSION" ]]; then
    if $TARGET_HAS_SYSTEM_EXT; then
        SYS_EXT_DIR="$WORK_DIR/system_ext"
    else
        SYS_EXT_DIR="$WORK_DIR/system/system/system_ext"
    fi

    NO_APEX=false
    [[ $SOURCE_VNDK_VERSION == "none" ]] && NO_APEX=true

    if [ ! -f "$SYS_EXT_DIR/apex/com.android.vndk.v$TARGET_VNDK_VERSION.apex" ]; then
        if ! $NO_APEX; then
            DELETE_FROM_WORK_DIR "system_ext" "apex/com.android.vndk.v$SOURCE_VNDK_VERSION.apex"
        fi

        case "$TARGET_VNDK_VERSION" in
            "30")
                ADD_TO_WORK_DIR "a73xqxx" "system_ext" "apex/com.android.vndk.v30.apex" 0 0 644 "u:object_r:system_file:s0"
                ;;
            "31")
                ADD_TO_WORK_DIR "r11sxxx" "system_ext" "apex/com.android.vndk.v31.apex" 0 0 644 "u:object_r:system_file:s0"
                ;;
            "33")
                ADD_TO_WORK_DIR "dm3qxxx" "system_ext" "apex/com.android.vndk.v33.apex" 0 0 644 "u:object_r:system_file:s0"
                ;;
            "34")
                ADD_TO_WORK_DIR "r12sxxx" "system_ext" "apex/com.android.vndk.v34.apex" 0 0 644 "u:object_r:system_file:s0"
                ;;
        esac
        if $NO_APEX; then
            sed -i '$d' "$SYS_EXT_DIR/etc/vintf/manifest.xml"
            echo "    <vendor-ndk>" >> "$SYS_EXT_DIR/etc/vintf/manifest.xml"
            echo "        <version>$TARGET_VNDK_VERSION</version>" >> "$SYS_EXT_DIR/etc/vintf/manifest.xml"
            echo "    </vendor-ndk>" >> "$SYS_EXT_DIR/etc/vintf/manifest.xml"
            echo "</manifest>" >> "$SYS_EXT_DIR/etc/vintf/manifest.xml"
        else
            sed -i "s/version>$SOURCE_VNDK_VERSION/version>$TARGET_VNDK_VERSION/g" "$SYS_EXT_DIR/etc/vintf/manifest.xml"
        fi
    else
        echo "VNDK v$TARGET_VNDK_VERSION apex is already in place. Ignoring"
    fi
else
    echo "SOURCE_VNDK_VERSION and TARGET_VNDK_VERSION are the same. Ignoring"
fi
