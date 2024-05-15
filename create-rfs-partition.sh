#!/bin/bash

# Author: Carl Kittelberger <icedream@icedream.pw>

set -e
set -u
set -o pipefail

. ./func.sh

# args: outputfile blocksize blockcount label

outputfile="$1"
blocksize="$2"
blocks="$3"
label="$4"
UPDATE_FOLDER="$5"
shift 5

uuid=""

# NOTE - hardcode uuid since we're copying the bootloader/GRUB as-is atm
case "$label" in
QTS_BOOT_PART2)
    uuid=a68e1b7f-1818-458a-9c4d-c2abc2fd0650
    ;;
QTS_BOOT_PART3)
    uuid=b19a7dcb-81eb-4f82-b941-a0c703868b0b
    ;;
esac

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

if [ ! -f "$outputfile" ]; then
    dd \
        if=/dev/zero \
        of="$outputfile" \
        bs="$blocksize" \
        count="$blocks"
fi

FLASH_RFS1_MP="$(mktemp -d)"
trap 'rm -rf "${FLASH_RFS1_MP}"' EXIT
[ -d "${FLASH_RFS1_MP}"/boot ] || unshare -uimr /bin/mkdir "${FLASH_RFS1_MP}"/boot
[ -f "${UPDATE_FOLDER}"/bzImage ] && unshare -uimr /bin/cp "${UPDATE_FOLDER}"/bzImage* "${FLASH_RFS1_MP}"/boot
[ -f "${UPDATE_FOLDER}"/initrd.boot ] && unshare -uimr /bin/cp "${UPDATE_FOLDER}"/initrd.boot* "${FLASH_RFS1_MP}"/boot
[ -f "${UPDATE_FOLDER}"/rootfs2.bz ] && unshare -uimr /bin/cp "${UPDATE_FOLDER}"/rootfs2.bz* "${FLASH_RFS1_MP}"/boot
[ -f "${UPDATE_FOLDER}"/rootfs_ext.tgz ] && unshare -uimr /bin/cp "${UPDATE_FOLDER}"/rootfs_ext.tgz* "${FLASH_RFS1_MP}"/boot
if [ $((blocks * blocksize)) -gt $((484608 * 512)) ] &&
    [ -f "${UPDATE_FOLDER}"/qpkg.tar ]; then
    # TODO - check if enough space for this
    unshare -uimr /bin/cp "${UPDATE_FOLDER}"/qpkg.tar* "${FLASH_RFS1_MP}"/boot
    unshare -uimr touch "${UPDATE_FOLDER}"/update_qpkg_f
fi

mke2fs -m0 -F -b 1024 -I 128 -L "$label" -U "$uuid" -d "${FLASH_RFS1_MP}" "$@" "$outputfile"
