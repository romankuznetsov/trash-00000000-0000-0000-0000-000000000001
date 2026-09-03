# SPDX-License-Identifier: GPL-3.0-or-later
#
# The qWDTT client, compiled from the client/ directory of this repository.
#
# 25.12 and newer only, and not by choice: golang.org/x/crypto requires
# go >= 1.25.0 and the 24.10 feed ships go 1.23.4. Lowering our own go
# directive does not help, because the floor comes from the dependencies.
# The two arch-independent
# packages in this feed stay buildable on both SDKs.

include $(TOPDIR)/rules.mk

PKG_NAME:=qwdtt-client
# The repository's tag, shared with qwdtt and luci-app-qwdtt.
PKG_VERSION:=1.0.2
PKG_RELEASE:=1

PKG_MAINTAINER:=
PKG_LICENSE:=GPL-3.0-or-later
# No PKG_LICENSE_FILES: it names a path inside a package's unpacked sources,
# and the build directory here is a copy of client/, which has no LICENSE of
# its own -- the repository keeps one at its root.

PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1

# A bare module name, not a domain path. golang-build.sh uses GO_PKG only as a
# directory name under src/, and module mode resolves imports from go.mod, so
# the unusual name is not a problem -- but it does decide the built binary's
# name, which is why the install rule below is explicit.
GO_PKG:=wg-turn-client
# The release workflow builds with -tags=openwrt too. Without it the wrong
# raw-socket implementation is selected.
GO_PKG_TAGS:=openwrt

include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk

# golang-package.mk hardcodes CGO_ENABLED=1 in GO_PKG_TARGET_VARS with no knob
# to turn it off, and on mipsel that fails: assembling Go's own cgo runtime
# stops with "gcc_mipsx.S: invalid operands `sw $18,12($29)'". Nothing here
# needs cgo -- the release workflow has always cross-compiled this client with
# CGO_ENABLED=0, for mipsle included -- so switch it off. These become shell
# assignments prefixed to the build command, where a later duplicate wins.
GO_PKG_VARS += CGO_ENABLED=0
# ...and -linkmode external, which the same file sets unconditionally, needs
# cgo. Clearing it leaves the toolchain's own internal linking, which is what
# a static CGO_ENABLED=0 build wants anyway.
GO_PKG_DEFAULT_LDFLAGS=

# `feeds install` symlinks each package directory individually into
# package/feeds/<feed>/, so CURDIR is that symlink and a plain $(CURDIR)/..
# points at the feed's install directory rather than at this repository.
# Resolving CURDIR first lands back in the checkout, where client/ is a
# sibling of this Makefile's directory.
QWDTT_CLIENT_SRC:=$(dir $(realpath $(CURDIR)))client

define Package/qwdtt-client
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=VPN
  TITLE:=qWDTT tunnel client
  URL:=https://github.com/romankuznetsov/qwdtt-openwrt
  DEPENDS:=$(GO_ARCH_DEPENDS) +ca-bundle +kmod-tun
endef

define Package/qwdtt-client/description
The client half of qWDTT, a novel VPN based on the WDTT protocol family that
tunnels traffic through VK TURN servers. It creates the TUN interface and
carries the LAN's IPv4 traffic to a qWDTT server.

Compiled from source. Neither the control script nor the LuCI page is here:
see the qwdtt and luci-app-qwdtt packages.
endef

# No PKG_SOURCE: the source is in this repository, so there is nothing to
# fetch and nothing to pin. golang-build.sh enables module mode only when
# go.mod sits at the build directory root -- it tests `-f $BUILD_DIR/go.mod`
# and silently falls back to GOPATH mode otherwise, which cannot work for a
# module with dependencies -- so client/ is copied to be the build directory
# rather than copied underneath one.
define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) $(QWDTT_CLIENT_SRC)/. $(PKG_BUILD_DIR)/
endef

# Not GoBinPackage: `go build` names the binary after the module, so the
# default install would produce /usr/bin/wg-turn-client. The control script
# and the LuCI helpers both call /usr/bin/qwdtt-client, so the name is set
# here instead.
define Package/qwdtt-client/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(GO_PKG_BUILD_BIN_DIR)/wg-turn-client \
		$(1)/usr/bin/qwdtt-client
endef

$(eval $(call BuildPackage,qwdtt-client))
