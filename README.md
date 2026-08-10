# iOS Ports

Monorepository for reproducible ports of command-line developer tools to
rootless jailbroken arm64 iOS and iPadOS devices.

## Ports

| Port | Version | Package | Status |
| --- | --- | --- | --- |
| [Node.js](ports/nodejs) | 24.18.1 LTS | `nodejs-ios24` | Active |
| [OpenAI Codex](ports/codex) | Experimental snapshot | `codex-ios` | Archived scaffold |

Node.js 24 is the only active build target for now. The earlier Codex work is
kept under `ports/codex` so its history and package are not lost.

## Build Node.js

The build needs macOS with the full Xcode iPhoneOS SDK and `ldid`:

```sh
make nodejs
```

The result is written below `ports/nodejs/dist/`. Every push that changes the
Node.js port also runs the same build on a GitHub-hosted Apple Silicon runner
and uploads the `.deb` and checksum as workflow artifacts.

This is an unofficial community project. Upstream versions and checksums are
pinned inside each port so updates remain reviewable.
