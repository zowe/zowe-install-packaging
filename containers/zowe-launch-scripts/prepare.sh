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

################################################################################
# FUNCTIONS
interpret_artifact_pattern() {
  component_id=$1
  artifact=$2

  component_id_regex=$(echo "${component_id}" | sed "s#\.#\\\.#g")
  component_id_path=$(echo "${component_id}" | sed "s#\.#/#g")

  cd "${REPO_ROOT_DIR}"

  if [ -n "${BASE_DIR}" -a -n "${WORK_DIR}" ]; then
    manifest="${BASE_DIR}/${WORK_DIR}/manifest.json"
  else
    manifest="manifest.json.template"
  fi
  artifact_version_pattern=$(cat "${manifest}" | awk "/${component_id_regex}/{x=NR+10;next}(NR<=x){print}" | sed -e '/\}/,+10d' | grep "\"version\":" | head -n 1 | awk -F: '{print $2;}' | xargs | sed -e 's/,$//' | sed -e 's/^"//' -e 's/"$//')
  artifact_repository=$(cat "${manifest}" | awk "/${component_id_regex}/{x=NR+10;next}(NR<=x){print}" | sed -e '/\}/,+10d' | grep "\"repository\":" | head -n 1 | awk -F: '{print $2;}' | xargs | sed -e 's/,$//' | sed -e 's/^"//' -e 's/"$//')
  artifact_file_pattern=$(cat "${manifest}" | awk "/${component_id_regex}/{x=NR+10;next}(NR<=x){print}" | sed -e '/\}/,+10d' | grep "\"artifact\":" | head -n 1 | awk -F: '{print $2;}' | xargs | sed -e 's/,$//' | sed -e 's/^"//' -e 's/"$//')
  echo "    - artifact version: ${artifact_version_pattern}"
  echo "            repository: ${artifact_repository:-<empty>}"
  echo "                  file: ${artifact_file_pattern:-<empty>}"
  first_char=$(echo "${artifact_version_pattern}" | cut -c1-1)
  wildcard_level=
  if [ "${first_char}" = "~" ]; then
    wildcard_level=patch
  fi
  if [ "${first_char}" = "^" ]; then
    wildcard_level=minor
  fi
  artifact_version=$(echo "${artifact_version_pattern}" | cut -d "-" -f1 | sed -e 's/\^//' -e 's/~//')
  has_meta=$(echo "${artifact_version_pattern}" | grep "-" || true)
  if [ -n "${has_meta}" ]; then
    artifact_version_meta=$(echo "${artifact_version_pattern}" | cut -d "-" -f2-)
  else
    artifact_version_meta=
  fi
  artifact_version_major=$(echo "${artifact_version}" | awk -F. '{print $1}')
  artifact_version_minor=$(echo "${artifact_version}" | awk -F. '{print $2}')
  artifact_version_patch=$(echo "${artifact_version}" | awk -F. '{print $3}')
  if [ -n "${artifact_version_meta}" ]; then
    artifact_version_meta=-${artifact_version_meta}
  fi
  echo "                 major: ${artifact_version_major}"
  echo "                 minor: ${artifact_version_minor}"
  echo "                 patch: ${artifact_version_patch}"
  echo "                  meta: ${artifact_version_meta}"
  echo "        wildcard level: ${wildcard_level}"
  if [ "${wildcard_level}" = "patch" ]; then
    jfrog_path=${artifact_repository:-${JFROG_REPO_SNAPSHOT}}/${component_id_path}/${artifact_version_major}.${artifact_version_minor}.*${artifact_version_meta}/${artifact:-${artifact_file_pattern}}
  elif [ "${wildcard_level}" = "minor" ]; then
    jfrog_path=${artifact_repository:-${JFROG_REPO_SNAPSHOT}}/${component_id_path}/${artifact_version_major}.*-${artifact_version_meta}/${artifact:-${artifact_file_pattern}}
  else
    jfrog_path=${artifact_repository:-${JFROG_REPO_RELEASE}}/${component_id_path}/${artifact_version_major}.${artifact_version_minor}.${artifact_version_patch}${artifact_version_meta}/${artifact:-${artifact_file_pattern}}
  fi
  echo "       > final pattern: ${jfrog_path}"
}

