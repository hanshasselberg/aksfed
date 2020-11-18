# AKS consul cluster

This repo sets up two AKS clusters in distinct vnets, peers them and install [consul federation](https://www.consul.io/docs/k8s/installation/multi-cluster/kubernetes) via helm chart.

You want to run it like that:

```
terraform apply
```

and then follow the steps in `after.sh`.
