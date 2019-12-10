#!/usr/bin/env bash
# Chmouel Boudjnah <chmouel@redhat.com>
version=latest
[[ -n ${1} ]] && version=${1}
URL=https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${version}
set -e

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
        platform=osx
        ;;
    *)
        echo "Could not detect platform: $(uname -o)"
        exit 1
esac

echo -n "Downloading openshift-clients-${version}: "
curl -sL ${URL}/openshift-client-${platform}-${version}.tar.gz|tar xz -f- oc kubectl
echo "Done."
echo -n "Downloading openshift-installer-${version}: "
curl -sL ${URL}/openshift-install-${platform}-${version}.tar.gz|tar xz -f- openshift-install
echo "Done."
