# Codex for rootless iPadOS

An experimental, reproducible port of the open-source OpenAI Codex CLI to
jailbroken arm64 iPads. The output is a rootless Debian package installed below
`/var/jb`.

The initial device target is an A10 `iPad7,5` running iPadOS 17.7.11. The build
uses the official Rust implementation directly; Node.js is not required at
runtime.

> This is an unofficial community port. OpenAI does not currently publish an
> iOS/iPadOS Codex CLI binary. Upstream is pinned in `config.env` so every port
> update is reviewable.

## Current status

- Repository, pinned upstream fetch, iOS cross-build, signing, rootless Debian
  packaging, USB device diagnostics, install helper, and static tests exist.
- The connected iPad is visible through usbmuxd and reports `arm64`, iPadOS
  17.7.11, and rootless package architecture `iphoneos-arm64`.
- A complete Xcode install is still required on the Mac. Command Line Tools do
  not include the iPhoneOS SDK.
- Device SSH is reachable over USB, but installation requires the iPad's root
  SSH password or an authorized key.
- iPadOS has no supported Codex process sandbox backend. Treat shell commands
  as unsandboxed and use this only with repositories you trust.

## Requirements

- macOS with full Xcode selected by `xcode-select`
- Rust with the `aarch64-apple-ios` target
- `ldid` on the iPad; host-side `ldid` is optional
- Git, Python 3, and internet access
- A rootless jailbreak with OpenSSH and `dpkg` on the iPad
- `libimobiledevice`/`usbmuxd` tools (`ideviceinfo`, `iproxy`)

Check the host and device:

```sh
make check
make device-info
```

If Xcode is installed but not selected:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
```

## Build and package

```sh
make all
```

The package is written to `dist/codex-ios_<version>_iphoneos-arm64.deb`.
Upstream sources are cloned into `.build/upstream`, checked out at the exact
commit in `config.env`, and left out of Git.

If host-side `ldid` is unavailable, the package's `postinst` signs the binary
on the iPad with the same reviewed entitlements.

## Install over USB

In one terminal, expose jailbreak SSH through usbmuxd:

```sh
iproxy 2222 22
```

In another terminal:

```sh
SSH_PORT=2222 SSH_USER=root make install
```

The helper uses interactive `scp`/`ssh`, so it can request the root password
without storing it. Prefer an SSH key. After installation:

```sh
ssh -p 2222 root@127.0.0.1
codex --version
codex login --device-auth
```

API-key authentication can instead be configured in the shell environment.
Do not commit credentials or bake them into the package.

## Security model

The upstream macOS Seatbelt and Linux sandbox implementations do not apply to
iPadOS. Upstream therefore selects `SandboxType::None` on this target. The port
does not pretend otherwise and does not patch around Codex permission prompts.
Run it as `mobile` where practical; use `root` only for package installation.

## Updating upstream

Change `CODEX_REVISION` in `config.env`, run `make clean all`, then perform the
device smoke test. Do not move the pin until cross-build and device execution
both pass.
