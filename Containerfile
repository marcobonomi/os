# NVIDIA driver packages and signed kernel modules (Universal Blue akmods),
# pinned by digest (updated by Renovate together with the base image)
FROM ghcr.io/ublue-os/akmods-nvidia-open:main-45@sha256:d19a4c014548a6e8cd9f7c49899f580da2c8ddb7c9c79348b4882b3069b49b95 AS akmods

# Base: Fedora bootc 45, pinned by digest (updated by Renovate)
FROM quay.io/fedora/fedora-bootc:45@sha256:881c4dd0acb6cc416d5fd484582b79b110eed31e4c971b1fc7d2990be2b18970

# Build scripts are bind-mounted, so they never end up in the image.
# /var/cache, /var/log and /tmp are kept out of the image layers.
RUN --mount=type=bind,source=build,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/10-base.sh

RUN --mount=type=bind,source=build,target=/ctx \
    --mount=type=bind,source=files,target=/files \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=bind,from=akmods,source=/rpms,target=/tmp/akmods-rpms \
    /ctx/20-nvidia.sh

# Static configuration files, copied as-is (paths mirror /).
# After the packages, so that they can override packaged files.
COPY files/ /

# After all packages and config files
RUN --mount=type=bind,source=build,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/90-initramfs.sh

# Must stay the last instruction: validates the final image
RUN bootc container lint --fatal-warnings
