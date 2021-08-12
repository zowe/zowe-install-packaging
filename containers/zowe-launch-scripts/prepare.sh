#!/bin/bash

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project.
################################################################################

################################################################################
# prepare docker build context
#
# This script will be executed with 2 parameters:
# - linux-distro
# - cpu-arch

################################################################################
# This script prepares all required files we plan to put into zowe-launch-scripts
# image.
#
# Prereqs:
# - must run with Github Actions (with GITHUB_RUN_NUMBER and GITHUB_SHA)
# - must provide $GITHUB_PR_ID is it's pull request
# - must initialize jFrog CLI
# - requires extra tools like jq, curl, tar, gzip, date

# exit if there are errors
set -e

###############################
# check parameters
linux_distro=$1
cpu_arch=$2
if [ -z "${linux_distro}" ]; then
  echo "Error: linux-distro parameter is missing."
  exit 1
fi
if [ -z "${cpu_arch}" ]; then
  echo "Error: cpu-arch parameter is missing."
  exit 1
fi

################################################################################
# CONSTANTS
# this should be containers/zowe-launch-scripts
BASE_DIR=$(cd $(dirname $0);pwd)
REPO_ROOT_DIR=$(cd $(dirname $0)/../../;pwd)
WORK_DIR=tmp
JFROG_REPO_SNAPSHOT=libs-snapshot-local
JFROG_REPO_RELEASE=libs-release-local
JFROG_URL=https://zowe.jfrog.io/zowe/

###############################
# copy Dockerfile
echo ">>>>> copy Dockerfile to ${linux_distro}/${cpu_arch}/Dockerfile"
mkdir -p "${linux_distro}/${cpu_arch}"
if [ ! -f Dockerfile ]; then
  echo "Error: Dockerfile file is missing."
  exit 2
fi
cp Dockerfile "${linux_distro}/${cpu_arch}/Dockerfile"

###############################
echo ">>>>> clean up folder"
rm -fr "${BASE_DIR}/${WORK_DIR}"
mkdir -p "${BASE_DIR}/${WORK_DIR}"

###############################
echo ">>>>> prepare basic files"
cd "${REPO_ROOT_DIR}"
cp README.md "${BASE_DIR}/${WORK_DIR}"
cp LICENSE "${BASE_DIR}/${WORK_DIR}"
cp CHANGELOG.md "${BASE_DIR}/${WORK_DIR}"

###############################
echo ">>>>> prepare manifest.json"
cd "${REPO_ROOT_DIR}"
if [ -n "${GITHUB_PR_ID}" ]; then
  GITHUB_BRANCH=PR-${GITHUB_PR_ID}
