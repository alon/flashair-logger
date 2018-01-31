#!/bin/bash

# Reset to 1 whenever MAJOR or MINOR is changed
VERSION_RELEASE=1

VERSION_MAJOR=$(lua -e 't = require("sync_sd_to_remote"); print(t.VERSION_MAJOR)')
VERSION_MINOR=$(lua -e 't = require("sync_sd_to_remote"); print(t.VERSION_MINOR)')
VERSION=$VERSION_MAJOR.$VERSION_MINOR-$VERSION_RELEASE
PACKAGE_NAME=flashair-logger_$VERSION
PACKAGE_FILENAME="debian/$PACKAGE_NAME.deb"
ROOT=debian/$PACKAGE_NAME
BIN=$ROOT/usr/bin

# Under debian lua packaged are dropped in 5.1 and symlinked into 5.2, 5.3
# TODO: those symlinks
# see for instance dpkg -L lua-socket (3.0~rc1+git+ac3201d-3)

ROOT51=$ROOT/usr/share/lua/5.1
DEBIAN=$ROOT/DEBIAN

mkdir -p "$ROOT51"
mkdir -p "$BIN"
mkdir -p "$DEBIAN"
cp -R falog "$ROOT51/"
cp sync_sd_to_remote.lua "$ROOT51/"
cp sync_sd_to_remote "$BIN/"

cat > "$DEBIAN/control" <<EOF
Package: flashair-logger
Version: $VERSION
Section: base
Priority: optional
Architecture: all
Depends: lua5.1 (>= 5.1.5), lua-socket (>= 2.99), lua-posix (>= 31)
Maintainer: Alon Levy <alon@pobox.com>
Description: FlashAir Logger
 Copies files from Toshiba FlashAir v3 cards over the HTTP API to a remote SSH server.

EOF

dpkg-deb -b "$ROOT"
cp $PACKAGE_FILENAME docker/flashair-logger.deb
