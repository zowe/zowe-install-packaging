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
WORK_BRANCH=master
ZOWE_MANIFEST="https://raw.githubusercontent.com/zowe/zowe-install-packaging/${WORK_BRANCH}/manifest.json.template"
WORK_DIR=.release
ZIP_DIR="${WORK_DIR}/source_zip"

################################################################################
echo "[${SCRIPT_NAME}] check github authentication and rate limit"
GITHUB_AUTH_HEADER=
if [ -n "$GITHUB_TOKEN" ]; then
  echo "[${SCRIPT_NAME}] - found GITHUB_TOKEN"
  GITHUB_AUTH_HEADER="-H \"Authorization: token ${GITHUB_TOKEN}\""
elif [ -n "$GITHUB_USERNAME" -a -n "$GITHUB_PASSWORD" ]; then
  echo "[${SCRIPT_NAME}] - found GITHUB_USERNAME and GITHUB_PASSWORD"
  GITHUB_AUTH_HEADER="-u \"${GITHUB_USERNAME}:${GITHUB_PASSWORD}\""
else
  echo "[${SCRIPT_NAME}] - [WARNING] no github authentication found, may found error of github api limitation."
fi
/bin/sh -c "curl -s $GITHUB_AUTH_HEADER https://api.github.com/rate_limit"
echo

################################################################################
echo "[${SCRIPT_NAME}] prepare working directory"
cd "$ROOT_PWD"
rm -f $WORK_DIR/zowe_sources-*
rm -fr "$ZIP_DIR"
mkdir -p "$ZIP_DIR"
echo

################################################################################
echo "[${SCRIPT_NAME}] download manifest.json"
/bin/sh -c "curl -s ${GITHUB_AUTH_HEADER} \"${ZOWE_MANIFEST}\"" > "${WORK_DIR}/manifest.json.template"
if [ -f "${WORK_DIR}/manifest.json.template" ]; then
  echo "[${SCRIPT_NAME}] - ${WORK_DIR}/manifest.json.template downloaded"
else
  echo "[${SCRIPT_NAME}][ERROR] - failed to download ${WORK_DIR}/manifest.json.template"
  exit 2
fi
echo

################################################################################
ZOWE_VERSION=$(jq -r '.version' "${WORK_DIR}/manifest.json.template")
echo "[${SCRIPT_NAME}] Zowe version is ${ZOWE_VERSION}"
echo

################################################################################
echo "[${SCRIPT_NAME}] write README.md"
cat > "${ZIP_DIR}/README.md" << EOF
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
ZOWE_SOURCE_DEPENDENCIES=$(jq -r '.sourceDependencies[] | .entries[] | .repository + "," + .tag' "${WORK_DIR}/manifest.json.template")
for repo in $ZOWE_SOURCE_DEPENDENCIES; do
  REPO_NAME=$(echo $repo | awk -F, '{print $1}')
  REPO_TAG=$(echo $repo | awk -F, '{print $2}')
  echo "[${SCRIPT_NAME}] - $REPO_NAME $REPO_TAG"
  echo "[${SCRIPT_NAME}]   - checking https://api.github.com/repos/zowe/${REPO_NAME}/git/refs/tags/${REPO_TAG}"
  REPO_HASH=$(/bin/sh -c "curl -s ${GITHUB_AUTH_HEADER} \"https://api.github.com/repos/zowe/${REPO_NAME}/git/refs/tags/${REPO_TAG}\"" | jq -r '.object.sha')
  EXIT_CODE=$?
  if [ "$EXIT_CODE" != "0" ]; then
    echo "[${SCRIPT_NAME}]   - [ERROR] failed to find tag hash, exit with ${EXIT_CODE}"
    exit 1
  fi
  if [ "$REPO_HASH" = "null" ]; then
    echo "[${SCRIPT_NAME}]   - [ERROR] failed to find tag hash, hash found as null"
    exit 1
  fi
  echo "[${SCRIPT_NAME}]   - found $REPO_HASH"
  REPO_HASH_SHORT=$(echo $REPO_HASH | cut -c 1-8)
  /bin/sh -c "curl -s ${GITHUB_AUTH_HEADER} \"https://codeload.github.com/zowe/${REPO_NAME}/zip/${REPO_TAG}\" --output \"${ZIP_DIR}/zowe-${REPO_NAME}-${REPO_TAG}-${REPO_HASH_SHORT}.zip\""
  if [ "$?" != "0" ]; then
    echo "[${SCRIPT_NAME}]   - [ERROR] failed to download source."
    exit 1
  else
    echo "[${SCRIPT_NAME}]   - zowe-${REPO_NAME}-${REPO_TAG}-${REPO_HASH_SHORT}.zip downloaded"
  fi
  sleep 2
done
echo

################################################################################
echo "[${SCRIPT_NAME}] source folder prepared:"
find "${ZIP_DIR}" -print
echo

################################################################################
echo "[${SCRIPT_NAME}] done."
exit 0
