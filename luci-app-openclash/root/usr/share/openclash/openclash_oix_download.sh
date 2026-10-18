#!/bin/sh
# Shared by sign-in and scheduled oixCloud configuration updates.
set -e
. /usr/share/libubox/jshn.sh
. /usr/share/openclash/uci.sh

[ "$#" -eq 2 ] || exit 1
case "$1" in https://*) ;; *) exit 1 ;; esac
core=/etc/openclash/core/clash_meta
if [ "$(uci_get_config small_flash_memory || true)" = "1" ]; then
    core=/tmp/etc/openclash/core/clash_meta
fi
if ! "$core" oix download-config --check >/dev/null 2>&1; then
    OIX_INSTALL_ONLY="${OIX_INSTALL_ONLY:-1}" OIX_FORCE_UPDATE=1 /usr/share/openclash/openclash_core.sh Oix >/dev/null 2>&1 || exit 1
    "$core" oix download-config --check >/dev/null 2>&1 || exit 1
fi
port=$(uci_get_config mixed_port || true)
port=${port:-7893}
case "$port" in *[!0-9]*|'') exit 1 ;; esac
[ "$port" -gt 0 ] && [ "$port" -le 65535 ] || exit 1
username=
password=
auth_found=0
read_auth() {
    local enabled
    [ "$auth_found" = 0 ] || return 0
    config_get enabled "$1" enabled 0
    [ "$enabled" = 1 ] || return 0
    config_get username "$1" username ''
    config_get password "$1" password ''
    auth_found=1
}
config_load openclash
config_foreach read_auth authentication
json_init
json_add_string url "$1"
json_add_string proxy "http://127.0.0.1:$port"
json_add_string proxy_username "$username"
json_add_string proxy_password "$password"
json_add_int routing_mark 6666
umask 077
temporary=$(mktemp "${2}.XXXXXX")
trap 'rm -f "$temporary"' EXIT HUP INT TERM
# Match the existing core exemption in nftables and iptables owner mode.
# The core also marks DNS and TCP sockets for iptables mark-only mode.
if json_dump | ruby -e 'Process::GID.change_privilege(65534); exec(ARGV[0], "oix", "download-config")' "$core" > "$temporary"; then
    [ -s "$temporary" ] || exit 1
    mv -f "$temporary" "$2"
else
    exit 1
fi
