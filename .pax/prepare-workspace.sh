#!/bin/sh -e
#
# SCRIPT ENDS ON FIRST NON-ZERO RC
#
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project. 2019, 2020
#######################################################################

#######################################################################
# Build script
#
# runs on Jenkins server, before sending data to z/OS
#
#######################################################################
set -x

# expected workspace layout:
# ./.pax/mediation/
# ./.pax/keyring-util/
# ./bin/
# ./files/
# ./install/
# ./manifest.json
# ./scripts/
# ./shared/scripts/
# ./workflows/files/
# ./workflows/templates/

# ---------------------------------------------------------------------
# --- do sed substitutions to workflow files
# $1: if non-null then move (input is removed)
# $wf_from: input location (raw workfiles)
# $wf_to: target location (customized workfiles)
# ---------------------------------------------------------------------
_customizeWorkflow () {
echo "[${SCRIPT_NAME}] creating workflows in $wf_to ..."
mkdir -p "$wf_to"

wf_files=$(ls "$wf_from")  # processes all files (.xml, .vtl & .properties)
for wf_file in $wf_files
do
  # skip if directory
  test -d "$wf_from/$wf_file" && continue
  # fill in Zowe version in the workflow file
  sed -e "s/###ZOWE_VERSION###/${ZOWE_VERSION}/g" \
      -e "s/encoding=\"utf-8\"/encoding=\"ibm-1047\"/g" \
      "$wf_from/$wf_file" \
      > "$wf_to/$wf_file"
  # remove raw workflow file if requested
  test -n "$1" && rm "$wf_from/$wf_file"
done

return 0
}    # _customizeWorkflow

# ---------------------------------------------------------------------
# --- do sed substitutions to template workflow files
# $wf_from: input location (raw workfiles)
# $wf_to: target location (customized workfiles)
# ---------------------------------------------------------------------
_templateWorkflow () {
wf_temp="${PAX_WORKSPACE_DIR}/ascii/wf_temp"  # temp dir for sed
mkdir -p "$wf_temp"
mkdir -p "$wf_to"

# stage input
cp -R $wf_from/. "$wf_temp"

# customize & move from temp
wf_from="$wf_temp"
_customizeWorkflow move

# move remaining sub-dirs from temp
cp -R $wf_temp/. "$wf_to"
rm -rf $wf_temp

return 0
}    # _templateWorkflow

# ---------------------------------------------------------------------
# --- main --- main --- main --- main --- main --- main --- main ---
# ---------------------------------------------------------------------
SCRIPT_NAME=$(basename "$0")  # $0=./.pax/prepare-workspace.sh
BASE_DIR=$(dirname "$0")      # <something>/.pax
PAX_WORKSPACE_DIR=.pax

if [ -z "$ZOWE_VERSION" ]; then
  echo "[$SCRIPT_NAME] ZOWE_VERSION environment variable is missing"
  exit 1
else
  echo "[$SCRIPT_NAME] working on Zowe v${ZOWE_VERSION} ..."
fi

cd $BASE_DIR
cd ..
ROOT_DIR=$(pwd)

# show what's already present
echo "[${SCRIPT_NAME}] content \$PAX_WORKSPACE_DIR: ls -A ${PAX_WORKSPACE_DIR}/"
ls -A "${PAX_WORKSPACE_DIR}/" || true

# workspace path abbreviations, relative to $ROOT_DIR
ASCII_DIR="${PAX_WORKSPACE_DIR}/ascii/zowe-${ZOWE_VERSION}"
CONTENT_DIR="${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}"

# prepare pax workspace
echo "[${SCRIPT_NAME}] preparing folders ..."
#-- ascii
mkdir -p "${ASCII_DIR}/bin"
mkdir -p "${ASCII_DIR}/files"
mkdir -p "${ASCII_DIR}/install"
mkdir -p "${ASCII_DIR}/scripts"
#-- content
mkdir -p "${CONTENT_DIR}/files"

