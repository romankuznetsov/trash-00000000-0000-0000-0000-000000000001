#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Pack a prebuilt qwdtt-client binary into an OpenWrt .ipk (opkg format).
#
# 24.10 and older ship a Go older than the client needs, so their SDK cannot
# compile it at all -- the floor comes from the dependencies, not our own go
# directive. The binary is a
# static CGO_ENABLED=0 ELF, so it does not need the target toolchain: this wraps
# the prebuilt ELF into an .ipk directly, with no SDK Go build. An .ipk is a
# gzip-tar of debian-binary + control.tar.gz + data.tar.gz, and opkg installs a
# local .ipk unsigned -- which is what lets a 24.10 user install the client
# through LuCI with no SSH. On 25.12 the client is shipped as a source-built
# .apk instead; this is the 24.10 counterpart.
#
# Usage: pack-client-ipk.sh <binary> <pkgarch> <version> <outdir>
#   e.g. pack-client-ipk.sh dist/qwdtt-client x86_64 1.0.2-1 dist
set -eu

bin=${1:?binary}
arch=${2:?pkgarch}
ver=${3:?version}
out=${4:?outdir}
[ -f "$bin" ] || { echo "no such binary: $bin" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/data/usr/bin" "$work/control" "$out"
install -m0755 "$bin" "$work/data/usr/bin/qwdtt-client"

{
	echo "Package: qwdtt-client"
	echo "Version: $ver"
	echo "Architecture: $arch"
	echo "Section: net"
	echo "Priority: optional"
	echo "License: GPL-3.0-or-later"
	echo "Installed-Size: $(stat -c%s "$bin")"
	echo "Depends: ca-bundle, kmod-tun, ip-full"
	echo "Description: qWDTT tunnel client (prebuilt static binary)."
} >"$work/control/control"

# Reproducible (fixed owner/mtime). Member order is load-bearing for opkg:
# debian-binary, then control.tar.gz, then data.tar.gz.
TF="--numeric-owner --owner=0 --group=0 --mtime=@0"
# shellcheck disable=SC2086
tar $TF -C "$work/data" -czf "$work/data.tar.gz" ./usr
# shellcheck disable=SC2086
tar $TF -C "$work/control" -czf "$work/control.tar.gz" ./control
echo "2.0" >"$work/debian-binary"

ipk="$out/qwdtt-client_${ver}_${arch}.ipk"
# shellcheck disable=SC2086
tar $TF -C "$work" -czf "$ipk" ./debian-binary ./control.tar.gz ./data.tar.gz
echo "$ipk"
