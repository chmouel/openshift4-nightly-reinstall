#!/usr/bin/env bash
# set -x
set -e
cd $(readlink -f $(dirname $(readlink -f $0)))
OS4_BINARY=${OS4_BINARY:-"./binaries/openshift-install"}
SYNCONLY=
EVERYONE=

while getopts "sa" o; do
    case "${o}" in
        a)
            EVERYONE=yes;;
        s)
            SYNCONLY=yes;;
        *)
            echo "Invalid option";
            exit 1;
            ;;
    esac
done
shift $((OPTIND-1))

PROFILE=${1}
S3_UPLOAD_BUCKET=

declare -A PROFILE_TO_GPG
WEB=""

function_exists() {
    declare -f -F $1 > /dev/null
    return $?
}

[[ -e local.sh ]]  || { echo "Could not find your local.sh which you need to setup"; exit 1 ;}

source local.sh

[[ -z ${!PROFILE_TO_GPG[@]} ]] && { echo "You need the PROFILE_TO_GPG variable setup in your local.sh"; exit 1 ;}
[[ -n ${WEB} ]] && [[ ! -d ${WEB} ]] && mkdir -p ${WEB}

SD=$(readlink -f $(dirname $0))

function setcreds() {
    local profile=$1
    [[ -n ${AWS_SHARED_CREDENTIALS_FILE} ]] && return
    if [[ -e $(dirname $0)/configs/${profile}.credentials ]];then
        export AWS_SHARED_CREDENTIALS_FILE=$(dirname $0)/configs/${profile}.credentials
    else
        export AWS_SHARED_CREDENTIALS_FILE=
    fi
}

function delete() {
    local profile=$1
    local profile_dir=${SD}/profiles/${profile}
	[[ -e ${profile_dir}/terraform.tfstate ]] && {
        function_exists pre_delete_${profile} && pre_delete_${profile} || true
#		timeout 30m ${OS4_BINARY} destroy cluster --dir ${profile_dir} --log-level=error || true
        function_exists post_delete_${profile} && post_delete_${profile}  || true
		rm -rf ${profile_dir}
	} || true
}

function recreate() {
    local profile=$1
    local profile_dir=${SD}/profiles/${profile}

	IC=$(readlink -f $(dirname $0)/configs/${profile}.yaml )
	[[ -e ${IC} ]] || {
		echo "${IC} don't exist"
		exit
	}
	echo "${profile}: $(date) :: start"

	delete ${profile}

	mkdir -p ${profile_dir}

	cp ${IC} ${profile_dir}/install-config.yaml
    function_exists pre_create_${profile} && pre_create_${profile}  || true

	${OS4_BINARY} create cluster --dir ${profile_dir} --log-level=error

    function_exists post_create_${profile} && post_create_${profile}  || true
	echo "${profile}: $(date) :: stop"
}

function encrypt() {
	local user=$1
	local profile_dir=${SD}/profiles/${user}
	local gpgemail=${PROFILE_TO_GPG[$user]}

    function_exists pre_encrypt_${profile} && pre_encrypt_${profile}  || true

	if [[ -z ${gpgemail} ]];then
        echo "${user}:: Could not find a GPG key to encrypt: ${profile_dir}/auth/kubeconfig"
        return
    fi

	[[ -e ${profile_dir}/.openshift_install.log ]] || return
	tail -10 ${profile_dir}/.openshift_install.log|grep "Access the OpenShift" > ${profile_dir}/auth/webaccess

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
			curl -o/dev/null -s -f -u "${WEB_PROTECTED}" -F path=${WEB_PROTECTED_PREFIX}${user}/${fname} -X POST \
				 -F file="@${path}" ${WEB_PROTECTED_URL} || { echo "Error uploading to ${WEB_PROTECTED_URL}"; exit 1 ;}
		done
	fi

	if [[ -n ${S3_UPLOAD_BUCKET} ]];then
		aws s3 cp --quiet --recursive ${profile_dir}/auth/gpg s3://${S3_UPLOAD_BUCKET}/${user} --acl public-read-write
	fi

    function_exists post_encrypt_${profile} && post_encrypt_${profile} || true
}

function cleandns() {
	local domain
	domain=$(python3 -c 'import sys,yaml;sys;x = yaml.load(sys.stdin.read(), Loader=yaml.SafeLoader);print(x["metadata"]["name"])' < configs/${1}.yaml)
	python3 scripts/openshift-install-cleanup-route53.records.py -s -f ${domain}
}

function main() {
    local profile=$1
    if [[ -z ${SYNCONLY} ]];then
        setcreds ${profile}
        cleandns ${profile}
        recreate ${profile}
    fi
    encrypt ${profile}
}

if [[ -n ${EVERYONE} ]];then
    for profile in ${!PROFILE_TO_GPG[@]};do
		main ${profile}
    done
	exit 0
fi

[[ -z ${PROFILE} ]] && {
    echo "I need a profile as argument or -a for everything";
    echo "Profiles available are: ${!PROFILE_TO_GPG[@]}"
    exit 1
}

[[ -z ${PROFILE_TO_GPG[$PROFILE]} ]] && {
    echo "WARNING: No GPG key association has been setup for ${PROFILE}"
}

main ${PROFILE}