###############################
echo ">>>>> prepare basic files"
cd "${REPO_ROOT_DIR}"
package_version=$(jq -r '.version' manifest.json.template)
package_release=$(echo "${package_version}" | awk -F. '{print $1;}')

###############################
# copy Dockerfile
echo ">>>>> copy Dockerfile to ${linux_distro}/${cpu_arch}/Dockerfile"
cd "${BASE_DIR}"
rm -fr "${linux_distro}/${cpu_arch}"
mkdir -p "${linux_distro}/${cpu_arch}"
if [ ! -f Dockerfile ]; then
  echo "Error: Dockerfile file is missing."
  exit 2
fi
cat Dockerfile | sed -e "s#version=\"0\.0\.0\"#version=\"${package_version}\"#" -e "s#release=\"0\"#release=\"${package_release}\"#" > "${linux_distro}/${cpu_arch}/Dockerfile"

###############################
echo ">>>>> clean up folder"
rm -fr "${BASE_DIR}/${WORK_DIR}"
mkdir -p "${BASE_DIR}/${WORK_DIR}"

###############################
echo ">>>>> prepare basic files"
cd "${REPO_ROOT_DIR}"
cp example-zowe.yaml "${BASE_DIR}/${WORK_DIR}"
cp ZOWE.md "${BASE_DIR}/${WORK_DIR}/README.md"
cp LICENSE "${BASE_DIR}/${WORK_DIR}"
cp DEVELOPERS.md "${BASE_DIR}/${WORK_DIR}"

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
echo ">>>>> prepare bin directory"
cd "${REPO_ROOT_DIR}"
cp -r bin "${BASE_DIR}/${WORK_DIR}"

###############################
# prepare utility tools
echo ">>>>> prepare utility tools"
jfrog_path=
interpret_artifact_pattern "org.zowe.utility-tools" "*.zip"
util_zip=$(jfrog rt s "${jfrog_path}" --sort-by created --sort-order desc --limit 1 | jq -r '.[0].path')
if [ -z "${util_zip}" ]; then
  echo "Error: cannot find org.zowe.utility-tools artifact."
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
echo "    - extract zowe-ncert ..."
mkdir -p "${BASE_DIR}/${WORK_DIR}/bin/utils/ncert"
tar xvf zowe-ncert-*.pax -C "${BASE_DIR}/${WORK_DIR}/bin/utils/ncert"
rm zowe-ncert-*.pax

###############################
# prepare zlux core
echo ">>>>> prepare zlux core"
jfrog_path=
interpret_artifact_pattern "org.zowe.zlux.zlux-core" "zlux-core-*.tar"
zlux_tar=$(jfrog rt s "${jfrog_path}" --sort-by created --sort-order desc --limit 1 | jq -r '.[0].path')
if [ -z "${zlux_tar}" ]; then
  echo "Error: cannot find org.zowe.zlux.zlux-core artifact."
  exit 1
fi
echo "    - artifact found: ${zlux_tar}"
echo "    - download and extract"
curl -s ${JFROG_URL}${zlux_tar} --output zlux-core.tar
mkdir -p "${BASE_DIR}/${WORK_DIR}/components/app-server/share"
cd "${BASE_DIR}/${WORK_DIR}/components/app-server/share"
tar xf "${REPO_ROOT_DIR}/zlux-core.tar"
rm -fr zlux-app-manager zlux-build zlux-platform
# should leave zlux-app-server, zlux-server-framework and zlux-shared in the folder
cd "${REPO_ROOT_DIR}"
rm -f zlux-core.tar

###############################
# copy to target context
echo ">>>>> copy to target build context"
# || true is to solve error messages like: node_modules/.bin/node-gyp-build: No such file or directory
cp -r "${BASE_DIR}/${WORK_DIR}" "${BASE_DIR}/${linux_distro}/${cpu_arch}/zowe" || true

###############################
# done
echo ">>>>> all done"
