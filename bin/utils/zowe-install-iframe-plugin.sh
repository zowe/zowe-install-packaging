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

# SJH: Note this script prefers using getopts arguments for more flexibility, but tolerates some parameters being passed directly for backwards compatibility.

#default version to 1.0.0 if not supplied
version="1.0.0"

while getopts "d:i:s:t:u:v:" opt; do
  case $opt in
    d) plugin_dir=$OPTARG;;
    i) id=$OPTARG;;
    s) shortname=$OPTARG;;
    t) tile_image_path=$OPTARG;;
    u) url=$OPTARG;;
    v) version=$OPTARG;;
    \?)
      echo "Invalid option: -$opt" >&2
      exit 1
      ;;
  esac
done
shift $(($OPTIND-1))

if [ "$#" -eq 5 ]
then
  id=$1
  shortname=$2
  url=$3
  plugin_dir=$4
  tile_image_path=$5
fi

# Do parameter validation and print usage
# check parms
# TODO - create a function for these?
missing_parms=
if [[ -z ${id} ]]
then
  missing_parms=${missing_parms}" -i"
fi
if [[ -z ${shortname} ]]
then
  missing_parms=${missing_parms}" -s"
fi
if [[ -z ${url} ]]
then
  missing_parms=${missing_parms}" -u"
fi
if [[ -z ${plugin_dir} ]]
then
  missing_parms=${missing_parms}" -d"
fi
if [[ -z ${tile_image_path} ]]
then
  missing_parms=${missing_parms}" -t"
fi

if [[ -n ${missing_parms} ]]
then
echo "Some required parameters were not supplied:${missing_parms}"
cat <<EndOfUsage
Usage: $0 -i <plugin_id> -s <plugin_short_name> -u <url> -d <plugin_directory> -t <tile_image_path> [-v <plugin_version>]
  eg. $0 -i "org.zowe.plugin.example" -s "Example plugin" -u "https://zowe.org:443/about-us/" -d "/zowe/component/plugin" -t "/zowe_plugin/artifacts/tile_image.png" -v "1.0.0"
EndOfUsage
exit 1
fi

# remove any previous plugin files
rm -rf ${plugin_dir}/web/assets
rm -f ${plugin_dir}/web/index.html
rm -f ${plugin_dir}/pluginDefinition.json

mkdir -p ${plugin_dir}/web/assets
cp ${tile_image_path} ${plugin_dir}/web/assets
# Tag the graphic as binary.
chtag -b ${plugin_dir}/web/assets/$(basename ${tile_image_path})

cat <<EOF >$plugin_dir/web/index.html
<!DOCTYPE html>
<html>
    <body>
        <iframe 
            id="zluxIframe"
            src="$url"; 
            style="position:fixed; top:0px; left:0px; bottom:0px; right:0px; width:100%; height:100%; border:none; margin:0; padding:0; overflow:hidden; z-index:999999;">
            Your browser doesn't support iframes
        </iframe>
    </body>
</html>
EOF
chtag -tc 1047 ${plugin_dir}/web/index.html

cat <<EOF >${plugin_dir}/pluginDefinition.json
{
  "identifier": "$id",
  "apiversion": "${version}",
  "pluginversion": "${version}",
  "pluginType": "application",
  "webContent": {
    "framework": "iframe",
    "startingPage": "index.html",
    "launchDefinition": {
      "pluginShortNameKey": "${shortname}",
      "pluginShortNameDefault": "${shortname}", 
      "imageSrc": "assets/$(basename ${tile_image_path})"
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
chtag -tc 1047 ${plugin_dir}/pluginDefinition.json

chmod -R a+rx ${plugin_dir}
${INSTANCE_DIR}/bin/install-app.sh ${plugin_dir}
