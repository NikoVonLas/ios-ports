# iOS Ports

Monorepository for reproducible ports of command-line developer tools to
rootless jailbroken arm64 iOS and iPadOS devices.

## Ports

| Port | Version | Package | Status |
| --- | --- | --- | --- |
| [Node.js](ports/nodejs) | 24.18.1 LTS | `nodejs-ios24` | Active |
| [OpenAI Codex](ports/codex) | Automatically tracked stable release | `codex-ios` | Active |
| [GitHub CLI](ports/github-cli) | Automatically tracked stable release | `github-cli-ios` | Active |

All ports target rootless arm64 iOS/iPadOS.

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

## Build Codex

Codex includes its separate V8-based Code Mode host. Since rust-v8 does not
publish an iOS device archive, the first build compiles a jitless V8 from
source:

```sh
make codex
make codex-repo
```

The `Update Codex for iPadOS` workflow checks the official `openai/codex`
stable release once per hour. A new `rust-vX.Y.Z` tag is pinned by commit SHA,
built and inspected on GitHub-hosted Apple Silicon macOS runners, committed
only after success, and then deployed as the Sileo repository. A versioned
source build of rust-v8 is stored as a reusable release asset, so ordinary
Codex updates only download the roughly 40 MB compressed V8 archive.

## Build GitHub CLI

GitHub CLI is a native Go program and cross-compiles directly to the official
`ios/arm64` Go target:

```sh
make github-cli
make github-cli-repo
```

The `Update GitHub CLI for iPadOS` workflow checks the official `cli/cli`
latest release once per hour. It pins the resolved commit SHA, builds and signs
the rootless package on macOS, inspects the package, and only then publishes it
to the shared Sileo repository.
