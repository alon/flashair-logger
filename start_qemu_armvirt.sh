#!/usr/bin/env bash

if [ "$UID" != "0" ]; then
    exec sudo "$0" "$1"
fi

IMAGE=$1

if [ "x$IMAGE" = "x" ]; then
    echo "usage: $0 <zimage_with_initramfs>"
    exit -1
fi

if [ ! -e "$IMAGE" ]; then
    echo "given image does not exist: $IMAGE"
    exit -1
fi

# For reference: running with user networking. no ssh access (no visible ports)
#qemu-system-arm -net nic,vlan=0 -net nic,vlan=1 -net user,vlan=1 \
#    -nographic -M virt -m 64 -kernel $IMAGE

LAN=ledetap0
# create tap interface which will be connected to LEDE LAN NIC
ip tuntap add mode tap $LAN
ip link set dev $LAN up
# configure interface with static ip to avoid overlapping routes                         
ip addr add 192.168.1.101/24 dev $LAN

qemu-system-arm -nographic -M virt -m 64 \
  -netdev tap,id=lan,ifname=$LAN,script=no,downscript=no \
  -device virtio-net-pci,netdev=lan \
  -kernel "$IMAGE"

# cleanup. delete tap interface created earlier
ip addr flush dev $LAN
ip link set dev $LAN down
ip tuntap del mode tap dev $LAN 
