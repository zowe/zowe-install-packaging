#!/bin/bash
if [ $# -lt 2 ]
    then
    echo "Usage: $0 [ContainerID] [ExternalApp]"
    exit 1
fi

EXTERNAL_APP_DIR=/root/zowe/apps
MVD_DIR=$(docker exec $1 bash -c 'echo $MVD_DESKTOP_DIR')

WEBCLIENT_DIR=$EXTERNAL_APP_DIR/$2/webClient
NODESERVER_DIR=$EXTERNAL_APP_DIR/$2/nodeServer
TSCONFIG_FILE=$WEBCLIENT_DIR/tsconfig.json

cat <<EOF | docker exec --interactive $1 sh
echo $MVD_DIR
if [ -d "$WEBCLIENT_DIR" ]; then
  cd $WEBCLIENT_DIR
  sed -i 's+../../zlux-app-manager/virtual-desktop+$MVD_DIR+g' $TSCONFIG_FILE
  npm install
  npm run-script build
  sed -i 's+$MVD_DIR+../../zlux-app-manager/virtual-desktop+g' $TSCONFIG_FILE
fi
if [ -d "$NODESERVER_DIR" ]; then
  cd $NODESERVER_DIR
  npm install
  npm run-script build
fi
if [[ -z "$MVD_DIR" ]]; then
  echo "MVD_DESKTOP_DIR is not set in the Docker image"
fi
EOF
