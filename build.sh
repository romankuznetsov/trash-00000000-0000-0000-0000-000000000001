#!/bin/sh

set -eu

FEEDNAME=qwdtt
# The two arch-independent packages. qwdtt would also be built as a dependency
# of luci-app-qwdtt, but naming it explicitly is what makes it asserted below
# and keeps it building if that dependency ever goes away.
PACKAGES='luci-app-qwdtt qwdtt'
# qwdtt-client is 25.12-only, and not by choice: golang.org/x/crypto requires
# go >= 1.25.0 and the 24.10 feed ships go 1.23.4, so the build stops before it
# starts. The floor comes from the dependencies, not from our own go directive
# -- the ipk side of this
# feed therefore carries the two arch-independent packages only.
PACKAGES_APK='qwdtt-client'
# The '#v11' is a git ref for docker build, and it pins the same tag the
# workflow does. Without it this tracked the action's default branch while CI
# tracked whatever it had at the time, so the two could diverge silently.
SDK_REPO=https://github.com/openwrt/gh-action-sdk.git#v11
DISTDIR=dist

# The output FORMAT follows the SDK version rather than any flag or option:
# OpenWrt replaced opkg with apk, so a 24.10 SDK emits .ipk and a 25.12 SDK
# emits .apk from identical sources. One architecture serves every target
# because the package sets LUCI_PKGARCH:=all.
#
# Both are pinned to a release, matching the workflow. The bare x86_64 tag is
# the snapshot SDK, which does not ship the SDK inside the image and so
# downloads and extracts it on every run -- around six times the wall clock,
# for a moving target that makes a red build ambiguous.
ARCH_IPK=x86_64-24.10.0
ARCH_APK=x86_64-25.12.5

# Git Bash rewrites arguments that look like absolute Unix paths into Windows
# paths, which would turn the container-side /feed into something like
# C:/Program Files/Git/feed. Ignored on Linux and macOS.
MSYS_NO_PATHCONV=1
export MSYS_NO_PATHCONV

# Run from the repository root whatever the caller's directory, since the whole
# root is the feed that gets mounted.
cd "$(dirname "$0")"

usage() {
	cat <<EOF
usage: ./build.sh <command>

  ipk     build .ipk  (SDK $ARCH_IPK): $PACKAGES
  apk     build .apk  (SDK $ARCH_APK): $PACKAGES $PACKAGES_APK
  all     build both
  shell   interactive shell in the SDK container
  clean   remove $DISTDIR/

Output lands in $DISTDIR/<sdk>/bin/packages/*/$FEEDNAME/, one directory per
SDK so 'all' keeps both formats instead of the second wiping the first.
Requires Docker. The first run downloads the SDK image (~1 GB) and takes a
while. The two arch-independent packages compile in seconds; qwdtt-client
compiles a Go toolchain first and takes roughly half an hour cold.

qwdtt-client is built from client/ in this checkout, so a local edit is
picked up with no commit, tag or hash to update first.
EOF
}

# `pwd -W` prints a Windows path (C:/...) under MSYS, which is what Docker
# Desktop needs for a bind mount. Elsewhere it does not exist and plain pwd is
# already right.
host_dir() {
	pwd -W 2>/dev/null || pwd
}

build() {
	_arch=$1
	_image="sdk-$FEEDNAME:$_arch"
	_pkgs=$PACKAGES
	if [ "$_arch" = "$ARCH_APK" ]; then
		_pkgs="$PACKAGES $PACKAGES_APK"
	fi
	# One output directory per SDK. `all` calls this twice and the entrypoint
	# ends with `mv bin/ /artifacts/`, so a single shared directory can only go
	# wrong both ways: cleaned before each build the second run deletes the
	# first's packages, and left in place the mv nests bin/ inside bin/.
	_out="$DISTDIR/$_arch"

	docker build --quiet --tag "$_image" --build-arg "ARCH=$_arch" "$SDK_REPO"

	# :? rather than plain expansion -- an empty value would make this rm -rf /.
	rm -rf "${_out:?}"
	mkdir -p "$_out"

	_host=$(host_dir)

	# NO_SHFMT_CHECK is not about shfmt, and v11 needs it exactly as main did.
	# The entrypoint guards a whole block on it, and inside that block
	# `git -C <pkg>/files diff` runs whether or not there is an *.init file to
	# format -- git then refuses a repository owned by another uid ("dubious
	# ownership in /feed"), the check reads that as a formatting failure, and
	# the checkout after it exits 128. CI never hit it because the action
	# chowns the workspace to 1000:1000 first, which is not an option when the
	# mount is the caller's own tree.
	# Signing is opt-in locally. Point QWDTT_SIGNING_KEY at the EC private key
	# to reproduce what CI does; without it the SDK generates a throwaway key
	# and the packages are untrusted everywhere, which is fine for a build
	# check but not for anything a router should install.
	_sign=""
	if [ -n "${QWDTT_SIGNING_KEY:-}" ]; then
		_sign=$(cat "$QWDTT_SIGNING_KEY")
	fi

	docker run --rm \
		--env NO_SHFMT_CHECK=1 \
		--env "FEEDNAME=$FEEDNAME" \
		--env "PACKAGES=$_pkgs" \
		--env "PRIVATE_KEY=$_sign" \
		--volume "$_host:/feed" \
		--volume "$_host/$_out:/artifacts" \
		"$_image"

	echo "--- built:"
	find "$_out/bin" -type f \( -name '*.ipk' -o -name '*.apk' \) | sort

	for _want in $_pkgs "luci-i18n-$FEEDNAME-ru"; do
		_n=$(find "$_out/bin" -type f \
			\( -name "$_want*.ipk" -o -name "$_want*.apk" \) | wc -l)
		if [ "$_n" -eq 0 ]; then
			echo "$_want was not produced" >&2
			exit 1
		fi
	done
}

case "${1:-}" in
ipk)
	build "$ARCH_IPK" ;;
apk)
	build "$ARCH_APK" ;;
all)
	build "$ARCH_IPK"
	build "$ARCH_APK" ;;
clean)
	rm -rf "$DISTDIR" ;;
shell)
	# For diagnosing a failure from inside: the SDK and the mounted feed are
	# both present, and the entrypoint is bypassed.
	docker run --rm -it \
		--volume "$(host_dir):/feed" \
		--entrypoint /bin/bash \
		"ghcr.io/openwrt/sdk:${2:-$ARCH_IPK}" ;;
'' | -h | --help | help)
	usage ;;
*)
	echo "unknown command: $1" >&2
	usage >&2
	exit 2 ;;
esac
