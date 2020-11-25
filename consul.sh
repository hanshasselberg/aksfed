#!/usr/local/env bash

source env.sh

az aks get-credentials -g $RG --name dc1 --overwrite-existing --context $RG-dc1
kubectl config use-context $RG-dc1

az hcs create-token --name dc1 -g $RG --output-kubernetes-secret | kubectl apply -f -
az hcs generate-kubernetes-secret --name dc1 -g $RG | kubectl apply -f -
az hcs generate-helm-values --name dc1 -g $RG --aks-resource-group $RG --aks-cluster-name dc1 | sed "s/# exposeGossip/exposeGossip/" > $RG-helm-dc1.yaml

echo "meshGateway:
  enabled: true" >> $RG-helm-dc1.yaml

helm install consul hashicorp/consul -f $RG-helm-dc1.yaml

token=$(kubectl get secret dc1-bootstrap-token -o jsonpath={.data.token} | base64 -d)
url=$(jq -r '.outputs.consul_url.value' $RG-hcs-dc1.json)
curl -s -H "X-CONSUL-TOKEN: $token" --upload-file mesh_config.json $url/v1/config
curl -s -H "X-CONSUL-TOKEN: $token" -d @allow_intention.json $url/v1/connect/intentions
curl -s -H "X-CONSUL-TOKEN: $token" --upload-file update_anon.json $url/v1/acl/token/00000000-0000-0000-0000-000000000002
# policy_id=$(curl -s -H "X-CONSUL-TOKEN: $token" $url/v1/acl/policy/name/client-token | jq -r '.ID')
# curl -s -H "X-CONSUL-TOKEN: $token" --upload-file update_client_token.json $url/v1/acl/policy/$policy_id

az aks get-credentials -g $RG --name dc2 --overwrite-existing --context $RG-dc2
kubectl config use-context $RG-dc2
az hcs create-token --name dc2 -g $RG --output-kubernetes-secret | kubectl apply -f -
az hcs generate-kubernetes-secret --name dc2 -g $RG | kubectl apply -f -
az hcs generate-helm-values --name dc2 -g $RG --aks-resource-group $RG --aks-cluster-name dc2 | sed "s/# exposeGossip/exposeGossip/" > $RG-helm-dc2.yaml
echo "meshGateway:
  enabled: true" >> $RG-helm-dc2.yaml

helm install consul hashicorp/consul -f $RG-helm-dc2.yaml

az aks get-credentials -g $RG --name dc3 --overwrite-existing --context $RG-dc3
kubectl config use-context $RG-dc3
az hcs create-token --name dc3 -g $RG --output-kubernetes-secret | kubectl apply -f -
az hcs generate-kubernetes-secret --name dc3 -g $RG | kubectl apply -f -
az hcs generate-helm-values --name dc3 -g $RG --aks-resource-group $RG --aks-cluster-name dc3 | sed "s/# exposeGossip/exposeGossip/" > $RG-helm-dc3.yaml
echo "meshGateway:
  enabled: true" >> $RG-helm-dc3.yaml

helm install consul hashicorp/consul -f $RG-helm-dc3.yaml

############### APPENDIX ###################

# kubectl exec statefulset/consul-server -- consul members -wan
# kubectl exec statefulset/consul-server -- consul catalog services -datacenter dc1
# kubectl exec statefulset/consul-server -- consul catalog services -datacenter dc2

# kubectl config use-context dc2
# kubectl exec statefulset/consul-server -- consul members -wan
# kubectl exec statefulset/consul-server -- consul catalog services -datacenter dc1
# kubectl exec statefulset/consul-server -- consul catalog services -datacenter dc2

# consul config read -name global -http-addr (jq -r '.outputs.consul_url.value' federation-test-hans-dc1.json) -token (kubectl get secret dc1-bootstrap-token -o jsonpath={.data.token} | base64 -d) -kind proxy-defaults
