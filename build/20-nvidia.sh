#!/usr/bin/env bash
# Step 3: NVIDIA driver with open kernel modules
#
# Sources, from the ublue akmods image (bind-mounted at $AKMODS):
# - kmod-nvidia: kernel modules built and signed for Secure Boot by Universal Blue
# - nvidia-*:    driver packages by negativo17, signed with his GPG key
# Dependencies come from the official Fedora repos only.
set -euo pipefail

AKMODS=/tmp/akmods-rpms
KEYS=/ctx/keys
MOK_CERT=/files/usr/share/pki/mok/ublue-akmods.der # files/ is bind-mounted here
NEGATIVO17_KEY=0c5d0f470484ae2fc40a9b6597f3008993e8909b

# KERNEL_VERSION, NVIDIA_AKMOD_VERSION, DIST_ARCH
# shellcheck source=/dev/null
source "$AKMODS/kmods/nvidia-vars"
dist=${DIST_ARCH%.*} # fc45

# --- The modules must be built for the kernel of the base image ---------------
base_kernel=$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-core)
if [[ "$base_kernel" != "$KERNEL_VERSION" ]]; then
    echo "ERROR: base kernel is $base_kernel, NVIDIA modules are built for $KERNEL_VERSION" >&2
    exit 1
fi

# --- Packages to install ------------------------------------------------------
# Wayland desktop + CUDA driver libraries (needed by GPU containers).
# Not installed: 32-bit libraries (Steam is a Flatpak), X11-only tools
# (nvidia-settings, nvidia-xconfig, xorg-x11-nvidia, libXNVCtrl, libnvidia-fbc),
# nvidia-persistenced (compute servers).
rpms=(
    "$AKMODS/nvidia/nvidia-driver-$NVIDIA_AKMOD_VERSION.$DIST_ARCH.rpm"
    "$AKMODS/nvidia/nvidia-driver-libs-$NVIDIA_AKMOD_VERSION.$DIST_ARCH.rpm"
    "$AKMODS/nvidia/nvidia-driver-common-$NVIDIA_AKMOD_VERSION.$DIST_ARCH.rpm"
    "$AKMODS/nvidia/nvidia-driver-cuda-$NVIDIA_AKMOD_VERSION.$DIST_ARCH.rpm"
    "$AKMODS/nvidia/nvidia-driver-cuda-libs-$NVIDIA_AKMOD_VERSION.$DIST_ARCH.rpm"
    "$AKMODS/nvidia/nvidia-modprobe-$NVIDIA_AKMOD_VERSION.$DIST_ARCH.rpm"
    "$AKMODS/nvidia/nvidia-persistenced-$NVIDIA_AKMOD_VERSION.$DIST_ARCH.rpm" # required by nvidia-driver-cuda
    "$AKMODS/nvidia/nvidia-kmod-common-$NVIDIA_AKMOD_VERSION.$dist.noarch.rpm"
)
kmod="$AKMODS/kmods/kmod-nvidia-$KERNEL_VERSION-$NVIDIA_AKMOD_VERSION.$DIST_ARCH.rpm"

# --- Verify the negativo17 signatures -----------------------------------------
# rpmkeys exits 0 also for unsigned packages: check the output explicitly.
rpmkeys --import "$KEYS/RPM-GPG-KEY-negativo17"
for rpm in "${rpms[@]}"; do
    if ! rpmkeys --checksig "$rpm" | grep -q ': digests signatures OK$'; then
        echo "ERROR: bad or missing negativo17 signature: $rpm" >&2
        exit 1
    fi
done

# --- Verify the module signatures ---------------------------------------------
# kmod-nvidia is not GPG-signed: check that every module is signed with the
# Universal Blue certificate we enroll as MOK, or Secure Boot would reject it.
mok_serial=$(openssl x509 -inform der -in "$MOK_CERT" -noout -serial | cut -d= -f2)
moddir=$(mktemp -d)
rpm2cpio "$kmod" | (cd "$moddir" && cpio -idm --quiet)
mapfile -t modules < <(find "$moddir" -name '*.ko*')
[[ ${#modules[@]} -gt 0 ]] || { echo "ERROR: no modules in $kmod" >&2; exit 1; }
for mod in "${modules[@]}"; do
    sig=$(modinfo -F sig_key "$mod" | tr -d ':')
    if [[ "$sig" != "$mok_serial" ]]; then
        echo "ERROR: $(basename "$mod") is not signed with the ublue MOK key (got '$sig')" >&2
        exit 1
    fi
done
rm -rf "$moddir"

# --- Install ------------------------------------------------------------------
# nvidia-driver-selinux (required with SELinux) is not in the akmods image nor
# in Fedora: take it, and only it, from the negativo17 repo, enabled for this
# command only and verified with the pinned key.
dnf -y install --setopt=install_weak_deps=False \
    --repofrompath="negativo17,https://negativo17.org/repos/nvidia/fedora-$(rpm -E %fedora)/$(uname -m)/" \
    --setopt=negativo17.gpgcheck=1 \
    --setopt=negativo17.gpgkey="file://$KEYS/RPM-GPG-KEY-negativo17" \
    --setopt=negativo17.includepkgs=nvidia-driver-selinux \
    "${rpms[@]}" "$kmod" nvidia-driver-selinux

rpmkeys --delete "$NEGATIVO17_KEY" # do not leave it trusted in the image

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
