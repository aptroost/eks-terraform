#!/bin/bash
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
mkdir -p $SCRIPTPATH/values

# FETCH
echo 'FETCH CHARTS'

## CLUSTER-AUTOSCALER https://github.com/helm/charts/blob/master/stable/cluster-autoscaler/Chart.yaml
helm fetch \
  --version 6.2.0 \
  --untar \
  --untardir $SCRIPTPATH/charts \
  stable/cluster-autoscaler

FILE=$SCRIPTPATH/values/cluster-autoscaler.yaml
if ! test -f "$FILE"; then
    cp -p $SCRIPTPATH/charts/cluster-autoscaler/values.yaml $FILE
fi
