#!/usr/bin/env bash

set -exuo pipefail

WORKING_DIR=work/

mkdir -p $WORKING_DIR
cd $WORKING_DIR

# Fetch sources and compile them

if [[ ! -d ./kcp ]]
then
  git clone git@github.com:kcp-dev/kcp.git
  (cd ./kcp && git checkout 8ac8619370f61d2212d611b87df92b7b0486220b)
fi
if [[ ! -d ./eventing ]]
then
  git clone git@github.com:knative/eventing.git
fi

if [[ ! -f ./kcp/bin/kcp ]]
then
  (cd ./kcp && mkdir -p bin/ && go build -ldflags "-X k8s.io/component-base/version.gitVersion=v1.22.2 -X k8s.io/component-base/version.gitCommit=5e58841cce77d4bc13713ad2b91fa0d961e69192" -o bin/kcp ./cmd/kcp)
fi

# Start KCP
rm -rf .kcp/

./kcp/bin/kcp start \
  --push_mode=true \
  --pull_mode=false \
  --install_cluster_controller \
  --install_workspace_controller \
  --auto_publish_apis \
   --resources_to_sync="deployments.apps,pods,services" &

export KUBECONFIG=.kcp/admin.kubeconfig

# Add one kind cluster

KUBECONFIG=kind1 kind delete cluster
KUBECONFIG=kind1 kind create cluster

sed -e 's/^/    /' kind1 | cat ./kcp/contrib/examples/cluster.yaml - | kubectl apply -f -
sleep 5

# Cluster is added and deployments API is added to KCP automatically
kubectl describe cluster
kubectl api-resources

echo "KCP is ready. You can use it with :"
echo "KUBECONFIG=./work/.kcp/admin.kubeconfig kubectl api-resources"

# Test 1 - install Eventing CRDs

kubectl apply $(ls eventing/config/300-* | awk ' { print " -f " $1 } ')
kubectl apply $(ls eventing/config/config-* | awk ' { print " -f " $1 } ')
