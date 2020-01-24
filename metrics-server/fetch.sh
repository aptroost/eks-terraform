#!/bin/bash
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
mkdir -p $SCRIPTPATH/values

# FETCH
echo 'FETCH CHARTS'

## METRICS-SERVER https://github.com/helm/charts/blob/master/stable/metrics-server/Chart.yaml
helm fetch \
  --version 2.9.0 \
  --untar \
  --untardir $SCRIPTPATH/charts \
  stable/metrics-server

FILE=$SCRIPTPATH/values/metrics-server.yaml
if ! test -f "$FILE"; then
    cp -p $SCRIPTPATH/charts/metrics-server/values.yaml $FILE
fi
