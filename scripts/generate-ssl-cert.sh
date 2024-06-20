#!/usr/bin/env bash
# Author: Chmouel Boudjnah <chmouel@chmouel.com>
set -eufo pipefail
DAYS_TO_RENEW=75
EMAIL=chmouel@chmouel.com

force=""
genDomain() {
	domain=$1
	certificate=.lego/certificates/$domain.json
	if [[ -n $force ]] || find $(dirname "$certificate") -name $(basename "$certificate") -mtime +${DAYS_TO_RENEW} -print | grep -q .; then
		lego --domains "*.apps.$domain" --email ${EMAIL} --dns route53 --accept-tos=true run
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
