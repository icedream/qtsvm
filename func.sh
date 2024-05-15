#!/bin/bash

# Author: Carl Kittelberger <icedream@icedream.pw>

# Log a message to STDERR.
log() {
    echo "$@" >&2
}

# Log an error message.
error() {
    log "ERROR:" "$@"
}

# Log an error message and exit non-zero.
fatal() {
    error "$@"
    exit 1
}

# Log an info message.
info() {
    log "INFO:" "$@"
}

# Log a warning.
warn() {
    log "WARNING:" "$@"
}

# Discover a QNAP server using QDiscover/Zeroconf.
qdiscover_single() {
    local qnap_server
    IFS=';' read -r _ _ _ qnap_server _ _ _ < <(avahi-browse -p --terminate _qdiscover._tcp || true)

    if [ -z "$qnap_server" ]; then
        false
    else
        printf "%s" "$qnap_server"
    fi
}

mount_delimiter=:

mount_noroot() {
    local img_path="$1"
    local files_path=""
    local files_method=
    local udisks_loop_device=

    if command -v mount >/dev/null; then
        files_path=$(mktemp -d -p /var/tmp)
        files_method=mount
        if mount -o loop "$img_path" "$files_path"; then
            info "$img_path mounted to $files_path"
            echo "${files_method}${mount_delimiter}${files_path}${mount_delimiter}"
            return
        fi
        warn "mount failed, moving to next method..."
    fi
    if command -v udisksctl >/dev/null; then
        # mount with udisks2
        # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=827029
        files_method=udisks
        if udisks_loop_device=$(
            udisksctl loop-setup \
                --no-user-interaction \
                --no-partition-scan \
                --file "$img_path" |
                grep -Eo '([^[:space:]\.]+)' |
                tail -n1
        ); then
            if files_path=$(
                udisksctl mount \
                    --block-device "$udisks_loop_device" |
                    grep -Eo 'at /([^\.]+)' |
                    tail -c+4
            ); then
                info "$img_path mounted via udisks2 to $files_path"
                echo "${files_method}${mount_delimiter}${files_path}${mount_delimiter}${udisks_loop_device}"
                return
            fi
        fi
        warn "udisks2 mount failed, moving to next method..."
        unmount_noroot "$files_method" "$files_path" "$udisks_loop_device"
    fi
    fail "No method available to mount image file."
}

unmount_noroot() {
    local files_method="$1"
    local files_path="$2"
    local files_extra="$3"
    case "$files_method" in
    extract)
        # remove the files
        info "Removing $files_path..."
        rm -rf "$files_path" >&2
        files_path=
        ;;
    udisks)
        if [ -n "$files_extra" ]; then
            info "Unmounting $files_path..."
            udisksctl unmount --block-device "$files_extra" >&2 || true
            udisksctl loop-delete --block-device "$files_extra" >&2
        fi
        ;;
    usermount)
        info "Unmounting $files_path..."
        fusermount -u "$files_path" >&2
        rmdir "$files_path" >&2
        ;;
    mount)
        info "Unmounting $files_path..."
        umount -l "$files_path" >&2
        rmdir "$files_path" >&2
        ;;
    *)
        # nothing mounted, ignore
        ;;
    esac
}
