# SPDX-License-Identifier: GPL-3.0-or-later
#
# A plain package rather than a luci.mk one, and separate from luci-app-qwdtt
# on purpose. This script is the tunnel's control layer: cron drives 'heal'
# and the procd interface triggers drive 'netchange', neither of which
# involves a browser, so a headless router needs it with no web interface
# installed. luci-app-qwdtt depends on it instead of shipping it.
#
# It ships the service layer: the control script, the procd init script that
# turns /etc/config/qwdtt into the client's command line, a default config and
# the firewall zone. Everything except the client binary, which is the separate
# qwdtt-client package.

include $(TOPDIR)/rules.mk

PKG_NAME:=qwdtt
# One tag versions the whole repository: the client, this script and the LuCI
# app all carry it, so the tag and the package version are always the same
# number and need no lookup table.
PKG_VERSION:=1.0.2
PKG_RELEASE:=1

# Deliberately empty, not forgotten. package-defaults.mk does
# MAINTAINER:=$(PKG_MAINTAINER), and nothing validates the field: it ends up
# as metadata only. Submitting to an official OpenWrt feed would require a
# real one.
PKG_MAINTAINER:=
PKG_LICENSE:=GPL-3.0-or-later

include $(INCLUDE_DIR)/package.mk

define Package/qwdtt
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=VPN
  TITLE:=Control script for the qWDTT tunnel client
  # For -m alone: BusyBox ping cannot set an fwmark, and the probe has to
  # carry mark 2 or it measures the WAN instead and reports success while
  # proving nothing. The cost is 137 KiB and a kmod-crypto-md5 pulled in
  # behind it, which is why this keeps being questioned.
  #
  # Binding the device instead was tried on a live tunnel and rejected.
  # BusyBox does bind the device for -I <ifname>, not merely the source, and
  # `-c10 -A -w4 -I <tun>` is the faster probe by every measure: under 1s
  # healthy and 4s against a dead host, where -i0.3 -m2 takes 3s and 6s, and
  # the 10-packet sample survives both. It does reach the tunnel, confirmed
  # twice over -- 60ms/ttl 117 against the WAN path's 39ms/ttl 107.
  #
  # What it loses is the reason the mark is there: the probe stops passing
  # through `fwmark 0x2 lookup 51820`, so a rule that has gone missing over a
  # live device reads as healthy. That state is one heal repairs, by
  # restarting the daemon that reinstalls the rules, and stale rules do occur
  # here -- the router carries a detached one today.
  #
  # -I <address> is not a third option. It sets the source only, so the
  # packet leaves by the default route: measured at the WAN's 39ms, reporting
  # a healthy tunnel it never entered.
  DEPENDS:=+iputils-ping
  # POSIX shell only: nothing is compiled, so one build serves every target.
  PKGARCH:=all
endef

define Package/qwdtt/description
Command-line control for qWDTT, a novel VPN based on the WDTT protocol family
that tunnels traffic through VK TURN servers.
endef

# No sources to fetch or build; package.mk still wants the directory.
define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

# /etc/config/qwdtt carries the peer, the password and the hashes, so an
# upgrade must never overwrite it.
define Package/qwdtt/conffiles
/etc/config/qwdtt
endef

define Package/qwdtt/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/qwdtt $(1)/usr/bin/qwdtt
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/qwdtt.init $(1)/etc/init.d/qwdtt
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/qwdtt.config $(1)/etc/config/qwdtt
	# 0600, not the 0644 INSTALL_CONF gives: this file holds the connection
	# password once the user fills it in.
	chmod 0600 $(1)/etc/config/qwdtt
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/qwdtt.defaults $(1)/etc/uci-defaults/99-qwdtt
endef

$(eval $(call BuildPackage,qwdtt))
