#!/usr/bin/env bash
# shellcheck disable=SC2015
# Chmouel Boudjnah <chmouel@redhat.com>
set -e
cd $(readlink -f $(dirname $(readlink -f $0)))
version=latest
destdir=arm64
base="ocp"
arch=aarch64/
binaryprefix="-amd64"
[[ $1 == "-d" ]] && {
	base="ocp-dev-preview"
	shift
}
[[ $1 == "-i" ]] && {
	binaryprefix=
	arch=
	destdir=x86
	base="ocp"
	shift
}
[[ -n ${1} ]] && version=${1}
URL=https://mirror.openshift.com/pub/openshift-v4/${arch}clients/${base}/${version}
LURL=https://mirror.openshift.com/pub/openshift-v4/clients/${base}/${version}
DEST=${DEST:-.}
version=$(curl -s ${URL}/release.txt | sed -n '/Version:/ { s/.*:[ ]*//; p ;}')

[[ -z ${version} ]] && {
	echo "Could not detect version"
	exit 1
}

case $(uname -o) in
*Linux)
	platform=linux
	;;
Darwin)
	platform=mac
	;;
*)
	echo "Could not detect platform: $(uname -o)"
	exit 1
	;;
esac

[[ -x ./oc ]] && ./oc version || true
[[ -x ./openshift-install ]] && ./openshift-install version || true

DEST=${DEST}/${destdir}
mkdir -p ${DEST}

u=${LURL}/openshift-client-${platform}-${version}.tar.gz
echo -n "Downloading $u"
curl -sL ${u} | tar -C . -xz -f- oc && ln -sf oc kubectl
echo "Done."
u=${URL}/openshift-install-${platform}${binaryprefix}-${version}.tar.gz
echo -n "Downloading ${u}"
curl -sL ${u} | tar -C ${DEST} -xz -f- openshift-install
echo "Done."

[[ -x ./oc ]] && ./oc version || true
[[ -x ./openshift-install ]] && ./openshift-install version || true
