# travis-qemu [![Build Status](https://travis-ci.org/alon/flashair-openwrt-logger.svg?branch=master)](https://travis-ci.org/alon/flashair-openwrt-logger)

Logging of the contents of an air SD card via an ssh connection.

Logger makes the following assumptions:
* HTTP connection to get directory listing and file contents
* Preferable to not use a temporary copy
* ssh connection to destination
* SD card files are in CSVFILES/LOG/ directory and there are no subdirectories (flat layout).

Implementation:
Using rsync would have been preferable, and is still possible with a file system in user space implementation. I have taken what was simpler to me, doing a very basic syncing based on a last synced date recorded in a file. I use the posix and socket lua extensions. Tested with openwrt 12.09 and lua 5.1.2

OpenWRT instructions:
opkg install luasocket luaposix
mkdir /root/.ssh
chmod 700 /root/.ssh
dropbearkey -t rsa /root/.ssh/id_rsa
