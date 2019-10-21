#!/usr/bin/env bash
# set -x
set -e
cd $(readlink -f $(dirname $(readlink -f $0)))
OS4_BINARY=${OS4_BINARY:-"./binaries/openshift-install"}

PROFILE=${1}

declare -A PROFILE_TO_GPG
WEB=""

[[ -e local.sh ]] && source local.sh

[[ -z ${!PROFILE_TO_GPG[@]} ]] && { echo "You need the PROFILE_TO_GPG variable setup in your local.sh"; exit 1 ;}
[[ -z ${PROFILE} ]] && {
    echo "I need a profile as argument or -a for everything";
    echo "Profiles available are: ${!PROFILE_TO_GPG[@]}"
    exit 1
}
[[ -z ${WEB} ]] && { echo "You need the WEB variable setup in your local.sh"; exit 1 ;}

[[ -d ${WEB} ]] || mkdir -p ${WEB}

SD=$(readlink -f $(dirname $0))
IC=$(readlink -f $(dirname $0)/configs/${PROFILE}.yaml )
[[ -e ${IC} ]] || {
	echo "${IC} don't exist"
	exit
}

function recreate() {
    local profile=$1
    local profile_dir=${SD}/profiles/${profile}

	echo "${profile}: $(date) :: start"
	[[ -e ${profile_dir}/terraform.tfstate ]] && {
		${OS4_BINARY} destroy cluster --dir ${profile_dir} --log-level=error
		rm -rf ${profile_dir}
	}
	mkdir -p ${profile_dir}

	cp ${IC} ${profile_dir}/install-config.yaml
	${OS4_BINARY} create cluster --dir ${profile_dir} --log-level=error
	echo "${profile}: $(date) :: stop"
}

function encrypt() {
	local user=$1
	local profile_dir=${SD}/profiles/${user}
	local gpgemail=${PROFILE_TO_GPG[$user]}

	if [[ -n ${gpgemail} ]];then
		tail -2 ${profile_dir}/.openshift_install.log > ${profile_dir}/auth/webaccess
        gpg --yes --output ${WEB}/tmp/${user}.kubeconfig.gpg -r ${gpgemail} --encrypt ${profile_dir}/auth/kubeconfig
		gpg --yes --output ${WEB}/tmp/${user}.webaccess.gpg -r ${gpgemail} --encrypt ${profile_dir}/auth/webaccess
		gpg --yes --output ${WEB}/tmp/${user}.kubeadmin.password.gpg -r ${gpgemail} --encrypt ${profile_dir}/auth/kubeadmin-password
    else
        echo "${user}:: Could not find a GPG key to encrypt: ${profile_dir}/auth/kubeconfig"
	fi
}

if [[ ${PROFILE} == "-a" ]];then
    for profile in ${!PROFILE_TO_GPG[@]};do
        recreate ${profile}
        encrypt ${profile}
    done
fi

[[ -z ${PROFILE_TO_GPG[$PROFILE]} ]] && {
    echo "WARNING: No GPG key association has been setup for ${PROFILE}"
}

recreate ${PROFILE}
encrypt ${PROFILE}
