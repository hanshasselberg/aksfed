#!/usr/local/env bash

export HCSRG=federation-test-hans
export AKSRG=aks-test-hans-2
set -e
set -x

az aks get-credentials -g $AKSRG --name dc1 --overwrite-existing --context $AKSRG-dc1
kubectl config use-context $AKSRG-dc1

az hcs create-token --name dc1 -g $HCSRG --output-kubernetes-secret | kubectl apply -f -
az hcs generate-kubernetes-secret --name dc1 -g $HCSRG | kubectl apply -f -
az hcs generate-helm-values --name dc1 -g $HCSRG --aks-resource-group $AKSRG --aks-cluster-name dc1 | sed "s/# exposeGossip/exposeGossip/" > $HCSRG-dc1.yaml

echo "meshGateway:
  enabled: true" >> $HCSRG-dc1.yaml

helm install consul hashicorp/consul -f $HCSRG-dc1.yaml
kubectl apply -f client.yaml

echo "change client-token to all dcs"

az aks get-credentials -g $AKSRG --name dc2 --overwrite-existing --context $AKSRG-dc2
kubectl config use-context $AKSRG-dc2
az hcs create-token --name dc2 -g $HCSRG --output-kubernetes-secret | kubectl apply -f -
az hcs generate-kubernetes-secret --name dc2 -g $HCSRG | kubectl apply -f -
az hcs generate-helm-values --name dc2 -g $HCSRG --aks-resource-group $AKSRG --aks-cluster-name dc2 | sed "s/# exposeGossip/exposeGossip/" > $HCSRG-dc2.yaml
echo "meshGateway:
  enabled: true" >> $HCSRG-dc2.yaml

helm install consulsec hashicorp/consul -f $HCSRG-dc2.yaml

token=$(kubectl get secret dc2-bootstrap-token -o jsonpath={.data.token} | base64 -d)
url=$(jq -r '.outputs.consul_url.value' federation-test-hans-dc1.json)
curl -H "X-CONSUL-TOKEN: $token" --upload-file mesh.json $url/v1/config
curl -H "X-CONSUL-TOKEN: $token" -d @allow.json $url/v1/connect/intentions

kubectl apply -f server.yaml
kubectl apply -f client.yaml

############### APPENDIX ###################

# kubectl exec statefulset/consul-server -- consul members -wan
# kubectl exec statefulset/consul-server -- consul catalog services -datacenter dc1
# kubectl exec statefulset/consul-server -- consul catalog services -datacenter dc2

# kubectl config use-context dc2
# kubectl exec statefulset/consul-server -- consul members -wan
# kubectl exec statefulset/consul-server -- consul catalog services -datacenter dc1
# kubectl exec statefulset/consul-server -- consul catalog services -datacenter dc2

# consul config read -name global -http-addr (jq -r '.outputs.consul_url.value' federation-test-hans-dc1.json) -token (kubectl get secret dc1-bootstrap-token -o jsonpath={.data.token} | base64 -d) -kind proxy-defaults
