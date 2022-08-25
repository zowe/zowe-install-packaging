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
# Copyright Contributors to the Zowe Project. 2019, 2022
#######################################################################

#######################################################################
# Build script
#
# runs on Jenkins server, before sending data to z/OS
#
#######################################################################
# set -x

# expected input workspace layout (${ROOT_DIR}):
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
PAX_WORKSPACE_DIR=$(cd "$(dirname "$0")";pwd)      # <something>/.pax
PAX_BINARY_DEPENDENCIES="${PAX_WORKSPACE_DIR}/binaryDependencies"
ROOT_DIR=$(cd "${PAX_WORKSPACE_DIR}/../";pwd)

echo "[${SCRIPT_NAME}] extracting ZOWE_VERSION ..."
ZOWE_VERSION=$(cat ${ROOT_DIR}/manifest.json | grep version | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')
if [ -z "$ZOWE_VERSION" ]; then
  echo "[$SCRIPT_NAME] Error: failed to extract version from manifest.json"
  exit 1
else
  echo "[$SCRIPT_NAME] - working on Zowe v${ZOWE_VERSION} ..."
fi

cd "${ROOT_DIR}"

# workspace path abbreviations, relative to ${ROOT_DIR}
ASCII_DIR="${PAX_WORKSPACE_DIR}/ascii"
CONTENT_DIR="${PAX_WORKSPACE_DIR}/content"

# prepare pax workspace
echo "[${SCRIPT_NAME}] preparing folders ..."
rm -fr "${ASCII_DIR}" && mkdir -p "${ASCII_DIR}"
rm -fr "${CONTENT_DIR}" && mkdir -p "${CONTENT_DIR}/bin"
mkdir -p "${CONTENT_DIR}/files"
mkdir -p "${CONTENT_DIR}/schemas"

# FIXME: remove these debug code
# rm -fr "${PAX_WORKSPACE_DIR}/binaryDependencies" && mkdir -p "${PAX_WORKSPACE_DIR}/binaryDependencies"
# cp -r "${PAX_WORKSPACE_DIR}/bak/binaryDependencies/" "${PAX_WORKSPACE_DIR}/binaryDependencies"

# Building TS files
cd "${ROOT_DIR}/build/zwe"
npm ci && npm run prod
# Cleanup TS files after build
find "${ROOT_DIR}/bin" -type f -name '*.ts' -delete

# copy from current github source
echo "[${SCRIPT_NAME}] copying files ..."
cd "${ROOT_DIR}"
cp manifest.json       "${CONTENT_DIR}"
cp example-zowe.yaml   "${CONTENT_DIR}"
cp ZOWE.md             "${CONTENT_DIR}/README.md"
cp DEVELOPERS.md       "${CONTENT_DIR}/DEVELOPERS.md"
cp -R bin/*            "${CONTENT_DIR}/bin"
cp -R files/*          "${CONTENT_DIR}/files"
cp -R schemas/*        "${CONTENT_DIR}/schemas"


# build dir should not end up in release, will be removed after build in pre-packaging phase
#cp -R build            "${CONTENT_DIR}/"

# move licenses
mkdir -p "${CONTENT_DIR}/licenses"
echo "[${SCRIPT_NAME}] copy license file ..."
mv "${PAX_BINARY_DEPENDENCIES}/zowe_licenses_full.zip" "${CONTENT_DIR}/licenses"

# extract packaging utility tools to bin/utils
echo "[${SCRIPT_NAME}] prepare utility tools ..."
cd "${ROOT_DIR}" && cd "${CONTENT_DIR}/bin/utils"
echo "[${SCRIPT_NAME}] extract zowe-utility-tools.zip ..."
jar -xf "${PAX_BINARY_DEPENDENCIES}"/zowe-utility-tools*.zip
# we should get 2 tgz files as npm packages
echo "[${SCRIPT_NAME}] extract zowe-fconv ..."
tar zxf zowe-fconv-*.tgz
mv package fconv
rm zowe-fconv-*.tgz
echo "[${SCRIPT_NAME}] extract zowe-njq ..."
tar zxf zowe-njq-*.tgz
mv package njq
rm zowe-njq-*.tgz
echo "[${SCRIPT_NAME}] extract zowe-config-converter ..."
tar zxf zowe-config-converter-*.tgz
mv package config-converter
rm zowe-config-converter-*.tgz
# zowe-ncert.pax will be extracted on z/OS side
cd "${ROOT_DIR}"
rm -f "${PAX_BINARY_DEPENDENCIES}"/zowe-utility-tools*.zip

# put text files into ascii folder (recursive & verbose)
echo "[${SCRIPT_NAME}] move ASCII files out of CONTENT directory for encoding conversion ..."
rsync -rv \
  --exclude '*.zip' \
  --exclude '*.png' \
  --exclude '*.tgz' \
  --exclude '*.tar.gz' \
  --exclude '*.pax' \
  --exclude '*.jar' \
  --exclude '*.class' \
  --prune-empty-dirs --remove-source-files \
  "${CONTENT_DIR}/" \
  "${ASCII_DIR}"

echo "[${SCRIPT_NAME}] copy keyring_utils"
cd "${ROOT_DIR}" && cd "${CONTENT_DIR}/bin/utils"
mkdir -p keyring-util
mv "${PAX_BINARY_DEPENDENCIES}"/keyring-util-* keyring-util/keyring-util

# move binary dependencies and prepare to extract on z/OS
echo "[${SCRIPT_NAME}] move binary dependencies ..."
mkdir -p "${CONTENT_DIR}/files/zlux"
cd "${PAX_BINARY_DEPENDENCIES}"
for zlux_dep in zlux-editor tn3270-ng2 vt-ng2 sample-react-app sample-iframe-app sample-angular-app explorer-ip ; do
  mv ${zlux_dep}-*.pax        "${CONTENT_DIR}/files/zlux/${zlux_dep}.pax"
done
mv *.pax "${CONTENT_DIR}/files/"
mv *.zip "${CONTENT_DIR}/files/"
# PAX_BINARY_DEPENDENCIES should be empty now
if [ -n "$(ls -1)" ]; then
  echo "[$SCRIPT_NAME] Error: binaryDependencies directory is not clean"
  exit 1
fi
cd "${ROOT_DIR}"
rm -r "${PAX_BINARY_DEPENDENCIES}"

echo "[${SCRIPT_NAME}] create customized workflows ..."
# create customized workflows
wf_from="workflows/files"
wf_to="${ASCII_DIR}/files/workflows"
_customizeWorkflow

# copy source for workflows with matching JCL -- build usage only
wf_from="workflows/templates"
wf_to="${PAX_WORKSPACE_DIR}/ascii/templates"
_templateWorkflow
cp workflows/*.rex "$wf_to"                               # add tooling

echo "[${SCRIPT_NAME}] copy smpe scripts ..."
# copy smpe scripts -- build usage only
mkdir -p "${PAX_WORKSPACE_DIR}/ascii/smpe"
cp -R smpe/. "${PAX_WORKSPACE_DIR}/ascii/smpe"
cp -R smpe/scripts/* "${PAX_WORKSPACE_DIR}/ascii/smpe/bld"
mkdir -p "${PAX_WORKSPACE_DIR}/ascii/smpe/pax/scripts"
cp -R smpe/scripts/* "${PAX_WORKSPACE_DIR}/ascii/smpe/pax/scripts"

echo "[$SCRIPT_NAME] done"

# result:
# ${PAX_WORKSPACE_DIR}/ascii/smpe/
# ${PAX_WORKSPACE_DIR}/ascii/templates/
# ${PAX_WORKSPACE_DIR}/ascii/
# ${PAX_WORKSPACE_DIR}/content/
# ascii/* will move into content/, translated to ebcdic
