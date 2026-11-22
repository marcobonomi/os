#!/usr/bin/env bash
# Step 3b: NVIDIA driver with open kernel modules
#
# Sources, from the ublue akmods image (bind-mounted at $AKMODS):
# - kmod-nvidia: kernel modules built and signed for Secure Boot by Universal Blue
# - nvidia-*:    driver packages by negativo17, signed with his GPG key
# Signatures are verified by 20-nvidia-verify.sh in a separate stage; here we
# only accept the exact files it verified. Dependencies come from Fedora.
set -euo pipefail

KEYS=/ctx/keys
NEGATIVO17_KEY=0c5d0f470484ae2fc40a9b6597f3008993e8909b

# shellcheck source=build/nvidia-rpms.sh
source /ctx/nvidia-rpms.sh

# --- Same files as verified ---------------------------------------------------
sha256sum --check --quiet /verified/SHA256SUMS

# --- The modules must be built for the kernel of the image --------------------
# The kernel is locked to the akmods one by 00-rootfs.sh: this is a safety net.
image_kernel=$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-core)
if [[ "$image_kernel" != "$KERNEL_VERSION" ]]; then
    echo "ERROR: kernel is $image_kernel, NVIDIA modules are built for $KERNEL_VERSION" >&2
    exit 1
fi

# --- Install ------------------------------------------------------------------
# nvidia-driver-selinux (required with SELinux) is not in the akmods image nor
# in Fedora: take it, and only it, from the negativo17 repo, enabled for this
# command only and verified with the pinned key.
dnf -y install --setopt=install_weak_deps=False \
    --repofrompath="negativo17,https://negativo17.org/repos/nvidia/fedora-$(rpm -E %fedora)/$(uname -m)/" \
    --setopt=negativo17.gpgcheck=1 \
    --setopt=negativo17.gpgkey="file://$KEYS/RPM-GPG-KEY-negativo17" \
    --setopt=negativo17.includepkgs=nvidia-driver-selinux \
    "${NVIDIA_RPMS[@]}" "$NVIDIA_KMOD_RPM" nvidia-driver-selinux

# dnf imported the key for nvidia-driver-selinux: do not leave it trusted
rpmkeys --delete "$NEGATIVO17_KEY"

# The kernel module and the driver must be the same version
kmod_ver=$(rpm -q --qf '%{VERSION}' kmod-nvidia)
drv_ver=$(rpm -q --qf '%{VERSION}' nvidia-driver)
if [[ "$kmod_ver" != "$drv_ver" ]]; then
    echo "ERROR: kmod-nvidia $kmod_ver does not match nvidia-driver $drv_ver" >&2
    exit 1
fi

# --- Cleanup (bootc lint) -----------------------------------------------------
# /run/selinux-policy is left by the nvidia-driver-selinux scriptlet
dnf clean all
rm -rf /var/lib/dnf /run/dnf /run/selinux-policy
