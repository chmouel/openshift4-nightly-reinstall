SECRET_KEY := $(shell openssl rand -base64 20)
HTPASSWD_FILE := configs/osinstall.htpasswd
APP_NAME := openshift4-nightly-reinstall

ifeq ("$(wildcard $(HTPASSWD_FILE))","")
    $(error $(HTPASSWD_FILE) does not exist, create one with `htpasswd`)
endif

config:
	oc delete configmap my-nginx-conf 2>/dev/null || true
	oc create configmap --save-config my-nginx-conf --from-file $(HTPASSWD_FILE) \
		--from-file configs/nginx.conf

reconfig: config
	@oc delete pod `oc get pod -o name -l app=$(APP_NAME)|sed 's,pod/,,'` || true

deploy: reconfig
	oc delete -f yamls/service.yaml 2>/dev/null || true
	oc create -f yamls/service.yaml
	oc delete deployment/$(APP_NAME) 2>/dev/null || true
	@IMAGE=`oc get is $(APP_NAME) -o json | \
			python -c "import sys, json;x=json.load(sys.stdin);print(x['status']['dockerImageRepository'])"` ; \
    sed -e "s,%SECRET_KEY%,$(SECRET_KEY)," \
        -e "s,%IMAGE%,$${IMAGE}," yamls/deployment.yaml | \
	oc create -f -
	oc expose service/$(APP_NAME) 2>/dev/null || true

build:
	@oc delete -f yamls/imagestream.yaml 2>/dev/null || true
	@oc create -f yamls/imagestream.yaml 2>/dev/null || true
	@oc delete -f yamls/buildconfig.yaml 2>/dev/null || true
	@oc create -f yamls/buildconfig.yaml 2>/dev/null || true
	oc start-build $(APP_NAME) -F -w

.PHONY: build deploy reconfig config
