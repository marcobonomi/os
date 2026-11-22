# Build with:
#   podman build --cap-add=all --security-opt=label=type:container_runtime_t \
#       --device /dev/fuse -t os .
# (the root filesystem generator needs these privileges)

# NVIDIA driver packages and signed kernel modules (Universal Blue akmods),
# pinned by digest (updated by Renovate)
FROM ghcr.io/ublue-os/akmods-nvidia-open:main-45@sha256:d19a4c014548a6e8cd9f7c49899f580da2c8ddb7c9c79348b4882b3069b49b95 AS akmods

# Fedora bootc 45, used only for its tools: the root filesystem generator,
# Fedora's package manifests, and tools to verify packages. Nothing of it ends
# up in the image. Pinned by digest (updated by Renovate)
FROM quay.io/fedora/fedora-bootc:45@sha256:881c4dd0acb6cc416d5fd484582b79b110eed31e4c971b1fc7d2990be2b18970 AS tools

# Only its own script is mounted, so that editing other scripts does not
# invalidate the cache of this (slow) stage
FROM tools AS rootfs
RUN --mount=type=bind,source=build/00-rootfs.sh,target=/ctx/00-rootfs.sh \
    --mount=type=bind,from=akmods,source=/rpms,target=/tmp/akmods-rpms \
    --mount=type=cache,dst=/var/cache \
    /ctx/00-rootfs.sh

FROM tools AS nvidia-verified
RUN --mount=type=bind,source=build,target=/ctx \
    --mount=type=bind,source=files,target=/files \
    --mount=type=bind,from=akmods,source=/rpms,target=/tmp/akmods-rpms \
    /ctx/20-nvidia-verify.sh

# The image starts from the generated root filesystem only
FROM scratch
COPY --from=rootfs /target-rootfs/ /
LABEL containers.bootc=1
ENV container=oci
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]

# Build scripts are bind-mounted, so they never end up in the image.
# /var/cache, /var/log and /tmp are kept out of the image layers.
RUN --mount=type=bind,source=build,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/10-base.sh

RUN --mount=type=bind,source=build,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=bind,from=akmods,source=/rpms,target=/tmp/akmods-rpms \
    --mount=type=bind,from=nvidia-verified,source=/verified,target=/verified \
    /ctx/20-nvidia.sh

RUN --mount=type=bind,source=build,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/30-desktop.sh

# Static configuration files, copied as-is (paths mirror /).
# After the packages, so that they can override packaged files.
COPY files/ /

# After all packages and config files
RUN --mount=type=bind,source=build,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/90-initramfs.sh

# Declare the /var directories created by packages in tmpfiles.d
RUN --mount=type=bind,source=build,target=/ctx \
    /ctx/95-var-tmpfiles.sh

# Must stay the last instruction: validates the final image
RUN bootc container lint --fatal-warnings
