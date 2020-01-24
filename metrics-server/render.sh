#!/bin/bash
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
rm -rf $SCRIPTPATH/manifests 
mkdir -p $SCRIPTPATH/manifests

# RENDER
echo 'RENDER MANIFESTS'

## METRICS-SERVER
helm template \
  --name metrics-server \
  --values $SCRIPTPATH/values/metrics-server.yaml \
  --output-dir $SCRIPTPATH/manifests \
    $SCRIPTPATH/charts/metrics-server
