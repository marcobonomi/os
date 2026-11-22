#!/usr/bin/env bash
# Step 3a: verify the NVIDIA packages from the ublue akmods image.
# Runs in a separate stage with the builder's tools (openssl, cpio), so they
# are not needed in the image. Writes the checksums of the verified RPMs to
# /verified/SHA256SUMS: the install step only accepts those exact files.
set -euo pipefail

KEYS=/ctx/keys
MOK_CERT=/files/usr/share/pki/mok/ublue-akmods.der

# shellcheck source=build/nvidia-rpms.sh
source /ctx/nvidia-rpms.sh

# --- negativo17 signatures on the driver packages -----------------------------
# rpmkeys exits 0 also for unsigned packages: check the output explicitly.
rpmkeys --import "$KEYS/RPM-GPG-KEY-negativo17"
for rpm in "${NVIDIA_RPMS[@]}"; do
    if ! rpmkeys --checksig "$rpm" | grep -q ': digests signatures OK$'; then
        echo "ERROR: bad or missing negativo17 signature: $rpm" >&2
        exit 1
    fi
done

# --- ublue signatures on the kernel modules -----------------------------------
# kmod-nvidia is not GPG-signed: check that every module is signed with the
# Universal Blue certificate we enroll as MOK, or Secure Boot would reject it.
mok_serial=$(openssl x509 -inform der -in "$MOK_CERT" -noout -serial | cut -d= -f2)
moddir=$(mktemp -d)
rpm2cpio "$NVIDIA_KMOD_RPM" | (cd "$moddir" && cpio -idm --quiet)
mapfile -t modules < <(find "$moddir" -name '*.ko*')
[[ ${#modules[@]} -gt 0 ]] || { echo "ERROR: no modules in $NVIDIA_KMOD_RPM" >&2; exit 1; }
for mod in "${modules[@]}"; do
    sig=$(modinfo -F sig_key "$mod" | tr -d ':')
    if [[ "$sig" != "$mok_serial" ]]; then
        echo "ERROR: $(basename "$mod") is not signed with the ublue MOK key (got '$sig')" >&2
        exit 1
    fi
done
rm -rf "$moddir"

# --- Record what was verified -------------------------------------------------
mkdir -p /verified
sha256sum "${NVIDIA_RPMS[@]}" "$NVIDIA_KMOD_RPM" > /verified/SHA256SUMS
