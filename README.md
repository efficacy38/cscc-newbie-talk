# cscc-k8s-talk

## dependency
- docker
- kind
- kubectl

## how to install this env
```
# run this script to boostrap kind cluster
./bootstrap-kind.sh

# deploy dev environment
k apply --recursive -f ./SETUP
```

