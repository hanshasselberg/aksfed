#!/usr/local/env bash

set -e
set -x

export HCP_PLAN=hcs-integration-preview
export RG=federation-test-hans-3
export TF_VAR_rg=$RG
