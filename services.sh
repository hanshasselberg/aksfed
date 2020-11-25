#!/usr/local/env bash

source env.sh

kubectl config use-context $RG-dc1
kubectl apply -f client.yaml

kubectl config use-context $RG-dc2
kubectl apply -f server.yaml

kubectl config use-context $RG-dc3
kubectl apply -f client.yaml
