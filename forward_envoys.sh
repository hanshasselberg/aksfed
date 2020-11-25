#!/usr/local/env bash

set -e

trap 'killall' INT

killall() {
    trap '' INT TERM     # ignore INT and TERM while shutting down
    echo "**** Shutting down... ****"     # added double quotes
    kill -TERM 0         # fixed order, send TERM not INT
    wait
    echo DONE
}

source env.sh
port=19000

function forward {
	pod=$1
	ctx=$(kubectl config current-context)
	kubectl port-forward $pod $port:19000 &
	echo "forward $ctx $pod: http://localhost:$port"
	((port=port+1))
}

function forward_mesh {
	for pod in $(kubectl get pods | grep mesh | awk '{print $1}'); do
		forward $pod
	done
}

kubectl config use-context $RG-dc1
forward_mesh
forward "static-client"

kubectl config use-context $RG-dc2
forward "static-server"
forward_mesh

kubectl config use-context $RG-dc3
forward_mesh
forward "static-client"

cat
