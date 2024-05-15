#!/bin/bash

# Author: Carl Kittelberger <icedream@icedream.pw>

set -e
set -u
set -o pipefail

. ./func.sh

# args: outputfile blocksize blockcount label

outputfile="$1"
shift 1

ensure_mount() {
    IFS="$mount_delimiter" read -r boot_mount_method boot_mount_path boot_mount_extra < <(
        mount_noroot "$outputfile"
    )
}

cleanup_mount() {
    unmount_noroot "$boot_mount_method" "$boot_mount_path" "$boot_mount_extra"
    boot_mount_method=
    boot_mount_path=
    boot_mount_extra=
}

UPDATE_TIMESTAMP_FILENAME=".sys_update_time"
UPDATE_TIMESTAMP="0.0 0.0"

TMP_CONFIG="$(mktemp -d)"
trap 'rm -rf "$TMP_CONFIG"' EXIT
[ ! -f "${TMP_CONFIG}"/system.map.key ] || rm -f "${TMP_CONFIG}"/system.map.key
[ ! -f "${TMP_CONFIG}"/smb.conf ] || rm -f "${TMP_CONFIG}"/smb.conf
[ ! -f "${TMP_CONFIG}"/smb.conf.cksum ] || rm -f "${TMP_CONFIG}"/smb.conf.cksum
/bin/echo "$UPDATE_TIMESTAMP" >"${TMP_CONFIG}/$UPDATE_TIMESTAMP_FILENAME"

[ -f "${TMP_CONFIG}"/uLinux.conf ] || cat uLinux.conf >"${TMP_CONFIG}"/uLinux.conf

NAS_CONFIG="$outputfile"
NAS_CONFIG_IMG="$outputfile"
NAS_CONFIG_SIZE=4096
if [ ! -f "$outputfile" ]; then
    dd \
        if=/dev/zero \
        of="$NAS_CONFIG_IMG" \
        bs=1k \
        count="$NAS_CONFIG_SIZE"
fi
mke2fs -F -v -m0 -b 1024 -I 128 -d "${TMP_CONFIG}" "$NAS_CONFIG_IMG"
/sbin/tune2fs -i 0 -c 0 "${NAS_CONFIG}"
