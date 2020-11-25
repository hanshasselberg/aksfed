#!/usr/bin/env bash

for port in $(seq 19000 19008); do
	echo http://localhost:$port
	curl -s http://localhost:$port/clusters | grep health_flag
done
