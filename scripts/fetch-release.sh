#!/usr/bin/env bash
#
# Detect which version of pipeline should be installed
# First it tries nightly
# If that doesn't work it tries previous releases (until the MAX_SHIFT variable)
# If not it exit 1
# It can take the argument --only-stable-release to not do nightly but only detect the pipeline version

# set max shift to 0, so that when a version is explicitly specified that version is fetched
# modify this in future if a workflow based on latest version and recent (shifted) versions is needed
set -eu

CURL_OPTIONS="-s" # -s for quiet, -v if you want debug

MAX_SHIFT=3


TARGET=${1}
UPSTREAM_REPO=${2}
NIGHTLY_RELEASE=${3}
STABLE_RELEASE_URL=${4}

TMPFILE=$(mktemp /tmp/.mm.XXXXXX)
clean() { rm -f ${TMPFILE}; }
trap clean EXIT

function get_version {
    local shift=${1} # 0 is latest, increase is the version before etc...
    curl -f ${CURL_OPTIONS} -o ${TMPFILE} https://api.github.com/repos/${UPSTREAM_REPO}/releases
    local version=$(python -c "from pkg_resources import parse_version;import json;jeez=json.load(open('${TMPFILE}'));print(sorted([x['tag_name'] for x in jeez], key=parse_version, reverse=True)[${shift}])")
    PAYLOAD_PIPELINE_VERSION=${version}
    echo $(eval echo ${STABLE_RELEASE_URL})
}

function tryurl {
    curl --fail-early ${CURL_OPTIONS} -o /dev/null -f ${1} || return 1
}

function geturl() {

    if tryurl ${NIGHTLY_RELEASE};then
         echo ${NIGHTLY_RELEASE}
         return 0
    fi

    for shifted in `seq 0 ${MAX_SHIFT}`;do
        versionyaml=$(get_version ${shifted})
        if tryurl ${versionyaml};then
            echo ${versionyaml}
            return 0
        fi
    done
    echo \n"No working ${TARGET} payload url found"\n
    exit 1
}

URL=$(geturl)
echo ${TARGET} template: ${URL}

# setting this a default so set -u is not failing
[[ -d /tmp/${TARGET,,} ]] || mkdir -p /tmp/${TARGET,,}
curl -Ls ${URL} -o /tmp/${TARGET,,}/release.yaml
