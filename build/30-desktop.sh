#!/usr/bin/env bash
# Step 4: minimal KDE Plasma desktop
#
# Weak dependencies are off, so everything a usable desktop needs is listed
# explicitly. Regular apps (editor, viewers, archiver...) come as Flatpaks.
set -euo pipefail

packages=(
    # Plasma session, KWin and the login manager (Fedora defaults)
    plasma-workspace plasma-desktop kwin
    plasma-login-manager kcm-plasmalogin
    kde-settings-plasma kde-settings-plasmalogin
    plasma-integration qt6-qtwayland

    # X11 apps (Steam client, Proton games) and software rendering for VMs
    xorg-x11-server-Xwayland mesa-dri-drivers

    # Settings, displays (HDR/VRR/refresh rate), lock screen, power
    plasma-systemsettings kscreen kscreenlocker powerdevil

    # Audio volume, network
    plasma-pa plasma-nm

    # Authentication dialogs, portals for Flatpak apps, Flatpak permissions
    polkit-kde xdg-desktop-portal-kde flatpak-kcm

    # KWallet unlocked at login, and its manager
    pam-kwallet kwalletmanager5

    # Disk health (SMART) notifications
    plasma-disks

    # Look and fonts (no CJK fonts for now)
    plasma-breeze breeze-icon-theme
    default-fonts-core-sans default-fonts-core-serif
    default-fonts-core-mono default-fonts-core-emoji

    # Apps that need full access to the host
    konsole dolphin spectacle plasma-systemmonitor kinfocenter

    # Standard user folders (Documents, Downloads...)
    xdg-user-dirs
)

dnf -y install --setopt=install_weak_deps=False "${packages[@]}"

systemctl enable plasmalogin.service

# --- Cleanup (bootc lint) -----------------------------------------------------
# - /run/*: left by package scriptlets
# - authselect checksum: regenerated at boot by authselect-apply-changes.service
dnf clean all
rm -rf /var/lib/dnf /run/dnf /run/plasmalogin /run/samba /run/selinux-policy
rm /var/lib/authselect/checksum
