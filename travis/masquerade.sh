#!/bin/bash
TARGET=eth0
echo 1 > /proc/sys/net/ipv4/ip_forward
echo "==== Masquerading anything to $TARGET"
iptables -F
iptables -t nat -F
iptables -t nat -A POSTROUTING -o $TARGET -j MASQUERADE
echo "==== IPTABLES on host"
iptables -L
echo "==== NAT"
iptables -t nat -L
