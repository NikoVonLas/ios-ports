#!/bin/sh
set -eu

export LC_ALL=C
export LANG=C

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

# shellcheck disable=SC1091
. "$project_root/config.env"

build_root="$project_root/build"
source_archive="$build_root/downloads/node-v$NODE_VERSION.tar.xz"
source_root="$build_root/src/node-v$NODE_VERSION"
stage_root="$build_root/stage"
dist_root="$project_root/dist"

export project_root build_root source_archive source_root stage_root dist_root
export NODE_VERSION NODE_SHA256 IOS_DEPLOYMENT_TARGET PACKAGE_REVISION