# copy from current github source
echo "[${SCRIPT_NAME}] copying files ..."
cp -R files/* "${CONTENT_DIR}/files"

# put text files into ascii folder (recursive & verbose)
# TODO why include? everything except exclude is copied
rsync -rv \
  --include '*.json' \
  --include '*.html' \
  --include '*.jcl' \
  --include '*.template' \
  --exclude '*.zip' \
  --exclude '*.png' \
  --exclude '*.tgz' \
  --exclude '*.tar.gz' \
  --exclude '*.pax' \
  --exclude '*.jar' \
  --prune-empty-dirs --remove-source-files \
  "${CONTENT_DIR}/files" \
  "${ASCII_DIR}"
cp manifest.json       "${ASCII_DIR}"
cp -R bin/*            "${ASCII_DIR}/bin"
cp -R install/*        "${ASCII_DIR}/install"
cp -R scripts/*        "${ASCII_DIR}/scripts"
cp -R shared/scripts/* "${ASCII_DIR}/scripts"

# jobs-api-server-start.sh is already in IBM-1047 encoding, no need to put in ascii folder
mkdir -p "${CONTENT_DIR}/files/scripts"
mv ${ASCII_DIR}/files/scripts/jobs-api*.sh \
   ${CONTENT_DIR}/files/scripts/
mv ${ASCII_DIR}/files/scripts/files-api*.sh \
   ${CONTENT_DIR}/files/scripts/

# move keyring-util to bin/utils/keyring-util
KEYRING_UTIL_SRC="${PAX_WORKSPACE_DIR}/keyring-util"
KEYRING_UTIL_DEST="${CONTENT_DIR}/bin/utils/keyring-util"
mkdir -p "$KEYRING_UTIL_DEST"
cp "$KEYRING_UTIL_SRC/keyring-util" "$KEYRING_UTIL_DEST/keyring-util"

# cleanup working files
rm -rf "$KEYRING_UTIL_SRC"

# move licenses
mkdir -p "${CONTENT_DIR}/licenses"
mv "${CONTENT_DIR}/files/zowe_licenses_full.zip" \
   "${CONTENT_DIR}/licenses"

# move zlux files to zlux folder & give fixed name
mkdir -p "${CONTENT_DIR}/files/zlux"
cd "${CONTENT_DIR}/files"
mv zlux-core-*.pax          zlux/zlux-core.pax
mv zss-auth-*.pax           zlux/zss-auth.pax
mv zosmf-auth-*.pax         zlux/zosmf-auth.pax
mv zlux-editor-*.pax        zlux/zlux-editor.pax
mv zlux-workflow-*.pax      zlux/zlux-workflow.pax
mv tn3270-ng2-*.pax         zlux/tn3270-ng2.pax
mv vt-ng2-*.pax             zlux/vt-ng2.pax
mv sample-react-app-*.pax   zlux/sample-react-app.pax
mv sample-iframe-app-*.pax  zlux/sample-iframe-app.pax
mv sample-angular-app-*.pax zlux/sample-angular-app.pax
mv zss-*.pax                zss.pax
cd "$ROOT_DIR"

# create customized workflows
wf_from="workflows/files"
wf_to="${ASCII_DIR}/files/workflows"
_customizeWorkflow

# copy smpe scripts -- build usage only
mkdir -p "${PAX_WORKSPACE_DIR}/ascii/smpe"
cp -R smpe/. "${PAX_WORKSPACE_DIR}/ascii/smpe"
cp -R shared/scripts/* "${PAX_WORKSPACE_DIR}/ascii/smpe/bld"
mkdir -p "${PAX_WORKSPACE_DIR}/ascii/smpe/pax/scripts"
cp -R shared/scripts/* "${PAX_WORKSPACE_DIR}/ascii/smpe/pax/scripts"

# copy source for workflows with matching JCL -- build usage only
wf_from="workflows/templates"
wf_to="${PAX_WORKSPACE_DIR}/ascii/templates"
_templateWorkflow
cp workflows/*.rex "$wf_to"                               # add tooling

echo "[$SCRIPT_NAME] done"

# result:
# ${PAX_WORKSPACE_DIR}/ascii/smpe/
# ${PAX_WORKSPACE_DIR}/ascii/templates/
# ${PAX_WORKSPACE_DIR}/ascii/zowe-${ZOWE_VERSION}/
# ${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/
# ${PAX_WORKSPACE_DIR}/mediation/  # already present
# ${PAX_WORKSPACE_DIR}/keyring-util/  # already present
# ascii/* will move into content/, translated to ebcdic
