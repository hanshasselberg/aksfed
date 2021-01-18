#!/usr/local/env bash

set -e
set -x

export HCP_PLAN=hcs-integration-preview
export RG=`terraform output rg`
