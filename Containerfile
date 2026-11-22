# Base: Fedora bootc 45, pinned by digest (updated by Renovate)
FROM quay.io/fedora/fedora-bootc:45@sha256:881c4dd0acb6cc416d5fd484582b79b110eed31e4c971b1fc7d2990be2b18970

# Must stay the last instruction: validates the final image
RUN bootc container lint --fatal-warnings
