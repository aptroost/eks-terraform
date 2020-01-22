#!/bin/bash
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

# DEPLOY
echo 'DEPLOY MANIFESTS'

## CLUSTER-AUTOSCALER
kubectl apply -R -f $SCRIPTPATH/manifests/cluster-autoscaler
