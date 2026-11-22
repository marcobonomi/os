# shellcheck shell=bash
# NVIDIA packages taken from the ublue akmods image (sourced by the NVIDIA
# scripts, so that verification and installation use the same list).
#
# Wayland desktop + CUDA driver libraries (needed by GPU containers).
# Not installed: 32-bit libraries (Steam is a Flatpak), X11-only tools
# (nvidia-settings, nvidia-xconfig, xorg-x11-nvidia, libXNVCtrl, libnvidia-fbc).

AKMODS=/tmp/akmods-rpms

# KERNEL_VERSION, NVIDIA_AKMOD_VERSION, DIST_ARCH
# shellcheck source=/dev/null
source "$AKMODS/kmods/nvidia-vars"
_dist=${DIST_ARCH%.*} # fc45

# Driver packages by negativo17 (GPG-signed)
NVIDIA_RPMS=(
    "$AKMODS/nvidia/nvidia-driver-$NVIDIA_AKMOD_VERSION.$DIST_ARCH.rpm"
    "$AKMODS/nvidia/nvidia-driver-libs-$NVIDIA_AKMOD_VERSION.$DIST_ARCH.rpm"
    "$AKMODS/nvidia/nvidia-driver-common-$NVIDIA_AKMOD_VERSION.$DIST_ARCH.rpm"
    "$AKMODS/nvidia/nvidia-driver-cuda-$NVIDIA_AKMOD_VERSION.$DIST_ARCH.rpm"
    "$AKMODS/nvidia/nvidia-driver-cuda-libs-$NVIDIA_AKMOD_VERSION.$DIST_ARCH.rpm"
    "$AKMODS/nvidia/nvidia-modprobe-$NVIDIA_AKMOD_VERSION.$DIST_ARCH.rpm"
    "$AKMODS/nvidia/nvidia-persistenced-$NVIDIA_AKMOD_VERSION.$DIST_ARCH.rpm" # required by nvidia-driver-cuda
    "$AKMODS/nvidia/nvidia-kmod-common-$NVIDIA_AKMOD_VERSION.$_dist.noarch.rpm"
)

# Kernel modules built and signed for Secure Boot by Universal Blue
NVIDIA_KMOD_RPM="$AKMODS/kmods/kmod-nvidia-$KERNEL_VERSION-$NVIDIA_AKMOD_VERSION.$DIST_ARCH.rpm"

export AKMODS KERNEL_VERSION NVIDIA_AKMOD_VERSION NVIDIA_RPMS NVIDIA_KMOD_RPM
