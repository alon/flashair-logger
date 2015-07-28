Synopsys
========

This project started as a means to copy data from a sd accessible device to the interwebs.

The sd carrying device (SCD) logs data every set amount of seconds about wind direction, power, and battery voltage. The problem was getting that data from the SCD to a website.

`<diagram missing here: SCD->Flashair->OpenWRT->3G->Website>`

Installation
============

Installing the router
---------------------

**Setup of a new TL-WR703N router with openwrt preinstalled**

 * Start with an empty `SLboat_Mod TP-LINK TL-WR703N`
 * connect ethernet to laptop, laptop uses dhcp
 * remove `~/.ssh/known_hosts` offending lines for ssh access
 * ssh into it. default password is unset, with telnet enabled. Login via telnet, set password. Add ssh pub key via: http://192.168.1.1/cgi-bin/luci/;stok=050e6ecb7ab80178f16ec1b9aa83b690/admin/system/admin (just an example, stok will be different) or manually via concatenating your public key (openssh .pub file):

 `ssh root@openwrt "echo $(cat ~/.ssh/id_rsa.pub) >>/etc/dropbear/authorized_keys;chmod 0600 /etc/dropbear/authorized_keys"`

  * setup networking via host
    * If host is connected via wireless, and in the hackerspace, and host has IP of 192.168.1.239:
      * host: `masquerade_via_wlp3s0` (see below)
      * host: `sudo iptables -F` (fixme)
      * wrt: `route add default gw 192.168.1.239`
      * wrt: `echo nameserver 10.81.2.1 > /etc/resolv.conf`
  * change hostname to melogger: `admin/system/system`
  * set timezone to Beirut: `admin/system/system`
`
 opkg update
 opkg install packages for gsm and lua:
 opkg remove usb-uhci
 opkg install usb-modeswitch usb-modeswitch-data comgt kmod-usb-serial kmod-usb-serial-option kmod-usb-acm luci-proto-3g luasocket luaposix
 opkg install usb-ohci kmod-usb-serial-wwan
`
 * reboot. perhaps not required, but I had problems with uhci/ohci or this. Need to redo instructions to test this point.
 * setup flashair card wireless as client
  * use wizard: scan, choose flashair, use password. called wwan (the default)
  * go to interfaces, select wwan, advanced, disable both "Use default gateway" and "Use DNS servers advertised by peer".
 * connect gsm dongle, insert sim
 * setup gsm networking
  * create new interface called '''umts''', for cellcom APN is internetg, the rest is empty (no username, no password)
  * move it to "wan" zone
  * open ssh on wan zone by adding the following in /etc/config/firewall before the final 'include' line:
`
 config rule
   option name  'accept ssh on wan'
   option src              wan
   option dest_port        22
   option target           ACCEPT
   option proto            tcp
`
  * back at the console run:
`
 mkdir /root/.ssh
 chmod 700 /root/.ssh
 dropbearkey -f /root/.ssh/id_rsa -t rsa
`
 * copy over the public key to cometme server at `/.ssh/authorized_keys`
 * test that you can ssh to cometme: `ssh -l user -i /root/.ssh/id_rsa server`
 * host: `git clone git://gitorious.org/air-sd-logger/air-sd-logger.git`
 * host: `cd air-sd-logger`
 * host: `make update` (assumes ip of router is 192.168.1.1)
  * copies over main executable to `/usr/bin/sync_sd_to_remote` and config file to `root/config.lua`
 * test: run executable locally once.
  * `sync_sd_to_remote /root/config.lua`
 * setup cron job:
  * `echo '30 0 * * * /usr/bin/syncsdtocomet /root/config.lua > /root/syncsdtocomet.last.log' > /etc/crontabs/root`
  * `/etc/init.d/cron start`
  * verify via `logread` that no parsing errors occured in `/etc/crontabs/root`
  * verify symlink in /etc/rc.d
 * test cron job (check the output, setup time close to it, wait)
  * `date 00:29`
  * `logread -f`
  * wait 60 seconds
  * `^C`
  * you should see a line: Nov 12 00:30:01 melogger cron.info crond[2727]: crond: USER root pid 2762 cmd /usr/bin/syncsdtocomet /root/config.lua > /root/syncsdtocomet.last.log
 * verify everything is running after a reboot
  * verify crond is running, there is an internet connection, and an sd card connection.
 * verify everything is running without ethernet connection
  * remove ethernet cable.
  * reboot forcibly (remove power).
  * wait 60 seconds.
  * verify: modem is blinking green (ZTE 190), wrt led is solid blue.
 * setup dynamic dns
  * create an account at duckdns.org
  * follow wrt instructions
   * opkg install ddns-scripts luci-app-ddns
   * update configuration via luci: `services->dynamic` dns. The config file:
