#Owned by alon dot levy at pobox dot com
#
#Copyright GNU act.
include $(TOPDIR)/rules.mk

PKG_NAME:=flashair-openwrt-logger
PKG_VERSION:=1.000
PKG_RELEASE:=1

PKG_MAINTAINER:=Created by Alon Levy/makefile by Cobia@whirlpool
include $(INCLUDE_DIR)/package.mk

define Package/flashair-openwrt-logger
  SECTION:=utils
  CATEGORY:=Network
  TITLE:=flashair-openwrt-logger
  PKGARCH:=all
  URL=https://github.com/alon/flashair-openwrt-logger
  MAINTEAINER:=Alon Levy <alon@pobox.com>
  DEPENDS:=+lua +luaposix +luasocket
endef

define Package/flashair-openwrt-logger/description
  Directory copying from Toshiba FlashAir cards to SSH server
endef


define Build/Compile
endef

define Package/flashair-openwrt-logger/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_DIR) $(1)/usr/bin
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,flashair-openwrt-logger))
