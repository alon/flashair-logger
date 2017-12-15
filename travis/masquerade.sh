#!/bin/bash
TARGET=eth0
echo 1 > /proc/sys/net/ipv4/ip_forward
echo masquerading anything to $TARGET
iptables -F
iptables -t nat -F
iptables -t nat -A POSTROUTING -o $TARGET -j MASQUERADE
