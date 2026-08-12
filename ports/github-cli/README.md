# GitHub CLI for rootless iOS

Native `ios/arm64` build of the official GitHub CLI for jailbroken iOS and
iPadOS 15 or later.

## Build

Install full Xcode, Go, and `ldid`, then run from the monorepo root:

```sh
make github-cli
make github-cli-repo
make github-cli-test
```

The package is written to `ports/github-cli/dist/` and installs `gh` at
`/var/jb/usr/bin/gh`.

## Authentication

Run `gh auth login` on the device. If automatic browser launching is not
available in the terminal, open the displayed URL manually and enter its
one-time code.

GitHub CLI extensions are separate executables. An extension only works on the
device when it provides an iOS arm64 binary or is implemented as a portable
script.
