This would generate an image for this repo with S2I to output to an OpenShift
ImageStream and then use a Kubernetes `Deployment` to deploy it, with a few sed
for dynamic variables.

The deployment has two containers, the main one is nginx getting all request and
passing the uploads to the uwsgi process in the other container and serves
the static file directly.

You need first to create a a username password with :

```
htpasswd -b -c osinstall.htpasswd username password
```

To build and deploy you just need :

```
make build deploy
```

django `SECRET_KEY` is automatically generated.
