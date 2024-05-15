#!/bin/bash

# Author: Carl Kittelberger <icedream@icedream.pw>

set -e
set -u
set -o pipefail

. ./func.sh

# args: outputfile blocksize blockcount label

outputfile="$1"
shift 1

TMP_CONFIG="./dumped/partitions/bootloader/extracted/"

NAS_CONFIG="$outputfile"
NAS_CONFIG_IMG="$outputfile"

if [ ! -f "$outputfile" ]; then
    dd \
        if=/dev/zero \
        of="$NAS_CONFIG_IMG" \
        bs=512 \
        count=4320
fi
# NOTE - hardcoding UUID, GRUB bootloader (as copied) will not find the partition otherwise
mke2fs -F -v -m0 -b 1024 -I 128 -U 90a34014-e609-4965-b6b4-95f277bfdf23 -O '^huge_file' -d "${TMP_CONFIG}" "$NAS_CONFIG_IMG"
/sbin/tune2fs -i 0 -c 0 "${NAS_CONFIG}"
