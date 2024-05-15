#!/bin/bash

# Author: Carl Kittelberger <icedream@icedream.pw>

set -e
set -u
set -o pipefail

. ./func.sh

# args: outputfile blocksize blockcount label

outputfile="$1"
shift 1

TMP_LICENSE="$(mktemp -d)"
trap 'rm -rf "$TMP_LICENSE"' EXIT
mkdir -p "$TMP_LICENSE/qlicense"

BLOCK=16608
BLOCKSIZE=512
if [ ! -f "$outputfile" ]; then
    dd \
        if=/dev/zero \
        of="$outputfile" \
        bs="$BLOCKSIZE" \
        count="$BLOCK"
fi
mke2fs -F -v -m0 -b 1024 -I 128 -d "${TMP_LICENSE}" "$outputfile"
/sbin/tune2fs -i 0 -c 0 "$outputfile"
