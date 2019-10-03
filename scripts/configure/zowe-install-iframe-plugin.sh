#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018, 2019
################################################################################

# Requires passed in:
# ZOWE_ROOT_DIR - install root directory
# PLUGIN_ID - id of the plugin eg org.zowe.explorer-jes
# PLUGIN_SHORTNAME - short name of the plugin eg JES Explorer
# URL - the full url of the page being embedded
# TILE_IMAGE_PATH - full path link to the file location of the image to be used as the mvd tile

ZOWE_ROOT_DIR=$1
PLUGIN_ID=$2
PLUGIN_SHORTNAME=$3
URL=$4
TILE_IMAGE_PATH=$5
PLUGIN_DIR_OVERRIDE=$6

if [ "$#" -lt 5 ]; then
  echo "Usage: $0 ZOWE_INSTALL_ROOT_DIRECTORY PLUGIN_ID PLUGIN_SHORTNAME URL TILE_IMAGE_PATH PLUGIN_DIR_OVERRIDE \neg. install-iframe-plugin.sh \"~/zowe\" \"org.zowe.plugin.example\" \"Example plugin\" \"https://zowe.org:443/about-us/\" \"/zowe_plugin/artifacts/tile_image.png\" /zowe/component/plugin" >&2
  exit 1
fi
if ! [ -d "$1" ]; then
  echo "$1 not a directory, please provide the full path to the root installation directory of zowe" >&2
  exit 1
fi
if ! [ -f "$5" ]; then
  echo "$5 not a file, please provide the full path to the image file to be used for the plugin" >&2
  exit 1
fi

ZLUX_SERVER_DIRECTORY='zlux-app-server'

chmod -R u+w $ZOWE_ROOT_DIR/$ZLUX_SERVER_DIRECTORY/plugins/
# switch spaces to underscores and lower case it for use as folder name
PLUGIN_FOLDER_NAME=$(echo $PLUGIN_SHORTNAME | tr -s ' ' | tr ' ' '_' | tr '[:upper:]' '[:lower:]')
PLUGIN_FOLDER=$ZOWE_ROOT_DIR/$PLUGIN_FOLDER_NAME

if ! [ -z "$PLUGIN_DIR_OVERRIDE" ]; then
  PLUGIN_FOLDER=$PLUGIN_DIR_OVERRIDE
fi

# remove any previous plugin files
rm -rf $PLUGIN_FOLDER/web/images
rm -f $PLUGIN_FOLDER/web/index.html
rm -f $PLUGIN_FOLDER/pluginDefinition.json
rm -f $ZOWE_ROOT_DIR/$ZLUX_SERVER_DIRECTORY/plugins/$PLUGIN_ID.json

mkdir -p $PLUGIN_FOLDER/web/images
cp $TILE_IMAGE_PATH $PLUGIN_FOLDER/web/images
# Tag the graphic as binary.
chtag -b $PLUGIN_FOLDER/web/images/$(basename $TILE_IMAGE_PATH)

cat <<EOF >$PLUGIN_FOLDER/web/index.html
<!DOCTYPE html>
<html>
    <body>
        <iframe 
            id="zluxIframe"
            src="$URL"; 
            style="position:fixed; top:0px; left:0px; bottom:0px; right:0px; width:100%; height:100%; border:none; margin:0; padding:0; overflow:hidden; z-index:999999;">
            Your browser doesn't support iframes
        </iframe>
    </body>
</html>
EOF

cat <<EOF >$PLUGIN_FOLDER/pluginDefinition.json
{
  "identifier": "$PLUGIN_ID",
  "apiVersion": "1.0.0",
  "pluginVersion": "1.0.0",
  "pluginType": "application",
  "webContent": {
    "framework": "iframe",
    "startingPage": "index.html",
    "launchDefinition": {
      "pluginShortNameKey": "$PLUGIN_SHORTNAME",
      "pluginShortNameDefault": "$PLUGIN_SHORTNAME", 
      "imageSrc": "images/$(basename $TILE_IMAGE_PATH)"
    },
    "descriptionKey": "",
    "descriptionDefault": "",
    "isSingleWindowApp": true,
    "defaultWindowStyle": {
      "width": 1400,
      "height": 800
    }
  }
}
EOF

if ! [ -z "$PLUGIN_DIR_OVERRIDE" ]; then
  PLUGIN_LOCATION=$PLUGIN_DIR_OVERRIDE
else
  PLUGIN_LOCATION="../../${PLUGIN_FOLDER_NAME}"
fi

cat <<EOF >$ZOWE_ROOT_DIR/$ZLUX_SERVER_DIRECTORY/plugins/$PLUGIN_ID.json
{
    "identifier": "$PLUGIN_ID",
    "pluginLocation": "$PLUGIN_LOCATION"
}
EOF

chmod -R a+rx $PLUGIN_FOLDER