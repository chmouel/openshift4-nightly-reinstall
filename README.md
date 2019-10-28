# OpenShift Install

## Pre-Requirements

A public web server setup, gpg setup.

## Steps

* Download and extract the openshift installer from
https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/ to
`./binaries/openshift-install`

* Setup a **PROFILE** in `./config/` taking an example from `configs/config.example.yaml` as for eg: `configs/user.yaml`

* Replace the *%VARIABLE%* in there with the right ones.

  - `%CLUSTER_NAME%`: Whatever name you want to give to that cluster, (or `sed "${RANDOM}q;d" /usr/share/dict/words`)
  - `%REGISTRY_TOKEN%`: the registry token you get from https://try.openshift.com/
  - `%SSH_KEY%` is your public SSH key.

* Add a `local.sh` at the top dir with your profile name to gpg key in bash hashtable and the WEB variable pointing to your local apache root (or subdir), i.e:

```bash
declare -A PROFILE_TO_GPG=(
    ["user"]="gpgkey@user.com"
)

WEB=/var/www/html/
```

* Ask the user for her/his GPG key and import it: `gpg --import gpgkey@user.com.pubkey.asc` or `gpg
   --recv-keys gpgkey@user.com` if it's uploaded on the public GPG servers.

* Trust the key : https://stackoverflow.com/a/17130637/145125

* Setup a cron for that profile to run every night (ask for the most convenient user TZ when she/he is not working) :

`00 06 * * * $PATH_TO/openshift4-nightly-reinstall/install.sh user >>/tmp/install.log`

* Let the user setup a function to resync its cluster key while enjoying a tiny sip of her/his double expresso latté ☕️, i.e:

```bash
function sync-os4() {
    local profile=profilename
    curl -s yourwebserver.com/${profile}.kubeconfig.gpg | gpg --decrypt > ${HOME}/.kube/config.os4
    export KUBECONFIG=${HOME}/.kube/config.os4
    oc version
}
```

## Web Access

Web access is available with :

```shell
$ curl -s yourwebserver.com/${profile}.kubeadmin.password.gpg |gpg --decrypt
```

With the full url to access :

```shell
curl -s yourwebserver.comf/tmp/${profile}.webaccess.gpg |gpg --decrypt
```

## User creation automations

You can automatically add new users to your clusters, so you don't have to have a different webaccess every time :


1. Create first an htpasswd-file with your username/passwd using the [htpasswd](https://httpd.apache.org/docs/current/programs/htpasswd.html) utility :
   `$ htpasswd -c htpasswd-file username`

2. Add this function to your zsh function and call it from sync-os4 function
``` shell
function os4_add_htpasswd_auth() {
    oc create secret generic htpasswd-secret --from-file=htpasswd=htpasswd-file -n openshift-config
    oc patch oauth cluster -n openshift-config --type merge --patch "spec:
  identityProviders:
  - htpasswd:
      fileData:
        name: htpasswd-secret
    mappingMethod: claim
    name: htpasswd
    type: HTPasswd
"
    # oc adm policy add-cluster-role-to-user cluster-admin ${your_username_used_to_login}
}
```
