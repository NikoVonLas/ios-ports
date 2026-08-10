# Patches

Node.js 24.18.1 already accepts `--dest-os=ios`. The build applies every
numbered patch in this directory before configuring the source.

- `0001-cares-disable-sys-random-on-ios.patch` disables the macOS c-ares
  feature probe for `<sys/random.h>`, which is absent from the iPhoneOS SDK.
  c-ares retains its `arc4random_buf` implementation on Apple platforms.
