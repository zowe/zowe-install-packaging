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
# Deprecated usage is: $0 PLUGIN_ID PLUGIN_SHORTNAME URL PLUGIN_DIRECTORY TILE_IMAGE_PATH

#default version to 1.0.0 if not supplied
version="1.0.0"

while getopts "d:i:s:t:u:v:z" opt; do
  case $opt in
    d) plugin_dir=$OPTARG;;
    i) id=$OPTARG;;
    s) shortname=$OPTARG;;
    t) tile_image_path=$OPTARG;;
    u) url=$OPTARG;;
    v) version=$OPTARG;;
    z) unit_test_mode="true";;
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

# Used to test input processing
if [[ "${unit_test_mode}" == "true" ]]
then
  echo "i:${id} s:\"${shortname}\" u:${url} d:${plugin_dir} t:${tile_image_path} v:[${version}]"
  exit 4
fi

url_sanitized="$url"
has_multiple_domains=
if [[ $ZWE_EXTERNAL_HOSTS == *,* ]]; then
  has_multiple_domains=yes
fi
if [[ $has_multiple_domains == "yes" ]] || [[ $url == http://* ]] || [[ $url == https://* ]]; then
  # remove protocol/host/port from url
  # REASON: with multiple domains, if the user cannot resolve domain we hardcoded
  #         in the url, he will not be able to use the iframe plugin.
  # IMPORTANT: after changing this, Desktop can only be accessed with gateway port
  url_sanitized="/$(echo $url | cut -d/ -f4-)"
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
            src="${url_sanitized}"; 
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
  "apiVersion": "${version}",
  "pluginVersion": "${version}",
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
