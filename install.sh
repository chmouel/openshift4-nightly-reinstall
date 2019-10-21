#!/usr/bin/env bash
# set -x
set -e
cd $(readlink -f $(dirname $(readlink -f $0)))
OS4_BINARY=${OS4_BINARY:-"./binaries/openshift-install"}

PROFILE=${1}

declare -A PROFILE_TO_GPG
WEB=""

[[ -e local.sh ]] && source local.sh

[[ -z ${PROFILE} ]] && { echo "I need a profile as argument or -a for everything"; exit 1 ;}
[[ -z ${WEB} ]] && { echo "You need the WEB variable setup in your local.sh"; exit 1 ;}
[[ -z ${PROFILE_TO_GPG[@]} ]] && { echo "You need the PROFILE_TO_GPG variable setup in your local.sh"; exit 1 ;}

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

if [[ ${PROFILE} == "-a" ]];then
    for PROFILE in ${!PROFILE_TO_GPG[@]};do
        echo recreate # TODO(chmouel):remove global variables
        echo encrypt ${PROFILE}
    done
fi

[[ -z ${PROFILE_TO_GPG[$PROFILE]} ]] && {
    echo "WARNING: No GPG key association has been setup for ${PROFILE}"
}

recreate
encrypt ${PROFILE}
