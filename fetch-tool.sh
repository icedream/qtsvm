#!/bin/bash

# Author: Carl Kittelberger <icedream@icedream.pw>

set -e
set -u
set -o pipefail

. ./func.sh

server=$(qdiscover_single || fail "Could not find a physical QNAP server to fetch tool from")

tool_path="${1}"
tool_relpath="rootfs/${tool_path#/}"
tool_reldir="$(dirname "$tool_relpath")"

mkdir -p "$tool_reldir"
scp "admin@$server:$1" "$tool_relpath"
