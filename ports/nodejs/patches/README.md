# Patches

Node.js 24.18.1 already accepts `--dest-os=ios`. The build applies every
numbered patch in this directory before configuring the source.

- `0001-cares-disable-sys-random-on-ios.patch` disables the macOS c-ares
  feature probe for `<sys/random.h>`, which is absent from the iPhoneOS SDK.
  c-ares retains its `arc4random_buf` implementation on Apple platforms.
- `0002-crypto-disable-macos-keychain-on-ios.patch` excludes Node's macOS
  Keychain certificate loader from iOS builds. Apple's iOS SDK does not expose
  those Trust Settings APIs; Node's bundled CA store and `NODE_EXTRA_CA_CERTS`
  remain available.
