#!/usr/bin/env bash

set -e

for port in $(seq 19000 19006); do
	echo $port 
	curl -s http://localhost:$port/clusters | grep health_flag
done
