#!/usr/local/env bash

source env.sh
set +x

kubectl config use-context $RG-dc1
kubectl exec static-client -c static-client -- curl -sS http://localhost:1234

kubectl config use-context $RG-dc3
kubectl exec static-client -c static-client -- curl -sS http://localhost:1234
