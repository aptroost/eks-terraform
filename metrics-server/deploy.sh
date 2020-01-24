#!/bin/bash
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

# DEPLOY
echo 'DEPLOY MANIFESTS'

## METRICS-SERVER
kubectl apply -R -f $SCRIPTPATH/manifests/metrics-server
