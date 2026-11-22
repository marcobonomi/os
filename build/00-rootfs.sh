#!/usr/bin/env bash
# Step 1: minimal root filesystem, generated with Fedora's own tool from its
# "minimal" manifest (bootc, systemd, kernel, dnf, SELinux, boot chain).
# Everything else is added explicitly by the next scripts.
#
# The kernel is locked to the version the NVIDIA modules are built for
# (read from the akmods image), so the two can never diverge. Older kernels
# are still available from the updates-archive repo.
set -euo pipefail

# KERNEL_VERSION
# shellcheck source=/dev/null
source /tmp/akmods-rpms/kmods/nvidia-vars

locks=()
for pkg in kernel kernel-core kernel-modules kernel-modules-core; do
    locks+=(--lock "$pkg-$KERNEL_VERSION")
done

mkdir -p /var/cache/rootfs
/usr/libexec/bootc-base-imagectl build-rootfs \
    --manifest=minimal \
    --cachedir=/var/cache/rootfs \
    "${locks[@]}" \
    /target-rootfs
