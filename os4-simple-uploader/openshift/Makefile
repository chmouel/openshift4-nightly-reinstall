SECRET_KEY := $(shell openssl rand -base64 20)

config:
	test -f osinstall.htpasswd || { echo "You need to create osinstall.htpasswd file"; exit 1 ;}
	oc delete configmap my-nginx-conf 2>/dev/null || true
	oc create configmap --save-config my-nginx-conf --from-file osinstall.htpasswd \
		--from-file nginx.conf

reconfig: config
	@oc delete pod `oc get pod -o name -l app=openshift4-nightly-reinstall|sed 's,pod/,,'` || true

deploy: reconfig
	oc delete -f service.yaml 2>/dev/null || true
	oc create -f service.yaml
	oc delete deployment/openshift4-nightly-reinstall 2>/dev/null || true
	@IMAGE=`oc get is openshift4-nightly-reinstall -o json | \
			python -c "import sys, json;x=json.load(sys.stdin);print(x['status']['dockerImageRepository'])"` ; \
    sed -e "s,%SECRET_KEY%,$(SECRET_KEY)," \
        -e "s,%IMAGE%,$${IMAGE}," deployment.yaml | \
	oc create -f -

build:
	@oc delete -f imagestream.yaml 2>/dev/null || true
	@oc create -f imagestream.yaml 2>/dev/null || true
	@oc delete -f buildconfig.yaml 2>/dev/null || true
	@oc create -f buildconfig.yaml 2>/dev/null || true
	oc start-build openshift4-nightly-reinstall -F
