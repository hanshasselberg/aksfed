#!/usr/local/env bash

export HCP_PLAN=hcs-integration-preview
# default vnet-cidr is 172.25.17.0/24
az hcs create --name dc1 --datacenter-name dc1 --resource-group hcs-definition-hans --email hans@hashicorp.com --plan-name on-demand --external-endpoint enabled > dc1.json
token=$(az hcs create-federation-token -g hcs-definition-hans --name dc1 | jq -r '.federationToken')
az hcs create --name dc2 --datacenter-name dc2 --resource-group hcs-definition-hans --email hans@hashicorp.com --plan-name on-demand --vnet-cidr 172.25.17.0/24 --federation-token "$token" --external-endpoint enabled > dc2.json

echo "az hcs show-federation -g hcs-definition-hans --name dc1"
