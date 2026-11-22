#!/usr/bin/env bash
# Regenerate the initramfs after all packages and config files are in place
# (plymouth, NVIDIA early KMS, no clevis)
set -euo pipefail

kver=$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-core)

# /root links to /var/roothome, which only exists on an installed system:
# dracut fails to resolve it during the build. Create it just for dracut.
mkdir -p /var/roothome

dracut --force --no-hostonly --reproducible --zstd --tmpdir /tmp \
    --kver "$kver" "/usr/lib/modules/$kver/initramfs.img"

rmdir /var/roothome
