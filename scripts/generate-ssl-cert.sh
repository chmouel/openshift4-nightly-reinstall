#!/usr/bin/env bash
# Author: Chmouel Boudjnah <chmouel@chmouel.com>
set -euxfo pipefail

force=""
genDomain() {
	domain=$1
	certificate=.lego/certificates/$domain.json
	if [[ -n $force ]] || find $(dirname "$certificate") -name $(basename "$certificate") -mtime +75 -print | grep -q .; then
		lego --domains $domain --domains "*.$domain" --email chmouel@chmouel.com --dns route53 --accept-tos=true run
	fi
}

if [[ ${1:-} == "-f" ]]; then
	force=true
	shift
fi
if [[ -n ${1:-} ]]; then
	genDomain $1
	exit
fi
for file in $(fd -tf .json$ .lego/certificates); do
	if [[ $file =~ /([^/]+)\.json$ ]]; then
		domain=${BASH_REMATCH[1]}
		genDomain $domain
	fi
done
