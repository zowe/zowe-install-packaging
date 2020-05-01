#!/bin/sh

#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project. 2020
#######################################################################

#######################################################################
# Generate Zowe source zip file
#######################################################################

################################################################################
# contants
SCRIPT_NAME=$(basename "$0")
SCRIPT_PWD=$(cd "$(dirname "$0")" && pwd)
ROOT_PWD=$(cd "$SCRIPT_PWD" && cd .. && pwd)
cd "$ROOT_PWD"
WORK_DIR=tmp/source_zip

################################################################################
echo "[${SCRIPT_NAME}] prepare working directory"
cd "$ROOT_PWD"
rm -fr "$WORK_DIR"
mkdir -p "$WORK_DIR"
echo

################################################################################
ZOWE_VERSION=$(jq -r '.version' manifest.json.template)
echo "[${SCRIPT_NAME}] Zowe version is ${ZOWE_VERSION}"
rm -f "zowe_sources-${ZOWE_VERSION}.zip"
echo

################################################################################
echo "[${SCRIPT_NAME}] write README.md"
cat > "${WORK_DIR}/README.md" << EOF
# Source files for the Zowe project - version ${ZOWE_VERSION}

Included in this zip file are the source files used to build the Zowe ${ZOWE_VERSION} Release.
Each of the zip files are named with the commit number that is consistent with the ${ZOWE_VERSION}
release of the Zowe ${ZOWE_VERSION} build.

Included in the zip is the source from the repositories hosted at https://github.com/zowe.

Information about the project can be found at https://zowe.org.

The community mailing lists and engagement information can be found at https://zowe.org/contribute/

Enjoy and happy hacking.
EOF
echo

################################################################################
echo "[${SCRIPT_NAME}] download source code"
ZOWE_SOURCE_DEPENDENCIES=$(jq -r '.sourceDependencies[] | .entries[] | .repository + "," + .tag' manifest.json.template)
for repo in $ZOWE_SOURCE_DEPENDENCIES; do
  REPO_NAME=$(echo $repo | awk -F, '{print $1}')
  REPO_TAG=$(echo $repo | awk -F, '{print $2}')
  echo "[${SCRIPT_NAME}] - $REPO_NAME $REPO_TAG"
  echo "[${SCRIPT_NAME}]   - checking https://api.github.com/repos/zowe/${REPO_NAME}/git/refs/tags/${REPO_TAG}"
  REPO_HASH=$(curl -s "https://api.github.com/repos/zowe/${REPO_NAME}/git/refs/tags/${REPO_TAG}" | jq -r '.object.sha')
  if [ "$?" != "0" ]; then
    echo "[${SCRIPT_NAME}]   - [ERROR] failed to find tag hash"
    exit 1
  fi
  if [ "$REPO_HASH" == "null" ]; then
    echo "[${SCRIPT_NAME}]   - [ERROR] failed to find tag hash"
    exit 1
  fi
  echo "[${SCRIPT_NAME}]   - found $REPO_HASH"
  REPO_HASH_SHORT=$(echo $REPO_HASH | cut -c 1-8)
  curl -s "https://codeload.github.com/zowe/${REPO_NAME}/zip/${REPO_TAG}" --output "${WORK_DIR}/${REPO_NAME}-${REPO_TAG}-${REPO_HASH_SHORT}.zip"
  if [ "$?" != "0" ]; then
    echo "[${SCRIPT_NAME}]   - [ERROR] failed to download source."
    exit 1
  else
    echo "[${SCRIPT_NAME}]   - ${REPO_NAME}-${REPO_TAG}-${REPO_HASH_SHORT}.zip downloaded"
  fi
  sleep 2
done
echo

################################################################################
echo "[${SCRIPT_NAME}] source folder prepared:"
find "${WORK_DIR}" -print
echo

################################################################################
echo "[${SCRIPT_NAME}] zip source"
zip -9 -v -D -j "zowe_sources-${ZOWE_VERSION}.zip" $WORK_DIR/*
if [ -f "zowe_sources-${ZOWE_VERSION}.zip" ]; then
  echo "[${SCRIPT_NAME}] - zowe_sources-${ZOWE_VERSION}.zip created"
else
  echo "[${SCRIPT_NAME}][ERROR] - failed to create zowe_sources-${ZOWE_VERSION}.zip"
  exit 2
fi
echo

################################################################################
echo "[${SCRIPT_NAME}] done."
exit 0
