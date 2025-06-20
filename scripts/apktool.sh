#!/usr/bin/env bash
#
# Copyright (C) 2023 Salvo Giangreco
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

set -eu
shopt -s nullglob

# [
PRINT_USAGE()
{
    echo "Usage: apktool d[ecode]/b[uild] <apk> (<apk>...)"
    echo "- APK/JAR path MUST not be full and match an existing file inside work_dir"
    echo "- Output files will be stored in ($APKTOOL_DIR)"
    echo "- Recompiled apk will be copied back to its original directory"
}

REMOVE_FROM_WORK_DIR()
{
    local FILE_PATH="$1"

    if [ -e "$FILE_PATH" ]; then
        local FILE
        local PARTITION
        FILE="$(echo -n "$FILE_PATH" | sed "s.$WORK_DIR/..")"
        PARTITION="$(echo -n "$FILE" | cut -d "/" -f 1)"

        echo "Debloating /$FILE"
        rm -rf "$FILE_PATH"

        FILE="$(echo -n "$FILE" | sed 's/\//\\\//g')"
        sed -i "/$FILE/d" "$WORK_DIR/configs/fs_config-$PARTITION"

        FILE="$(echo -n "$FILE" | sed 's/\./\\./g')"
        sed -i "/$FILE/d" "$WORK_DIR/configs/file_context-$PARTITION"
    fi
}

DEX_TO_API()
{
    local DEX_FILE="$1"
    local API
    local DEX_VERSION

    DEX_VERSION="$(xxd -p -l "1" --skip "6" "$DEX_FILE")"

    case "$DEX_VERSION" in
        "35")
            API="23"
            ;;
        "37")
            API="25"
            ;;
        "38")
            API="27"
            ;;
        "39")
            API="29"
            ;;
        "40")
            API="34"
            ;;
        "41")
            API="35"
            ;;
        *)
            echo "Unknown DEX format version ($DEX_VERSION). Aborting"
            exit 1
            ;;
    esac

    echo "$API"
}

DO_DECOMPILE()
{
    local OUT_DIR="$1"
    local APK_PATH
    local DEX_API_LEVEL
    local SMALI_OUT

    [[ "$OUT_DIR" != "/"* ]] && OUT_DIR="/$OUT_DIR"

    case "$OUT_DIR" in
        "/system/system_ext/"*)
            if $TARGET_HAS_SYSTEM_EXT; then
                APK_PATH="$WORK_DIR$(echo "$OUT_DIR" | sed 's/\/system\/system_ext/\/system_ext/')"
            else
                APK_PATH="$WORK_DIR/system$OUT_DIR"
            fi
            OUT_DIR="$(echo "$OUT_DIR" | sed 's/\/system\/system_ext/\/system_ext/')"
        ;;
        "/system_ext/"*)
            if $TARGET_HAS_SYSTEM_EXT; then
                APK_PATH="$WORK_DIR$OUT_DIR"
            else
                APK_PATH="$WORK_DIR/system/system$OUT_DIR"
            fi
            ;;
        "/system/system/"*)
            APK_PATH="$WORK_DIR$OUT_DIR"
            OUT_DIR="$(echo "$OUT_DIR" | sed 's/\/system\/system/\/system/')"
            ;;
        "/system/"*)
            APK_PATH="$WORK_DIR/system$OUT_DIR"
            ;;
        "/odm/"* | "/product/"* | "/system_dlkm/"* | "/vendor/"* | "/vendor_dlkm/"*)
            APK_PATH="$WORK_DIR$OUT_DIR"
            ;;
        *)
            echo "Unvalid path: $OUT_DIR"
            return 1
            ;;
    esac

    if [ ! -f "$APK_PATH" ]; then
        echo "File not found: $OUT_DIR"
        return 1
    elif [[ "$(xxd -p -l "4" "$APK_PATH")" != "504b0304" ]]; then
        echo "File not valid: $OUT_DIR"
        return 1
    fi

    echo "Decompiling $OUT_DIR"
    if [[ "$APK_PATH" == *rro_*.apk ]]; then
        apktool d -q $FORCE -o "$APKTOOL_DIR$OUT_DIR" -p "$FRAMEWORK_DIR" -s "$APK_PATH"
    else
        apktool d -q $FORCE -o "$APKTOOL_DIR$OUT_DIR" -p "$FRAMEWORK_DIR" -r -s "$APK_PATH"
    fi

    for f in "$APKTOOL_DIR$OUT_DIR/"*.dex
    do
        DEX_API_LEVEL="$(DEX_TO_API "$f")"
        echo -n "$DEX_API_LEVEL" > "$APKTOOL_DIR$OUT_DIR/../dex_api_version"

        if [[ "$f" == *"classes.dex" ]]; then
            SMALI_OUT="smali"
        else
            SMALI_OUT="smali_$(basename "${f//.dex/}")"
        fi

        baksmali d -a "$DEX_API_LEVEL" --ac false --di false -l -o "$APKTOOL_DIR$OUT_DIR/$SMALI_OUT" --sl "$f"
        rm "$f"
    done

    # Workaround for U framework.jar
    if [[ "$APK_PATH" == *"framework.jar" ]]; then
        if unzip -l "$APK_PATH" | grep -q "debian.mime.types"; then
            unzip -q "$APK_PATH" "res/*" -d "$APKTOOL_DIR$OUT_DIR/unknown"
        fi
    fi
}

