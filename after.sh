#!/usr/local/env bash

az aks get-credentials --resource-group aks-test-hans --name dc1 --overwrite-existing
kubectl config use-context dc1

az hcs create-token --name dc1 --resource-group hcs-definition-hans --output-kubernetes-secret | kubectl apply -f -
az hcs generate-kubernetes-secret --name dc1 --resource-group hcs-definition-hans | kubectl apply -f -
az hcs generate-helm-values --name dc1 -g hcs-definition-hans --aks-resource-group aks-test-hans --aks-cluster-name dc1 | sed "s/# exposeGossip/exposeGossip/" > dc1.yaml

echo "  meshGateway:
    enabled: true" >> dc1.yaml

helm install consul hashicorp/consul -f dc1.yaml

az aks get-credentials --resource-group aks-test-hans --name dc2 --overwrite-existing
kubectl config use-context dc2
az hcs create-token --name dc2 --resource-group hcs-definition-hans --output-kubernetes-secret | kubectl apply -f -
az hcs generate-kubernetes-secret --name dc2 --resource-group hcs-definition-hans | kubectl apply -f -
az hcs generate-helm-values --name dc2 -g hcs-definition-hans --aks-resource-group aks-test-hans --aks-cluster-name dc2 | sed "s/# exposeGossip/exposeGossip/" > dc2.yaml
helm install consulsec hashicorp/consul -f dc2.yaml
echo "  meshGateway:
    enabled: true" >> dc1.yaml

# kubectl exec statefulset/consul-server -- consul members -wan
# kubectl exec statefulset/consul-server -- consul catalog services -datacenter dc1
# kubectl exec statefulset/consul-server -- consul catalog services -datacenter dc2

# kubectl config use-context dc2
# kubectl exec statefulset/consul-server -- consul members -wan
# kubectl exec statefulset/consul-server -- consul catalog services -datacenter dc1
# kubectl exec statefulset/consul-server -- consul catalog services -datacenter dc2
