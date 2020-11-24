#!/usr/local/env bash

export HCP_PLAN=hcs-integration-preview
export RG=hcs-definition-hans
export RG=federation-test-hans

# default vnet-cidr is 172.25.17.0/24
az hcs create --name dc1 --datacenter-name dc1 --resource-group $RG --email hans@hashicorp.com --plan-name on-demand --external-endpoint enabled > $RG-dc1.json
token=$(az hcs create-federation-token -g $RG --name dc1 | jq -r '.federationToken')
az hcs create --name dc2 --datacenter-name dc2 --resource-group $RG --email hans@hashicorp.com --plan-name on-demand --vnet-cidr 172.25.17.0/24 --federation-token "$token" --external-endpoint enabled > $RG-dc2.json

echo "az hcs show-federation -g $RG --name dc1"