`
 config service 'duckdns'
   option enabled '1'
   option domain '<the domain>'
   option username 'NA'
   option password '<the token>'
   option force_interval '72'
   option force_unit 'hours'
   option check_interval '10'
   option check_unit 'minutes'
   option update_url 'http://www.duckdns.org/update?domains=[DOMAIN]&token=[PASSWORD]&ip=[IP]'
   option interface 'umts'
   option ip_source 'interface'
   option ip_interface '3g-umts'
`
 * setup constant ip for cellcom:
  * change APN to statreal in `/etc/config/network` or via luci

Installing the flashair card
----------------------------

### What is the Flashair

It is a SDIO card that is also an Access Point. We use the 16 GB class 10 card.
* http://www.toshiba-components.com/FlashAir/
* https://www.flashair-developers.com/en/about/overview/

### Configuration of the Flashair card

The card contains a `SD_WLAN/CONFIG` file (see [https://www.flashair-developers.com/en/documents/api/config/ guide]), it needs to be edited to contain the following:
`
 APPSSID=cometmelogger
 APPAUTOTIME=0
 APPNETWORKKEY=haleycometme
 LOCK=1
`

Setup on the remote server
--------------------------

Notes
=====

rsync for flashair
------------------

openwrt on wrt701 connected to flashair, with 3g modem connected to internet

 * sd & wireless card combo (wifisd, flashair)
 * http server on port 80, with whole filesystem contents.
 * Files are stored at: SD CARD/CSVFILES/LOG
 * 192.168.0.1/24
 * (development on ethernet, 192.168.1.1/24)
 * periodically connect to a remote server via ssh

Data flow overview
------------------

 * communication:
  * flashair -> openwrt wr703n w/ 3g modem -> host-on-cloud
 * communication paths
  * logger [sd slot]-> flashair sd card [flashair wifi]<-> openwrt [usb socket]-> usb extension cable 10m (hub + 2x5m) [usb socket]-> 3g modem [gsm]->[internet]->[ssh]-> host on cloud
 * physical
  * logger
   * flashair sd card
  * TL-WR703N
   * power adapter
   * usb extension 5 m
    * hub
     * usb extension 5 m
      * 3g modem

Helper: Masquerade script
-------------------------

`
 #!/bin/bash
 # symlink me to "masquerade_via_INTERFACE", i.e. masquerade_via_em1 if you are connected to ethernet, masquerade_via_wlp3s0 if wlp3s0 is your wireless interface name.
 if [ $UID != 0 ]; then
     exec sudo $0
 fi
 BASE=`basename $0`
 TARGET=${BASE#masquerade_via_}
 echo 1 > /proc/sys/net/ipv4/ip_forward
 echo masquerading anything to $TARGET
 iptables -t nat -F
 iptables -t nat -A POSTROUTING -o $TARGET -j MASQUERADE
`

Troubleshooting
---------------

 * Modem should ''blink green'' when connected. It's two faulty modes are:
  * ''Solid Red''. That means the sim didn't register. It is a sim problem, not an openwrt one. Try a different sim. Try sim in phone. Contact gsm provider if nothing works and you can reproduce in a phone.
  * ''Solid Green''. Sim is registered but not in data mode. This is an openwrt configuration error. Try rebooting. Then use logread to look for ppd, or ps. Use '''ubus call network.interface.umts''' status for more details. Try removing usb-uhci and installing usb-uhci, and rebooting after.

Notes
=====

Dropbear
--------

[http://matt.ucc.asn.au/dropbear/dropbear.html dropbear] (minimal disk space implementation):
 * dropbearkey
 * https://yorkspace.wordpress.com/2009/04/08/using-public-keys-with-dropbear-ssh-client/
 * comet-me server is hosted weirdly, the root is at /, so you need to place the public keys in /.ssh/authorized_keys (permissions 700 for directory, 600 for file)

Cronjob
-------

Copying is done 1 per minute with a cronjob

* * * * * /root/pushlog

Wireless connection as client on openwrt
----------------------------------------

The flashair client wireless connection was created with the "wizard" from the scanned access points and then manually set to
# ignore routes
# ignore dns

This is important since it takes precedence during name resolution since it appears *last*, i.e. the reverse of the usual name resolution order (as by glibc). This is a dnsmasq-ism. The actual resolv.conf is in /tmp/resolv.conf.auto I believe (writing from memory)

dropbear scp client doesn't have an option to set the user name, and since the user name contains an at sign (@) I used cat (8 bit clean when ssh is used without a pty, i.e. running a command, at least I hope - only tested text files..)

Secondly, ssh of dropbear needs an explicit identity to do public key authentication. The whole /root/pushlog is:

 #/bin/sh
 wget -o - -q http://192.168.0.1/CSVFILES/LOG | ssh -i ~/.ssh/id_rsa -l user@name example.com "cat > $HOME/LOG"

GDM/3G Modem with Antenna
-------------------------

One of the requirements is to have the modem in a cave, and the antenna external. One solution would be a long usb cable, but it looks like it would be less robust to random errors, so we are going with a long antenna.

ZTE 190MF
---------

That's what we currently use, supported well with openwrt.

Huawei 3131
-----------

Relatively new (2012), at [http://www.huaweidevice.com.eg/Product-Description/Data-cards-E3131.php Huawei]

Final cart:
* 15ft RG58 External Antenna Extension Coax RF Jumper Cable FME male to FME female
* 5dbi 900MHz GSM Antenna cable with FME female magnetic
* FME plug TO TS9 right angle connector with 15cm cable antenna HUAWEI ZTE adapter pigtail cable customize free shipping
** plug == Male (pin in the middle).

Purchase links:
* [http://www.aliexpress.com/item/free-shipping-HUAWEI-E3131-4G-3G-21M-USB-Dongle-E3131-HUAWEI-Modem/765958826.html Modem@aliexpress]
* [http://www.amazon.com/Huawei-External-magnetic-antenna-adapter/dp/B00DF32B9W/ref=pd_sim_sbs_cps_1 Antenna@amazon]
* [http://www.amazon.com/External-Antenna-Adapter-Pigtail-connector/dp/B00C4KPSY2 Adapter] Cable for external antenna (contradicts antenna above)
** CRC9 to FME-male Right-Angle Patch Cable

Reference
---------

SMA, RPSMA
* http://www.amphenolrf.com/products/CatalogPages/SMA.pdf
* https://en.wikipedia.org/wiki/SMA_connector
* https://www.sparkfun.com/pages/RF_Conn_Guide

CRC9, TS9 - TODO

FME
* https://en.wikipedia.org/wiki/FME_connector

= SD Card with Wifi =
This is hopefully identical to what Noam has:
* 4GB SD (Secure Digital) Eye-Fi card - Includes Wifi module that allows wireless data transfer to any wifi-enabled device - Easy setup and photo sharing with included software - Automatic file upload frees memory card space - Device compatibility with SDHC format - Included USB adapter - Class 4 Speed rating
** 206 nis in plonter

openwrt setup
-------------

* starting from OpenWrt_SLboat_Mod - second attempt. Thanks Yair!
* wifi left for last, first setup usb gsm dongle
* adding ssh key via system->administration menu item (/etc/config/somewhere FILLME)
* using Huawei 3131
* get working internet. since wifi is off got it via masquerade from laptop.
* Installing extra packages per http://wiki.openwrt.org/doc/recipes/3gdongle
** cannot see device (/sys/kernel/debug/usb/devices shows the device with (None) driver)
** installing kmod-usb-net-cdc-ether (saw fedora use it)
* installed modeswitch (needed too according to fedora)
* Created /etc/usb_modeswitch.d/12d1:14db (copied from 14d1)
 # Huawei E3131
 
 TargetVendor=  0x12d1
 TargetProduct= 0x14db
 
 MessageContent="55534243123456780000000000000011062000000100000000000000000000"

3g (umts) setup
---------------

** after looking at everything of huawei it seems the MessageContent is almost always the same.
* APN for rami levy: http://www.unlockit.co.nz/mobilesettings/settings.php?id=698
** APN/user/pass: internet.rl / 	rl@3g / rl
** unneeded: MMC 425 / MNC 03

* cdc_ether works, but now it isn't appropriate for all the gcom (serial) oriented howto's.
* ifconfig -a shows eth1 with hw addr (static?) 58:2C:80:13:92:63
** attempting to do ifconfig up does a reboot. not a good sign. maybe reuse my old stick for now.

switched back to cdc_acm using modem (ZTE190M ?)
* '''logread''' for log debugging. Showing failure:
 Sep  8 18:02:16 OpenWrt_SLboat_Mod local2.info chat[19013]: AT+CGDCONT=1,"IP","internet.rl"^M^M
 Sep  8 18:02:16 OpenWrt_SLboat_Mod local2.info chat[19013]: OK
 Sep  8 18:02:16 OpenWrt_SLboat_Mod local2.info chat[19013]:  -- got it
 Sep  8 18:02:16 OpenWrt_SLboat_Mod local2.info chat[19013]: send (ATD*99***1#^M)
 Sep  8 18:02:16 OpenWrt_SLboat_Mod local2.info chat[19013]: expect (CONNECT)
 Sep  8 18:02:16 OpenWrt_SLboat_Mod local2.info chat[19013]: ^M
 Sep  8 18:02:16 OpenWrt_SLboat_Mod local2.info chat[19013]: ATD*99***1#^M^M
 Sep  8 18:02:16 OpenWrt_SLboat_Mod local2.info chat[19013]: ERROR

This was fixed by seemingly removing and reinserting the dongle. So it had some state which I don't know how to query or reset yet. If I can figure it out I can add it to the chat script. In the debugging process verified it works on my main machine by "systemctl stop ModemManager; systemctl stop NetworkManager"; remove and reinsert dongle to my machine. use minicom to isue the above commands: one that isn't shown, and AT+CGDCONT=1,"IP","internet.rl" plus ATD*99***1# and got CONNECT 7200000 (maybe an extra zero there).

= Networking setup on the OpenWRT =

Two zones:
* lan: contains umts + lan (yes, lan is the zone label and a network label)
* wan: actually wrongly named, this contains just wwan (again wrongly named), the wireless flashair (Client mode) connection.

Zone firewall config - the masquerade is for using the internet connection (since I didn't have two) and can be turned off, but since it requires a lan connection to be effective it doesn't pose a security problem, so better leave it for convenience when debugging.
* '''lan''': Input accept, Output accept, Forward accept, Masquerade on, MSS clamping off.
* '''wan''': Input reject, Output accept, Forward reject, Masquerade off, MSS clamping off.

Networks: we have three, one bridge (pointless but there), pay attention:
* LAN: bridge is '''br-lan''', it contains the ethernet interface (eth0) only.
* UMTS: contains 3g-umts.
* WWAN: contains Client flashair. The client was created via the "scan" button on the interface.

A quick way to create all of these is just to ignore the above and dump the following files inside /etc/config:

/etc/config/network:
 config interface 'loopback'
 	option ifname 'lo'
 	option proto 'static'
 	option ipaddr '127.0.0.1'
 	option netmask '255.0.0.0'
 
 config interface 'lan'
 	option ifname 'eth0'
 	option type 'bridge'
 	option proto 'static'
 	option ipaddr '192.168.1.1'
 	option netmask '255.255.255.0'
 
 config interface 'umts'
 	option proto '3g'
 	option apn 'internet.rl'
 	option username 'rl@3g'
 	option password 'rl'
 	option device '/dev/ttyUSB2'
 	option service 'umts'
 
 config interface 'wwan'
 	option proto 'dhcp'
 	option defaultroute '0'
 	option peerdns '0'

Notice ''ttyUSB2''! the modem I'm using comes up with 3 serial interfaces after usb modeswitch finishes turning it from a storage device to a modem, and only the third is usable as a modem (maybe the others are for firmware upload or a non AT interface or debugging).

/etc/config/wireless:

 # cat /etc/config/wireless
 
 config wifi-device 'radio0'
 	option type 'mac80211'
 	option hwmode '11ng'
 	option macaddr '8c:21:0a:ee:f4:50'
 	option htmode 'HT20'
 	list ht_capab 'SHORT-GI-20'
 	list ht_capab 'SHORT-GI-40'
 	list ht_capab 'RX-STBC1'
 	list ht_capab 'DSSS_CCK-40'
 	option txpower '27'
 	option country 'US'
 	option disabled '0'
 	option channel '6'
 
 config wifi-iface
 	option network 'wwan'
 	option ssid 'flashair'
 	option encryption 'psk2'
 	option device 'radio0'
 	option mode 'sta'
 	option bssid 'E8:E0:B7:18:8B:DF'
 	option key '<password here>'

Copying things over from SD to an ssh server somewhere
------------------------------------------------------

I would really like to use rsync, but for that I would need to have a sort of http filesystem. Barring that, poor man's rsync:
* generate a list of files on card, and their dates in memory
* for each file, record last time it was synced (/root/sdsync/file_name is an ascii file containing that time - or just touch it with that time, even better)
* if that is older then current date of file then sync.
* to optimize sync, do it in one go by using something like uuencode: (for file in files; uuencode file -) | ssh uudecode_all_files

Helpers
-------

# cat /usr/bin/listsd
 #!/bin/sh
 wget -O - -q http://192.168.0.1/CSVFILES/LOG | grep -e '^wlansd\[' | sed -e 's/wlansd\[[0-9]*\]="//' | sed -e 's/";//'

Lua
---
* splitting and joining strings: http://lua-users.org/wiki/SplitJoin
* popen implementation that doesn't block, maybe: 
* serialization to lua: http://www.lua.org/pil/12.1.1.html
** using load(function) for lua 5.1 compatibility (as opposed to load(string)

Sources
-------
https://gitorious.org/air-sd-logger/air-sd-logger/

Visualization
-------------
D3: http://tonygarcia.me/slides/d3chartintro/

Or maybe python: https://github.com/ContinuumIO/Bokeh
Also see this completely unrelated [http://www.talyarkoni.org/blog/2012/06/08/r-the-master-troll-of-statistical-languages/ post] on python becoming the defacto language for scientific data processing

Buying List
-----------
TODO: where are the eyecards

Development
-----------
Using [http://wiki.openwrt.org/doc/howto/docker_openwrt_image docker]

TODO
----

Complete test setup using x86 openwrt (for fast testing) and arm openwrt (for closer to hardware)
- openwrt image
- connect to a server image

Main problems
- emulation of usb gsm dongles - at least enough to fool openwrt / luci / to test the install flow.
