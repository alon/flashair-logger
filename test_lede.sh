#!/usr/bin/env bash

# Run a full LEDE distribution test using qemu-armvirt
#
# Start tmux
# run qemu under it
# qemu: install required packages
# qemu: copy sources
# qemu: copy config file
# host: start externally sdcardemul
# qemu: start test
# host: verify results
# uses ssh to prebuilt host user (can run another system for that host, even another LEDE system)

SSH_USER=flashair
if [ "x$1" != "x" ]; then
    SSH_USER=$1
fi
TARGET_PATH=/home/$SSH_USER/data-logger

function waitfortcp {
    HOST=$1
    PORT=$2
    while true; do
        if nc -z "$HOST" "$PORT"; then
            break
        fi
        sleep 1
    done
}

function killjobs {
    for p in $(jobs -p); do
        sudo kill "$p"
    done
}

function S {
    ssh -q -o StrictHostKeyChecking=no root@192.168.1.1 "$@"
}

function C2 {
    scp -q -o StrictHostKeyChecking=no "$@" root@192.168.1.1:/root/
}

trap killjobs EXIT

IMAGE=$(pwd)/lede.kernel

if [ ! -e "$IMAGE" ]; then
    echo "Missing LEDE image required for test"
    echo "Please download it from:"
    echo "http://lede-project.tetaneutral.net/releases/17.01.0/targets/armvirt/generic/lede-17.01.0-r3205-59508e3-armvirt-zImage-initramfs"
    exit -1
fi

# TODO - very heavy handed, fit for container/vm like travis
sudo killall qemu-system-arm
sudo "$(pwd)/start_qemu_armvirt.sh" "$IMAGE" > /dev/null < /dev/null &

echo waiting for ssh on qemu
waitfortcp 192.168.1.1 22

# Provision LEDE - Install syncer
# luaposix & luasocket are installed by default on LEDE 17+
S ash < lede.setup_network.sh
S opkg update
S opkg install luaposix luasocket
cp lede.config.test.template lede.config.test
echo "SSH_USER='$SSH_USER'" >> lede.config.test
echo "TARGET_PATH='$TARGET_PATH'" >> lede.config.test
C2 lede.key sync_sd_to_remote lede.config.test sync_sd_to_remote.lua fa_*.lua oswrap.lua iowrap.lua
# one time: add lede.key.pub to authorized keys of the target ssh account
SDROOT=/tmp/flashair_lede_test_root/
rm -Rf $SDROOT
CSVROOT=$SDROOT/CSVFILES/LOG
mkdir -p $CSVROOT
for f in a.csv b.csv c.csv; do
    echo 1,1,1 > $CSVROOT/$f
done

# clean directory first (note: this must sync with lede.config.test)
ssh "$SSH_USER@localhost" rm -R "$TARGET_PATH" \; mkdir -p "$TARGET_PATH"

# Start Flashair card simulator
./sdcardemul.py --dir $SDROOT &

echo waiting for sdcardemul
waitfortcp 192.168.1.101 8000
S /root/sync_sd_to_remote /root/lede.config.test

# verify it worked correctly
LOCALPATH=/tmp/flashair_test_output
rm -Rf $LOCALPATH

echo "rsync from target locally for comparison"
rsync -ra "$SSH_USER@localhost:$TARGET_PATH/" "$LOCALPATH/"

echo "comparing"
python3 -c "import test, os; os._exit(int(not test.is_same('$CSVROOT', '$LOCALPATH')))"
EXIT_CODE=$?
echo "result: $EXIT_CODE"
exit $EXIT_CODE
