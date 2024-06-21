#!/usr/bin/env bash
# shellcheck disable=SC2015
# set -x
set -e
cd $(readlink -f $(dirname $(readlink -f $0)))
OS4_BINARY=${OS4_BINARY:-"./binaries/arm64/openshift-install"}
SYNCONLY=
EVERYONE=
NODELETE=

while getopts "sKka" o; do
	case "${o}" in
	a)
		EVERYONE=yes
		;;
	k)
		DELETEONLY=yes
		;;
	K)
		NODELETE=yes
		;;
	s)
		SYNCONLY=yes
		;;
	*)
		echo "Invalid option"
		exit 1
		;;
	esac
done
shift $((OPTIND - 1))

PROFILE=${1}
S3_UPLOAD_BUCKET=
S3_UPLOAD_CONFIG_FILE=
export S3_UPLOAD_CONFIG_FILE S3_UPLOAD_BUCKET

declare -A PROFILE_TO_GPG
WEB=""

function_exists() {
	declare -f -F $1 >/dev/null
	return $?
}

[[ -e local.sh ]] || {
	echo "Could not find your local.sh which you need to setup"
	exit 1
}

# shellcheck disable=SC1091
source local.sh

#[[ -z ${!PROFILE_TO_GPG[@]} ]] && { echo "You need the PROFILE_TO_GPG variable setup in your local.sh"; exit 1 ;}
[[ -n ${WEB} ]] && [[ ! -d ${WEB} ]] && mkdir -p ${WEB}

SD=$(readlink -f $(dirname $0))

function setcreds() {
	local profile=$1
	[[ -n ${AWS_SHARED_CREDENTIALS_FILE} ]] && return
	if [[ -e $(dirname $0)/configs/${profile}.credentials ]]; then
		export AWS_SHARED_CREDENTIALS_FILE
		AWS_SHARED_CREDENTIALS_FILE=$(readlink -f $(dirname $0)/configs/${profile}.credentials)
	else
		unset AWS_SHARED_CREDENTIALS_FILE
	fi
}

#TODO: downloader
function os4_binary() {
	local profile=$1
	[[ -x ${SD}/configs/${profile}.openshift-install ]] && {
		echo ${SD}/configs/${profile}.openshift-install
		return
	}
	echo ${OS4_BINARY}
}

function delete() {
	local profile=$1
	local profile_dir=${SD}/profiles/${profile}
	[[ -e ${profile_dir}/terraform.tfstate || -e ${profile_dir}/terraform.tfvars.json ]] && {
		function_exists pre_delete_${profile} && pre_delete_${profile} || true
		timeout 30m $(os4_binary ${profile}) destroy cluster --dir ${profile_dir} --log-level=error || true
		function_exists post_delete_${profile} && post_delete_${profile} || true
	} || true
}

function recreate() {
	local profile=$1
	local profile_dir=${SD}/profiles/${profile}

	IC=$(readlink -f $(dirname $0)/configs/${profile}.yaml)
	[[ -e ${IC} ]] || {
		echo "${IC} don't exist"
		exit
	}
	echo "${profile}: $(date) :: start"

	[[ -z ${NODELETE} ]] && delete ${profile} || rm -rf ${profile_dir}

	[[ -n ${DELETEONLY} ]] && exit 0
	mkdir -p ${profile_dir}

	cp ${IC} ${profile_dir}/install-config.yaml
	function_exists pre_create_${profile} && pre_create_${profile} || true

	$(os4_binary ${profile}) create cluster --dir ${profile_dir} --log-level=error

	function_exists post_create_${profile} && post_create_${profile} || true
	echo "${profile}: $(date) :: stop"
}

