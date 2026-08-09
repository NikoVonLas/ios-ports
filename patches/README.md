# Upstream patches

Keep iPadOS-specific source patches here and apply them from `scripts/build.sh`.
The first port intentionally carries no speculative source patches: upstream's
unsupported-Unix path already selects `SandboxType::None`. Add patches only in
response to a reproducible cross-build or device-runtime failure.

