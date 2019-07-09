#!/bin/sh -e
set -x

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2019
################################################################################

################################################################################
# Build script
# 
# - build client
# - import ui server dependency
################################################################################

# contants
SCRIPT_NAME=$(basename "$0")
BASEDIR=$(dirname "$0")
PAX_WORKSPACE_DIR=.pax
ZOWE_VERSION=$(cat manifest.json | jq -r '.version')

cd $BASEDIR
cd ..
ROOT_DIR=$(pwd)

# prepare pax workspace
echo "[${SCRIPT_NAME}] preparing folders ..."
mkdir -p "${PAX_WORKSPACE_DIR}/ascii/zowe-${ZOWE_VERSION}/scripts"
mkdir -p "${PAX_WORKSPACE_DIR}/ascii/zowe-${ZOWE_VERSION}/install"
mkdir -p "${PAX_WORKSPACE_DIR}/ascii/zowe-${ZOWE_VERSION}/files"
mkdir -p "${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files"

# copy from current github source
echo "[${SCRIPT_NAME}] copying files ..."
cp -R files/* "${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files"
# put text files into ascii folder
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
  "${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files" \
  "${PAX_WORKSPACE_DIR}/ascii/zowe-${ZOWE_VERSION}"
cp manifest.json "${PAX_WORKSPACE_DIR}/ascii/zowe-${ZOWE_VERSION}"
cp -R install/* "${PAX_WORKSPACE_DIR}/ascii/zowe-${ZOWE_VERSION}/install"
cp -R scripts/* "${PAX_WORKSPACE_DIR}/ascii/zowe-${ZOWE_VERSION}/scripts"

# write a version file, so pre-packaging.sh can pick up
echo "$ZOWE_VERSION" > "${PAX_WORKSPACE_DIR}/ascii/version"

# move licenses
mkdir -p "${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/licenses"
mv ${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files/zowe_licenses_full.zip "${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/licenses"

# move zlux files to zlux folder
mkdir -p "${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files/zlux"
mv ${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files/zlux-core-*.pax "${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files/zlux/zlux-core.pax"
mv ${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files/zss-auth-*.pax "${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files/zlux/zss-auth.pax"
mv ${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files/zosmf-auth-*.pax "${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files/zlux/zosmf-auth.pax"
mv ${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files/zlux-editor-*.pax "${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files/zlux/zlux-editor.pax"
mv ${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files/zlux-workflow-*.pax "${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files/zlux/zlux-workflow.pax"
mv ${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files/tn3270-ng2-*.pax "${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files/zlux/tn3270-ng2.pax"
mv ${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files/vt-ng2-*.pax "${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files/zlux/vt-ng2.pax"
mv ${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files/sample-react-app-*.pax "${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files/zlux/sample-react-app.pax"
mv ${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files/sample-iframe-app-*.pax "${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files/zlux/sample-iframe-app.pax"
mv ${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files/sample-angular-app-*.pax "${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files/zlux/sample-angular-app.pax"
mv ${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files/zss-*.pax "${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files/zss.pax"

# jobs-api-server-start.sh is already in IBM-1047 encoding, no need to put in ascii folder
mkdir -p "${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files/scripts"
mv "${PAX_WORKSPACE_DIR}/ascii/zowe-${ZOWE_VERSION}/files/scripts/jobs-api-server-start.sh" \
   "${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files/scripts/jobs-api-server-start.sh"
mv "${PAX_WORKSPACE_DIR}/ascii/zowe-${ZOWE_VERSION}/files/scripts/data-sets-api-server-start.sh" \
   "${PAX_WORKSPACE_DIR}/content/zowe-${ZOWE_VERSION}/files/scripts/data-sets-api-server-start.sh"
