#!/bin/bash
set -xeu

CLUSTER_NAME="cscc-newbie-talk"

# ------ setup base env ------ #
config_dir="$(pwd)/config"
cnidir="$(pwd)/cni/bin/"
mkdir -p "$config_dir"
mkdir -p "$cnidir"

# install the base CNI
wget https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1.3.0.tgz
tar -xvf cni-plugins-linux-amd64-v1.3.0.tgz -C "$cnidir"
rm cni-plugins-linux-amd64-v1.3.0.tgz

# bootstrap kind cluster
cat << EOF > "$config_dir/kind-config.yaml"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraMounts:
      - hostPath: $cnidir
        containerPath: /opt/cni/bin
  - role: worker
    extraMounts:
      - hostPath: $cnidir
        containerPath: /opt/cni/bin
  - role: worker
    extraMounts:
      - hostPath: $cnidir
        containerPath: /opt/cni/bin
networking:
  # the default CNI will not be installed
  disableDefaultCNI: true
EOF

echo -e "\ncreate kind cluster, and install metallb\n"
kind create cluster --name "$CLUSTER_NAME" --config "$config_dir/kind-config.yaml"

# ------ install CNI ------ #
# get flannel cni yaml
curl -L https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml \
  -o "$config_dir/kube-flannel.yml"

# use host-gw as backend
sed -i 's/vxlan/host-gw/g' "$config_dir/kube-flannel.yml"
# apply flannel cni
kubectl apply -f "$config_dir/kube-flannel.yml"
# wait flannel ready
kubectl wait --namespace kube-flannel \
                --for=condition=ready pod \
                --selector=app=flannel \
                --timeout=90s

# ------ install metallb ------ #
# enable metallb, with https://kind.sigs.k8s.io/docs/user/loadbalancer/
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
kubectl wait --namespace metallb-system \
                --for=condition=ready pod \
                --selector=app=metallb \
                --timeout=90s

# setup metallb LB Pool
echo "setup metallb LB Pool"
kind_ipam="$(docker network inspect kind | jq -r '.[0].IPAM.Config[0].Subnet')"
network_prefix="$(echo $kind_ipam | cut -d'.' -f1-2)"
lb_range="$network_prefix.0.155-$network_prefix.0.200" 

echo ""
echo "current kind IPv4 subnet: $kind_ipam"
echo "metallab LB Pool: $lb_range"

cat <<EOF > "$config_dir/metallb-config.yaml"
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: example
  namespace: metallb-system
spec:
  addresses:
  - $lb_range
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: empty
  namespace: metallb-system
EOF
kubectl apply -f "$config_dir/metallb-config.yaml"
