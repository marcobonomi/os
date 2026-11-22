# Base: Fedora bootc 45, pinned by digest (updated by Renovate)
FROM quay.io/fedora/fedora-bootc:45@sha256:881c4dd0acb6cc416d5fd484582b79b110eed31e4c971b1fc7d2990be2b18970

# Build scripts are bind-mounted, so they never end up in the image.
# /var/cache, /var/log and /tmp are kept out of the image layers.
RUN --mount=type=bind,source=build,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/10-base.sh

# Static configuration files, copied as-is (paths mirror /)
COPY files/ /

# Must stay the last instruction: validates the final image
RUN bootc container lint --fatal-warnings
