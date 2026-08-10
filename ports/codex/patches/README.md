# Upstream patches

Keep iPadOS-specific source patches here. `scripts/fetch-source.sh` resets the
checkout to the pinned revision and applies every numbered patch in order.

`0001-disable-arboard-on-ios.patch` prevents the TUI from selecting arboard's
Linux Wayland/X11 backend on iOS and retains OSC 52 terminal clipboard fallback.

`0002-define-rlimit-exit-code-on-ios.patch` makes the shared Unix core-limit
helper compile on iOS without enabling macOS-only ptrace hardening.

`0003-disable-v8-sandbox-on-ios.patch` keeps the V8 sandbox enabled on supported
desktop targets but disables it on iOS, whose process address-space policy
prevents V8 from reserving the sandbox cage.
