# Node.js 24 for rootless iOS

Reproducible build and Debian packaging scripts for running Node.js 24 LTS and
npm on jailbroken arm64 iOS/iPadOS devices.

The target package is `iphoneos-arm64` and installs beneath `/var/jb`. It is
intended for rootless jailbreaks such as palera1n and Dopamine on iOS 15 or
later. The first test target is an A10 iPad (`iPad7,5`) on iPadOS 17.7.11.

## Status

The port structure, source verification, cross-toolchain wrappers,
rootless package layout, entitlements, and smoke tests are implemented. A full
build requires the complete Xcode application because Command Line Tools do not
contain the iPhoneOS SDK.

## Requirements

- macOS with full Xcode selected by `xcode-select`
- Python 3
- GNU Make
- `ldid` for signing the target executable
- internet access to fetch the pinned Node.js source archive

Check the host before downloading or compiling:

```sh
make -C ports/nodejs check
```

## Build

```sh
make -C ports/nodejs fetch
make -C ports/nodejs build
make -C ports/nodejs package
```

Or run the entire pipeline:

```sh
make nodejs
```

The `.deb` is written to `dist/`.

Version and deployment settings are pinned in `config.env`. Downloads are
verified against the SHA-256 published by the Node.js project before they are
extracted.

## Install and test

Copy the package to the device and install it:

```sh
sudo dpkg -i nodejs_24.18.1-2_iphoneos-arm64.deb
node --version
npm --version
node /var/jb/usr/share/nodejs-ios24/smoke.js
```

The installed `node` command is a small wrapper that runs V8 with `--jitless`.
This avoids a `SIGBUS` when V8 tries to allocate executable memory on Dopamine,
including during npm startup. Set `NODE_IOS_ALLOW_JIT=1` only for testing on a
device and jailbreak that provide working JIT memory mappings.

## Important limitation

iOS is accepted by Node.js's build configuration, but it is not an officially
distributed Node.js binary platform. Each Node/V8 release can expose new build
or runtime incompatibilities. Device smoke tests are therefore part of the
release process; a successful cross-build alone is not enough.
