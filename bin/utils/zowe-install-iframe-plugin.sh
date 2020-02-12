#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018, 2020
################################################################################

# Requires passed in:
# PLUGIN_ID - id of the plugin eg org.zowe.explorer-jes
# PLUGIN_SHORTNAME - short name of the plugin eg JES Explorer
# URL - the full url of the page being embedded
# PLUGIN_DIR - the directory to create the plugin in
# TILE_IMAGE_PATH - full path link to the file location of the image to be used as the mvd tile

PLUGIN_ID=$1
PLUGIN_SHORTNAME=$2
URL=$3
PLUGIN_DIR=$4
TILE_IMAGE_PATH=$5
INSTANCE_DIR=$6

if [ "$#" -ne 6 ]; then
  echo "Usage: $0 PLUGIN_ID PLUGIN_SHORTNAME PLUGIN_DIRECTORY URL TILE_IMAGE_PATH INSTANCE_DIRECTORY \neg. install-iframe-plugin.sh \"org.zowe.plugin.example\" \"Example plugin\" \"https://zowe.org:443/about-us/\" \"/zowe/component/plugin\" \"/zowe_plugin/artifacts/tile_image.png\" \"/u/zowe_user/instance-dir\"" >&2
  exit 1
fi
if ! [ -f "$5" ]; then
  echo "$5 not a file, please provide the full path to the image file to be used for the plugin" >&2
  exit 1
fi

if ! [ -z "$PLUGIN_DIR_OVERRIDE" ]; then
  PLUGIN_FOLDER=$PLUGIN_DIR_OVERRIDE
fi

# remove any previous plugin files
rm -rf $PLUGIN_DIR/web/images
rm -f $PLUGIN_DIR/web/index.html
rm -f $PLUGIN_DIR/pluginDefinition.json

mkdir -p $PLUGIN_DIR/web/images
cp $TILE_IMAGE_PATH $PLUGIN_DIR/web/images
# Tag the graphic as binary.
chtag -b $PLUGIN_DIR/web/images/$(basename $TILE_IMAGE_PATH)

cat <<EOF >$PLUGIN_DIR/web/index.html
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

cat <<EOF >$PLUGIN_DIR/pluginDefinition.json
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

chmod -R a+rx $PLUGIN_DIR
${INSTANCE_DIR}/bin/install-app.sh $PLUGIN_DIR