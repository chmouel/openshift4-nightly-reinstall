#!/usr/bin/env bash
# set -x
set -e
cd $(readlink -f $(dirname $(readlink -f $0)))
OS4_BINARY=${OS4_BINARY:-"./binaries/openshift-install"}

PROFILE=${1}
S3_UPLOAD_BUCKET=

declare -A PROFILE_TO_GPG
WEB=""

[[ -e local.sh ]]  || { echo "Could not find your local.sh which you need to setup"; exit 1 ;}

source local.sh

[[ -z ${!PROFILE_TO_GPG[@]} ]] && { echo "You need the PROFILE_TO_GPG variable setup in your local.sh"; exit 1 ;}
[[ -z ${PROFILE} ]] && {
    echo "I need a profile as argument or -a for everything";
    echo "Profiles available are: ${!PROFILE_TO_GPG[@]}"
    exit 1
}
[[ -n ${WEB} ]] && [[ ! -d ${WEB} ]] && mkdir -p ${WEB}

SD=$(readlink -f $(dirname $0))

function recreate() {
    local profile=$1
    local profile_dir=${SD}/profiles/${profile}

	IC=$(readlink -f $(dirname $0)/configs/${profile}.yaml )
	[[ -e ${IC} ]] || {
		echo "${IC} don't exist"
		exit
	}

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

	if [[ -z ${gpgemail} ]];then
        echo "${user}:: Could not find a GPG key to encrypt: ${profile_dir}/auth/kubeconfig"
        return
    fi

	tail -2 ${profile_dir}/.openshift_install.log > ${profile_dir}/auth/webaccess

	mkdir -p ${profile_dir}/auth/gpg/
	gpg --yes --output ${profile_dir}/auth/gpg/kubeconfig.gpg -r ${gpgemail} --encrypt ${profile_dir}/auth/kubeconfig
	gpg --yes --output ${profile_dir}/auth/gpg/webaccess.gpg -r ${gpgemail} --encrypt ${profile_dir}/auth/webaccess
	gpg --yes --output ${profile_dir}/auth/gpg/kubeadmin.password.gpg -r ${gpgemail} --encrypt ${profile_dir}/auth/kubeadmin-password

	if [[ -n ${WEB} ]];then
		rm -rf ${WEB}/osinstall/${user}
		mkdir -p ${WEB}/osinstall/${user}
		cp -a ${profile_dir}/auth/gpg ${WEB}/osinstall/${user}
	fi

	if [[ -n ${WEB_PROTECTED_URL} && -n ${WEB_PROTECTED} ]];then
		for path in ${profile_dir}/auth/gpg/*;do
			fname=$(basename $path)
			curl -o/dev/null -s -f -u "${WEB_PROTECTED}" -F path=${user}/${fname} -X POST \
				 -F file=@${path} ${WEB_PROTECTED_URL} || { echo "Error uploading to ${WEB_PROTECTED_URL}"; exit 1 ;}
		done
	fi

	if [[ -n ${S3_UPLOAD_BUCKET} ]];then
		aws s3 cp --quiet --recursive ${profile_dir}/auth/gpg s3://${S3_UPLOAD_BUCKET}/${user} --acl public-read-write
	fi
}

if [[ ${PROFILE} == "-a" ]];then
    for profile in ${!PROFILE_TO_GPG[@]};do
        recreate ${profile}
        encrypt ${profile}
    done
	exit
fi

[[ -z ${PROFILE_TO_GPG[$PROFILE]} ]] && {
    echo "WARNING: No GPG key association has been setup for ${PROFILE}"
}

recreate ${PROFILE}
encrypt ${PROFILE}
