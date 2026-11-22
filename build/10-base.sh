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
dnf -y remove \
    cloud-utils-growpart \
    NetworkManager-cloud-setup \
    WALinuxAgent-udev \
    kdump-utils kexec-tools \
    sssd-ad sssd-ipa \
    'qemu-user-static*' \
    stalld \
    iptables-services \
    clevis clevis-dracut clevis-luks clevis-pin-tpm2 clevis-systemd

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
