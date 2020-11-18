az aks get-credentials --resource-group aks-test-hans --name dc1 --overwrite-existing
helm install consul hashicorp/consul -f dc1.yaml
kubectl get secret consul-federation -o yaml > consul-federation-secret.yaml

az aks get-credentials --resource-group aks-test-hans --name dc2 --overwrite-existing
kubectl config use-context dc2
kubectl apply -f consul-federation-secret.yaml
helm install consulsec hashicorp/consul -f dc2.yaml

kubectl exec statefulset/consul-server -- consul members -wan
kubectl exec statefulset/consul-server -- consul catalog services -datacenter dc1
kubectl exec statefulset/consul-server -- consul catalog services -datacenter dc2

kubectl config use-context dc2
kubectl exec statefulset/consul-server -- consul members -wan
kubectl exec statefulset/consul-server -- consul catalog services -datacenter dc1
kubectl exec statefulset/consul-server -- consul catalog services -datacenter dc2
