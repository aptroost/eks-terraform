#!/bin/bash
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
rm -rf $SCRIPTPATH/manifests 
mkdir -p $SCRIPTPATH/manifests

# RENDER
echo 'RENDER MANIFESTS'

## CLUSTER-AUTOSCALER
helm template \
  --name cluster-autoscaler \
  --values $SCRIPTPATH/values/cluster-autoscaler.yaml \
  --output-dir $SCRIPTPATH/manifests \
    $SCRIPTPATH/charts/cluster-autoscaler
