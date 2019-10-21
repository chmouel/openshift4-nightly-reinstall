#!/usr/bin/env bash
# set -x
set -e
cd $(readlink -f $(dirname $(readlink -f $0)))
OS4_BINARY=${OS4_BINARY:-"./binaries/openshift-install"}

WEB=/home/www/chmouel.com/
PROFILE=${1:-chmouel}

declare -A PROFILE_TO_GPG=(
    ["vincent"]="vincent@demeester.fr"
    ["chmouel42"]="chmouel@chmouel.com"
    ["chmouel"]="chmouel@chmouel.com"
    ["hrishi"]="hshinde@redhat.com"
    ["nikhil"]="nikthoma@redhat.com"
)

[[ -e local.sh ]] && source local.sh

[[ -z ${PROFILE} ]] && {
    echo "I need a profile"
	exit 1
}

SD=$(readlink -f $(dirname $0))
IC=$(readlink -f $(dirname $0)/configs/${PROFILE}.yaml )
[[ -e ${IC} ]] || {
	echo "${IC} don't exist"
	exit
}
PROFILE_DIR=${SD}/profiles/${PROFILE}

function recreate() {
	echo "${PROFILE}: $(date) :: start"
	[[ -e ${PROFILE_DIR}/terraform.tfstate ]] && {
		${OS4_BINARY} destroy cluster --dir ${PROFILE_DIR} --log-level=error
		rm -rf ${PROFILE_DIR}
	}
	mkdir -p ${PROFILE_DIR}

	cp ${IC} ${PROFILE_DIR}/install-config.yaml
	${OS4_BINARY} create cluster --dir ${PROFILE_DIR} --log-level=error
	echo "${PROFILE}: $(date) :: stop"
}

function encrypt() {
	user=$1
	profile_dir=${SD}/profiles/${user}
	gpgemail=${PROFILE_TO_GPG[$user]}

	if [[ -n ${gpgemail} ]];then
		tail -2 ${profile_dir}/.openshift_install.log > ${profile_dir}/auth/webaccess
        gpg --yes --output ${WEB}/tmp/${user}.kubeconfig.gpg -r ${gpgemail} --encrypt ${profile_dir}/auth/kubeconfig
		gpg --yes --output ${WEB}/tmp/${user}.webaccess.gpg -r ${gpgemail} --encrypt ${profile_dir}/auth/webaccess
		gpg --yes --output ${WEB}/tmp/${user}.kubeadmin.password.gpg -r ${gpgemail} --encrypt ${profile_dir}/auth/kubeadmin-password
    else
        echo "${PROFILE}:: Could not find a GPG key to encrypt: ${profile_dir}/auth/kubeconfig"
	fi
}

#for x in nikhil vincent chmouel sunil hrishi;do
#	encrypt ${x}
#done

recreate
encrypt ${PROFILE}
