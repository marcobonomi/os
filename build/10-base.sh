#!/usr/bin/env bash
# Step 2: system foundations on top of the minimal root filesystem
set -euo pipefail

packages=(
    # Disk encryption (LUKS), network
    cryptsetup NetworkManager

    # Firmware: network card (linux-firmware, realtek) and CPU microcode
    linux-firmware realtek-firmware amd-ucode-firmware

    # Users, passwords, sudo, authorization
    sudo polkit passwd shadow-utils

    # Accurate time (TLS, signature checks) and time zones
    chrony tzdata

    # Swap on zram
    zram-generator-defaults

    # Containers (AI workloads)
    podman

    # Audio
    pipewire wireplumber pipewire-pulseaudio pipewire-alsa

    # Graphical boot splash (LUKS PIN prompt)
    plymouth plymouth-system-theme

    # Basic command line tools
    less tar zstd iproute hostname bash-completion usbutils pciutils
)

# Only explicitly requested packages and their hard dependencies
dnf -y install --setopt=install_weak_deps=False "${packages[@]}"

# --- Cleanup: no build leftovers in /var and /run (bootc lint) ----------------
# /var/lib/dnf also holds the "countme" counters: not wanted in the image
dnf clean all
rm -rf /var/lib/dnf /run/dnf
