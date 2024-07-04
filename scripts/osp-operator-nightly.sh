#!/usr/bin/env bash
# Copyright 2024 Chmouel Boudjnah <chmouel@chmouel.com>
set -euxfo pipefail

TMP=$(mktemp /tmp/.mm.XXXXXX)
clean() { rm -f $TMP; }
trap clean EXIT

# only install the 1.x version  so adjust  that number in the regexp if one it goes to 2.
installLatestOperatorBuildSub() {
	local artifactUrl="https://artifacts.ospqa.com/builds/"
	local artifactsToGrab="catalog-source.yaml image-content-source-policy.yaml"
	curl --fail-early -f -k $artifactUrl >$TMP || {
		echo "Failed to get $artifactUrl" >&2
		exit 1
	}
	ocversion=$(oc version | sed -n '/Server Version/ { s/.* //;s/^\([0-9]*\.[0-9]*\).*/\1/; p; }')
	local lastversion
	lastversion=$(sed -n '/^<a href=.1\./ { s,.*".\([^/]*\).*,\1,; p; }' $TMP | sort --version-sort -r | head -1)
	local buildUrl="${artifactUrl}${lastversion}/"

	curl --fail-early -f -k $buildUrl >$TMP || {
		echo "Failed to get $buildUrl" >&2
		exit 1
	}
	local latestOpenShiftVersion
	latestOpenShiftVersion=$(sed -n '/.a href./ {s,.a href=.\([^/]*\).*,\1,;p}' $TMP | grep -E "^.*-${ocversion}" | sort -Vr | head -1)
	local latestOpenShiftUrl="${buildUrl}${latestOpenShiftVersion}"

	for yaml in $artifactsToGrab; do
		curl --fail-early -o$TMP -f -k "${latestOpenShiftUrl}/${yaml}" || {
			echo "Failed to get ${latestOpenShiftUrl}${yaml}" >&2
			exit 1
		}
		kubectl apply -f $TMP
	done

	echo "Installed ${artifactsToGrab} from $latestOpenShiftUrl"
}

installCustomOperator() {
	cat <<EOF | kubectl apply -f-

  apiVersion: operators.coreos.com/v1alpha1
  kind: Subscription
  metadata:
    name: openshift-pipelines-operator
    namespace: openshift-operators
  spec:
    channel: latest
    name: openshift-pipelines-operator-rh
    source: custom-operators
    sourceNamespace: openshift-marketplace
EOF

	kubectl patch tektonconfig config --type="merge" -p '{"spec": {"platforms": {"openshift":{"pipelinesAsCode": {"enable": true}}}}}' 2>/dev/null || true

	i=0
	while true; do
		[[ ${i} == 120 ]] && exit 1
		ep=$(kubectl get ns openshift-pipelines || true)
		[[ -n ${ep} ]] && break
		sleep 5
		i=$((i + 1))
	done

	i=0
	for tt in tekton-pipelines-webhook tekton-triggers-webhook pipelines-as-code-controller pipelines-as-code-watcher; do
		while true; do
			[[ ${i} == 120 ]] && exit 1
			ep=$(kubectl get ep -n openshift-pipelines ${tt} -o jsonpath='{.subsets[*].addresses[*].ip}' || true)
			[[ -n ${ep} ]] && break
			sleep 5
			i=$((i + 1))
		done
	done
}

installLatestOperatorBuildSub
installCustomOperator