else
  GITHUB_BRANCH=${GITHUB_REF#refs/heads/}
fi
echo "    - branch: ${GITHUB_BRANCH}"
echo "    - build number: ${GITHUB_RUN_NUMBER}"
echo "    - commit hash: ${GITHUB_SHA}"
# assume to run in Github Actions
cat manifest.json.template | \
  sed -e "s#{BUILD_BRANCH}#${GITHUB_BRANCH}#" \
      -e "s#{BUILD_NUMBER}#${GITHUB_RUN_NUMBER}#" \
      -e "s#{BUILD_COMMIT_HASH}#${GITHUB_SHA}#" \
      -e "s#{BUILD_TIMESTAMP}#$(date +%s)#" \
  > "${BASE_DIR}/${WORK_DIR}/manifest.json"

###############################
echo ">>>>> prepare bin and script directory"
cd "${REPO_ROOT_DIR}"
cp -r bin "${BASE_DIR}/${WORK_DIR}"
cp -r scripts "${BASE_DIR}/${WORK_DIR}"
# tweaks for scripts directory
mkdir "${BASE_DIR}/${WORK_DIR}/scripts/internal"
mv "${BASE_DIR}/${WORK_DIR}/scripts/ocopyshr.clist" "${BASE_DIR}/${WORK_DIR}/scripts/internal"
mv "${BASE_DIR}/${WORK_DIR}/scripts/ocopyshr.sh" "${BASE_DIR}/${WORK_DIR}/scripts/internal"
mv "${BASE_DIR}/${WORK_DIR}/scripts/opercmd" "${BASE_DIR}/${WORK_DIR}/scripts/internal"
mv "${BASE_DIR}/${WORK_DIR}/scripts/tag-files.sh" "${BASE_DIR}/${WORK_DIR}/scripts/utils"
rm "${BASE_DIR}/${WORK_DIR}/scripts/zowe-install-MVS.sh"

###############################
# prepare utility tools
echo ">>>>> prepare utility tools"
cd "${REPO_ROOT_DIR}"
util_version_pattern=$(cat "${BASE_DIR}/${WORK_DIR}/manifest.json" | awk "/org\.zowe\.utility_tools/{x=NR+19;next}(NR<=x){print}" | grep "version" | head -n 1 | awk -F: '{print $2;}' | xargs | sed -e 's/^"//' -e 's/"$//')
echo "    - utility version ${util_version_pattern}"
wildcard_level=
if [[ "${util_version_pattern}" =~ ~* ]]; then
  wildcard_level=patch
fi
if [[ "${util_version_pattern}" =~ ^* ]]; then
  wildcard_level=minor
fi
util_version=$(echo "${util_version_pattern}" | cut -d "-" -f1 | sed -e 's/\^//' -e 's/~//')
util_version_meta=$(echo "${util_version_pattern}" | cut -d "-" -f2-)
util_version_major=$(echo "${util_version}" | awk -F. '{print $1}')
util_version_minor=$(echo "${util_version}" | awk -F. '{print $2}')
util_version_patch=$(echo "${util_version}" | awk -F. '{print $3}')
if [ -n "${util_version_meta}" ]; then
  util_version_meta=-${util_version_meta}
fi
echo "    - utility version interpreted:"
echo "        - major: ${util_version_major}"
echo "        - minor: ${util_version_minor}"
echo "        - patch: ${util_version_patch}"
echo "        - meta: ${util_version_meta}"
echo "        - wildcard level: ${wildcard_level}"
if [ "${wildcard_level}" = "patch" ]; then
  jfrog_path=${JFROG_REPO_SNAPSHOT}/org/zowe/utility_tools/${util_version_major}.${util_version_minor}.*${util_version_meta}/*.zip
elif [ "${wildcard_level}" = "minor" ]; then
  jfrog_path=${JFROG_REPO_SNAPSHOT}/org/zowe/utility_tools/${util_version_major}.*-${util_version_meta}/*.zip
else
  jfrog_path=${JFROG_REPO_RELEASE}/org/zowe/utility_tools/${util_version_major}.${util_version_minor}.${util_version_patch}${util_version_meta}/*.zip
fi
echo "    - artifact path pattern: ${jfrog_path}"
util_zip=$(jfrog rt s "${jfrog_path}" --sort-by created --sort-order desc --limit 1 | jq -r '.[0].path')
if [ -z "${util_zip}" ]; then
  echo "Error: cannot find org.zowe.utility_tools artifact."
  exit 1
fi
echo "    - artifact found: ${util_zip}"
echo "    - download and extract"
curl -s ${JFROG_URL}${util_zip} --output zowe-utility-tools.zip
unzip zowe-utility-tools.zip
rm zowe-utility-tools.zip
echo "    - extract zowe-fconv ..."
tar zxf zowe-fconv-*.tgz -C "${BASE_DIR}/${WORK_DIR}/bin/utils"
mv "${BASE_DIR}/${WORK_DIR}/bin/utils/package" "${BASE_DIR}/${WORK_DIR}/bin/utils/fconv"
rm zowe-fconv-*.tgz
echo "    - extract zowe-njq ..."
tar zxf zowe-njq-*.tgz -C "${BASE_DIR}/${WORK_DIR}/bin/utils"
mv "${BASE_DIR}/${WORK_DIR}/bin/utils/package" "${BASE_DIR}/${WORK_DIR}/bin/utils/njq"
rm zowe-njq-*.tgz
echo "    - extract zowe-config-converter ..."
tar zxf zowe-config-converter-*.tgz -C "${BASE_DIR}/${WORK_DIR}/bin/utils"
mv "${BASE_DIR}/${WORK_DIR}/bin/utils/package" "${BASE_DIR}/${WORK_DIR}/bin/utils/config-converter"
rm zowe-config-converter-*.tgz
rm -f "${CONTENT_DIR}/files/zowe-utility-tools.zip"

###############################
# copy to target context
echo ">>>>> copy to target build context"
cp -r "${BASE_DIR}/${WORK_DIR}" "${BASE_DIR}/${linux_distro}/${cpu_arch}/zowe"

###############################
# done
echo ">>>>> all done"
