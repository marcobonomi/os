#!/usr/bin/env bash
# Declare in tmpfiles.d every directory and symlink that packages created in
# /var. On bootc /var is not updated from the image after installation: these
# entries make systemd create them at boot. (rpm-ostree does the same when
# composing Fedora's base images; dnf does not.)
#
# Regular files in /var are an error: each one must be handled explicitly.
set -euo pipefail

out=/usr/lib/tmpfiles.d/zz-image-var.conf

# Paths already declared by a tmpfiles.d file (second field of each entry)
declared=$(cat /usr/lib/tmpfiles.d/*.conf | awk '!/^[[:space:]]*(#|$)/ {print $2}' | sort -u)

files=$(find /var -mindepth 1 \( -path /var/cache -o -path /var/log -o -path /var/tmp \) -prune \
    -o -type f -print)
if [[ -n "$files" ]]; then
    echo "ERROR: regular files in /var, handle them explicitly:" >&2
    echo "$files" >&2
    exit 1
fi

{
    echo "# Generated at build time by build/95-var-tmpfiles.sh"
    find /var -mindepth 1 \( -path /var/cache -o -path /var/log -o -path /var/tmp \) -prune \
        -o \( -type d -o -type l \) -printf '%y %p %m %u %g %l\n' |
        while read -r type path mode user group target; do
            grep -qxF "$path" <<< "$declared" && continue
            case "$type" in
                d) printf 'd %s %04o %s %s - -\n' "$path" "0$mode" "$user" "$group" ;;
                l) printf 'L %s - - - - %s\n' "$path" "$target" ;;
            esac
        done
} > "$out"

cat "$out"
