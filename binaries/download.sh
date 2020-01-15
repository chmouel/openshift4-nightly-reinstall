#!/usr/bin/env bash
# Chmouel Boudjnah <chmouel@redhat.com>
version=latest
base="ocp"
[[ $1 == "-d" ]] && { base="ocp-dev-preview"  ; shift ;}
[[ -n ${1} ]] && version=${1}
URL=https://mirror.openshift.com/pub/openshift-v4/clients/${base}/${version}
set -e
DEST=${DEST:-.}
set -x
version=$(curl -s ${URL}/release.txt |sed -n '/Version:/ { s/.*:[ ]*//; p ;}')

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
esac
echo ${URL}/openshift-client-${platform}-${version}.tar.gz
exit 
echo -n "Downloading openshift-clients-${version}: "
curl -sL ${URL}/openshift-client-${platform}-${version}.tar.gz|tar -C ${DEST} xz -f- oc kubectl
echo "Done."
echo -n "Downloading openshift-installer-${version}: "
curl -sL ${URL}/openshift-install-${platform}-${version}.tar.gz|tar -C ${DEST}  xz -f- openshift-install
echo "Done."
