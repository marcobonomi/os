#!/usr/bin/env bash
# Step 2: desktop foundations and removal of server/cloud packages
set -euo pipefail

# Only explicitly requested packages and their hard dependencies
dnf_install() { dnf -y install --setopt=install_weak_deps=False "$@"; }

# --- Remove server/cloud packages ---------------------------------------------
# - cloud: growpart, cloud-setup, Azure agent udev rules
# - crash dumps: kdump (coredumps are disabled anyway)
# - enterprise auth: Active Directory / FreeIPA
# - foreign-architecture emulation, real-time stall daemon, legacy iptables
# - clevis: TPM unlock is done with systemd-cryptenroll instead
# - AWS libraries (cloud)
# - firmware for hardware that is absent or disabled: nouveau/nova (the NVIDIA
#   driver ships its own), AMD/Intel GPUs, Wi-Fi, Bluetooth, modems, laptop audio
dnf -y remove \
    cloud-utils-growpart \
    NetworkManager-cloud-setup \
    WALinuxAgent-udev \
    kdump-utils kexec-tools \
    sssd-ad sssd-ipa \
    'qemu-user-static*' \
    stalld \
    iptables-services \
    clevis clevis-dracut clevis-luks clevis-pin-tpm2 clevis-systemd \
    python3-boto3 python3-botocore python3-s3transfer \
    nvidia-gpu-firmware amd-gpu-firmware intel-gpu-firmware \
    atheros-firmware mt7xxx-firmware brcmfmac-firmware tiwilink-firmware \
    nxpwireless-firmware qcom-wwan-firmware \
    intel-audio-firmware cirrus-audio-firmware intel-npu-firmware

# Created by the fedora-bootc build (not by a package): it would make dracut
# fail now that clevis is gone
rm /usr/lib/dracut/dracut.conf.d/50-bootc-clevis.conf

# --- Install desktop foundations ----------------------------------------------
dnf_install \
    pipewire wireplumber pipewire-pulseaudio pipewire-alsa \
    zram-generator-defaults \
    plymouth plymouth-system-theme \
    usbutils pciutils

# --- Cleanup: no build leftovers in /var and /run (bootc lint) ----------------
# /var/lib/dnf also holds the "countme" counters: not wanted in the image
dnf clean all
rm -rf /var/lib/dnf /run/dnf
