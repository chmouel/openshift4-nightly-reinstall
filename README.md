# OpenShift Install

## Pre-Requirements

A public web server setup, gpg setup.

## Steps

1. Download and extract the openshift installer from
https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/ to
`./binaries/openshift-install`

2. Setup a **PROFILE** in `./config/` taking an example from `configs/config.example.yaml` as for eg: `configs/user.yaml`

3. Replace the *%VARIABLE%* in there with the right ones

4. Add a `local.sh` at the top dir with your profile name to gpg key in bash hashtable, i.e:

```bash
declare -A PROFILE_TO_GPG=(
    ["user"]="gpgkey@user.com"
)

WEB=/var/www/html/
```

5. Import the GPG key, `gpg --import gpgkey@user.com.pubkey.asc` or `gpg
   --recv-keys gpgkey@user.com` if it's uploaded on the public GPG servers.

6. Trust the key : https://stackoverflow.com/a/17130637/145125

7. Setup a cron for that profile to run every night (ask for the most convenient user TZ when she/he is not working) :

`00 06 * * * $PATH_TO/os4-build/install.sh user >>/tmp/install.log`

8. Let the user setup a function to resync its cluster key by while taking a tiny sip of her/his latté ☕️, i.e:

```bash
function sync-os4() {
    curl -s yourwebserver.com/${profile}.kubeconfig.gpg | gpg --decrypt > ${HOME}/.kube/config.os4
    export KUBECONFIG=${HOME}/.kube/config.os4
}
```
