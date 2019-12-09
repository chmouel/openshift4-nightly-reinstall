Simple file uploader and getting in Django

You probably want to htpassword protect it

See in [examples](examples/) for a configuration over uwsgi/nginx/systemd/htpasswd

You can launch this on openshift like this but you really need to setup the env
variable RESTRICT_IP to restrict upload from there.

```
oc new-app python:3.6~https://github.com/chmouel/openshift4-nightly-reinstall --context-dir=os4-simple-uploader --env SECRET_KEY='SETSECRET' --env ALLOWED_HOSTS="localhost" --env APP_MODULE=osinstall.wsgi --env DISABLE_MIGRATE=true --env RESTRICT_IP=1.2.3.4
```

This was made under django3, perhaps works with other versions as it simple enough but who knows.
