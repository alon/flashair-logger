[![Build Status](https://travis-ci.org/alon/flashair-gclogger.svg?branch=master)](https://travis-ci.org/alon/flashair-logger)

# Flashair Logger

Logging of the contents of a FlashAir v2 or v3 SD card via an SSH connection.

Flashair-Logger makes the following assumptions / requirements:
* FlashAir v2/v3 with known HTTP API for directory listing and file contents retrieval
* Preferable to not use a temporary copy
* SSH connection available to destination
* SD card files are in CSVFILES/LOG/ directory and there are no subdirectories (flat layout).

Implementation:
Using rsync would have been preferable, and is still possible with a file
system in user space implementation. Instead the list of files is sent to the
target which returns the diff list whose contents is then sent.

Uses the posix and socket lua extensions. Tested with openwrt 12.09 & debian 9
and with Lua 5.1.2

A LEDE package is no longer maintained, however a Debian one can be created
with build_debian_package.sh