function encrypt() {
	local user=$1
	local profile_dir=${SD}/profiles/${user}
	local gpgemail=${PROFILE_TO_GPG[$user]}

	function_exists pre_encrypt_${profile} && pre_encrypt_${profile} || true

	if [[ -z ${gpgemail} ]]; then
		return 0
	fi

	[[ -e ${profile_dir}/.openshift_install.log ]] || return
	tail -10 ${profile_dir}/.openshift_install.log | grep "Login to the console" >${profile_dir}/auth/webaccess

	mkdir -p ${profile_dir}/auth/gpg/
	if [[ -n ${gpgemail} ]]; then
		gpg --yes --output ${profile_dir}/auth/gpg/kubeconfig.gpg -r ${gpgemail} --encrypt ${profile_dir}/auth/kubeconfig
		gpg --yes --output ${profile_dir}/auth/gpg/webaccess.gpg -r ${gpgemail} --encrypt ${profile_dir}/auth/webaccess
		gpg --yes --output ${profile_dir}/auth/gpg/kubeadmin.password.gpg -r ${gpgemail} --encrypt ${profile_dir}/auth/kubeadmin-password
	else
		cp -v ${profile_dir}/auth/{kubeconfig,webaccess,kubeadmin-password} ${profile_dir}/auth/gpg/
	fi
	function_exists post_encrypt_${profile} && post_encrypt_${profile} || true
}

function syncit() {
	local user=$1
	local profile_dir=${SD}/profiles/${user}

	if [[ -n ${WEB:?} ]]; then
		rm -rf ${WEB:?}/${user}
		mkdir -p ${WEB:?}/${user}
		cp -a ${profile_dir}/auth/* ${WEB:?}/${user}
		rmdir ${WEB:?}/${user}/gpg
		chmod a+r ${WEB:?}/${user}/*
	fi

	if [[ -n ${WEB_PROTECTED_URL} && -n ${WEB_PROTECTED} ]]; then
		for path in "${profile_dir}"/auth/gpg/*; do
			fname=$(basename $path)
			curl -o/dev/null -s -f -u "${WEB_PROTECTED}" -F path=${WEB_PROTECTED_PREFIX}${user}/${fname} -X POST \
				-F file="@${path}" ${WEB_PROTECTED_URL} || {
				echo "Error uploading to ${WEB_PROTECTED_URL}"
				exit 1
			}
		done
	fi

	if [[ -n ${S3_UPLOAD_BUCKET} ]]; then
		# (
		#     [[ -n ${S3_UPLOAD_CONFIG_FILE} ]] && {
		#         f=$(readlink -f ${S3_UPLOAD_CONFIG_FILE})
		#         [[ -e ${f} ]] || { echo "$f cannot be found" ; exit 1;}
		#         export AWS_CONFIG_FILE=${S3_UPLOAD_CONFIG_FILE}
		#     }
		aws s3 cp --recursive ${profile_dir}/auth/gpg s3://${S3_UPLOAD_BUCKET}/${user} --acl public-read
		# )
	fi
}

function cleandns() {
	local domain name
	name=$(python3 -c 'import sys,yaml;sys;x = yaml.load(sys.stdin.read(), Loader=yaml.SafeLoader);print(x["metadata"]["name"])' <configs/${1}.yaml)
	domain=$(python3 -c 'import sys,yaml;sys;x = yaml.load(sys.stdin.read(), Loader=yaml.SafeLoader);print(x["baseDomain"])' <configs/${1}.yaml)
	scripts/openshift-install-cleanup-route53.records.py -s -f ${name} -z ${domain}
}

function main() {
	local profile=$1
	setcreds ${profile}
	if [[ -z ${SYNCONLY} ]]; then
		cleandns ${profile}
		recreate ${profile}
	else
		if function_exists post_create_${profile}; then
			post_create_${profile} || true
		fi
	fi
	encrypt ${profile}
	syncit ${profile}
}

if [[ -n ${EVERYONE} ]]; then
	for profile in "${!PROFILE_TO_GPG[@]}"; do
		main ${profile}
	done
	exit 0
fi

[[ -z ${PROFILE} ]] && {
	echo "I need a profile as argument or -a for everything"
	echo 'Profiles available are: ' "${!PROFILE_TO_GPG[@]}"
	exit 1
}

main ${PROFILE}
