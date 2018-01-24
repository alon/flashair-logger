#!/usr/bin/env bash

# Run a full LEDE distribution test using qemu-armvirt
#
# run qemu in the background
# qemu: install required packages
# qemu: copy sources
# qemu: copy config file
# host: start externally sdcardemul
# qemu: start test
# host: verify results
# uses ssh to prebuilt host user (can run another system for that host, even another LEDE system)


# TODO: could not set up vm connection to internet on Travis-CI. So going with local packages.
CONNECT_TO_INTERNET=no

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
    scp -r -q -o StrictHostKeyChecking=no "$@" root@192.168.1.1:/root/
}

trap killjobs EXIT

IMAGE=$(pwd)/cache/lede.kernel

if [ ! -e "$IMAGE" ]; then
    echo "Missing LEDE image required for test"
    echo "Please download it from:"
    echo "http://lede-project.tetaneutral.net/releases/17.01.0/targets/armvirt/generic/lede-17.01.0-r3205-59508e3-armvirt-zImage-initramfs"
    echo "to $IMAGE"
    exit -1
fi

# TODO - very heavy handed, fit for container/vm like travis
sudo killall qemu-system-arm
sudo "$(pwd)/start_qemu_armvirt.sh" "$IMAGE" > /dev/null < /dev/null &

echo "waiting for ssh on qemu"
time waitfortcp 192.168.1.1 22

if [ "x$CONNECT_TO_INTERNET" != "xno" ]; then
    # Connet to the external network
    S ash < lede.setup_network.sh
    S "cat > /etc/resolv.conf" < /etc/resolv.conf
    echo "========== host ========="
    ping -c 2 64.6.64.6
    route -n
    cat /etc/resolv.conf
    ifconfig -a
    echo "========== vm ==========="
    S ping -c 2 192.168.1.101
    S ping -c 2 64.6.64.6
    S route -n
    S ifconfig -a
    echo "========================="
    S opkg update
    S opkg install luaposix luasocket
else
    declare -a package_urls
    declare -a package_names
    package_urls=(
        [0]=http://downloads.lede-project.org/releases/17.01.0/targets/armvirt/generic/packages/librt_1.1.16-1_arm_cortex-a15_neon-vfpv4.ipk
        [1]=http://downloads.lede-project.org/releases/17.01.0/packages/arm_cortex-a15_neon-vfpv4/packages/luaposix_v33.2.1-5_arm_cortex-a15_neon-vfpv4.ipk
        [2]=http://downloads.lede-project.org/releases/17.01.0/packages/arm_cortex-a15_neon-vfpv4/packages/luasocket_3.0-rc1-20130909-3_arm_cortex-a15_neon-vfpv4.ipk
    )
    package_names=(
        [0]=librt_1.1.16-1_arm_cortex-a15_neon-vfpv4.ipk
        [1]=luaposix_v33.2.1-5_arm_cortex-a15_neon-vfpv4.ipk
        [2]=luasocket_3.0-rc1-20130909-3_arm_cortex-a15_neon-vfpv4.ipk
    )
    (
        cd cache
        for i in "${!package_urls[@]}"; do if [ ! -e "${package_names[i]}" ]; then wget "${package_urls[i]}" -O "${package_names[i]}"; fi; done
        C2 "${package_names[@]}"
        S opkg install "${package_names[0]}"
        S opkg install "${package_names[1]}" "${package_names[2]}"
    )
fi
cp lede.config.test.template lede.config.test
echo "SSH_USER='$SSH_USER'" >> lede.config.test
echo "TARGET_PATH='$TARGET_PATH'" >> lede.config.test
C2 lede.key sync_sd_to_remote lede.config.test sync_sd_to_remote.lua falog
# one time: add lede.key.pub to authorized keys of the target ssh account
SDROOT=/tmp/flashair_lede_test_root/
[ -e $SDROOT ] && rm -Rf $SDROOT
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
[ -e $LOCALPATH ] && rm -Rf $LOCALPATH

echo "rsync from target locally for comparison"
rsync -ra "$SSH_USER@localhost:$TARGET_PATH/" "$LOCALPATH/"

echo "comparing"
python3 -c "import test, os; os._exit(int(not test.is_same('$CSVROOT', '$LOCALPATH')))"
EXIT_CODE=$?
echo "result: $EXIT_CODE (0 is good)"
exit $EXIT_CODE