DO_RECOMPILE()
{
    local IN_DIR="$1"
    local APK_PATH
    local APK_NAME
    local DEX_FILENAME

    [[ "$IN_DIR" != "/"* ]] && IN_DIR="/$IN_DIR"

    case "$IN_DIR" in
        "/system/system_ext/"*)
            if $TARGET_HAS_SYSTEM_EXT; then
                APK_PATH="$WORK_DIR$(echo "$IN_DIR" | sed 's/\/system\/system_ext/\/system_ext/')"
            else
                APK_PATH="$WORK_DIR/system$IN_DIR"
            fi
            IN_DIR="$(echo "$IN_DIR" | sed 's/\/system\/system_ext/\/system_ext/')"
        ;;
        "/system_ext/"*)
            if $TARGET_HAS_SYSTEM_EXT; then
                APK_PATH="$WORK_DIR$IN_DIR"
            else
                APK_PATH="$WORK_DIR/system/system$IN_DIR"
            fi
            ;;
        "/system/system/"*)
            APK_PATH="$WORK_DIR$IN_DIR"
            IN_DIR="$(echo "$IN_DIR" | sed 's/\/system\/system/\/system/')"
            ;;
        "/system/"*)
            APK_PATH="$WORK_DIR/system$IN_DIR"
            ;;
        "/odm/"* | "/product/"* | "/system_dlkm/"* | "/vendor/"* | "/vendor_dlkm/"*)
            APK_PATH="$WORK_DIR$IN_DIR"
            ;;
        *)
            echo "Unvalid path: $IN_DIR"
            return 1
            ;;
    esac

    if [ ! -d "$APKTOOL_DIR$IN_DIR" ]; then
        echo "Folder not found: $IN_DIR"
        return 1
    fi

    APK_NAME="$(basename "$APK_PATH")"

    echo "Recompiling $IN_DIR"

    for f in "$APKTOOL_DIR$IN_DIR/"*
    do
        [[ "$f" != *"smali"* ]] && continue

        if [[ "$f" == *"smali" ]]; then
            DEX_FILENAME="classes.dex"
        else
            DEX_FILENAME="$(basename "${f/smali_//}").dex"
        fi

        smali a -a "$(cat "$APKTOOL_DIR$IN_DIR/../dex_api_version")" -o "$APKTOOL_DIR$IN_DIR/$DEX_FILENAME" "$f"
    done

    mkdir -p "$APKTOOL_DIR$IN_DIR/build/apk"
    cp -a --preserve=all "$APKTOOL_DIR$IN_DIR/original/META-INF" "$APKTOOL_DIR$IN_DIR/build/apk/META-INF"
    apktool b -q -p "$FRAMEWORK_DIR" "$APKTOOL_DIR$IN_DIR"
    [[ -f "$APKTOOL_DIR$IN_DIR/classes.dex" ]] && rm "$APKTOOL_DIR$IN_DIR/"*.dex

    echo "Zipaligning $IN_DIR"
    zipalign -p 4 "$APKTOOL_DIR$IN_DIR/dist/$APK_NAME" "$APKTOOL_DIR$IN_DIR/dist/temp" \
        && mv -f "$APKTOOL_DIR$IN_DIR/dist/temp" "$APKTOOL_DIR$IN_DIR/dist/$APK_NAME"

    mv -f "$APKTOOL_DIR$IN_DIR/dist/$APK_NAME" "$APK_PATH"
    rm -rf "$APKTOOL_DIR$IN_DIR/build" && rm -rf "$APKTOOL_DIR$IN_DIR/dist"

    if [ -d "${APK_PATH%/*}/oat" ]; then
        REMOVE_FROM_WORK_DIR "${APK_PATH%/*}/oat"
    fi
    if [ -f "${APK_PATH%/*}/$APK_NAME.prof" ]; then
        REMOVE_FROM_WORK_DIR "${APK_PATH%/*}/$APK_NAME.prof"
    fi
    if [ -f "${APK_PATH%/*}/$APK_NAME.bprof" ]; then
        REMOVE_FROM_WORK_DIR "${APK_PATH%/*}/$APK_NAME.bprof"
    fi
}

FRAMEWORK_DIR="$APKTOOL_DIR/bin/fw"
# ]

if [ ! -d "$FRAMEWORK_DIR" ]; then
    if [ -f "$WORK_DIR/system/system/framework/framework-res.apk" ]; then
        echo "Set up apktool env"
        apktool if -q -p "$FRAMEWORK_DIR" "$WORK_DIR/system/system/framework/framework-res.apk"
    else
        echo "Please set up your work_dir first."
        exit 1
    fi
fi

if [ "$#" == 0 ]; then
    PRINT_USAGE
    exit 1
fi

DECOMPILE=false
RECOMPILE=true

case "$1" in
    "d" | "decode")
        DECOMPILE=true
        ;;
    "b" | "build")
        RECOMPILE=true
        ;;
    *)
        PRINT_USAGE
        exit 1
        ;;
esac

shift

FORCE=""

if [[ "$1" == "-f" ]]|| [[ "$1" == "--force" ]]; then
    FORCE="-f"
    shift
fi

if [ "$#" == 0 ]; then
    PRINT_USAGE
    exit 1
fi

while [ "$#" != 0 ]; do
    if $DECOMPILE; then
        DO_DECOMPILE "$1"
    elif $RECOMPILE; then
        DO_RECOMPILE "$1"
    else
        PRINT_USAGE
        exit 1
    fi
    shift
done

exit 0
