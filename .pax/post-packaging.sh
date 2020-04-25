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
# runs on z/OS, after creating zowe.pax
#
#######################################################################
set -x

SCRIPT_NAME=$(basename "$0")
CURR_PWD=$(pwd)

if [ "$BUILD_SMPE" != "yes" ]; then
  echo "[$SCRIPT_NAME] not building SMP/E package, skipping."
  exit 0
fi

if [ -z "$ZOWE_VERSION" ]; then
  echo "[$SCRIPT_NAME] ZOWE_VERSION environment variable is missing"
  exit 1
else
  echo "[$SCRIPT_NAME] working on Zowe v${ZOWE_VERSION} ..."
fi

# define constants for this build
SMPE_BUILD_ROOT=${CURR_PWD}/zowe
SMPE_BUILD_LOG_DIR=${SMPE_BUILD_ROOT}/logs # keep in sync with default log dir in smpe/bld/get-config.sh
SMPE_BUILD_SHIP_DIR=${SMPE_BUILD_ROOT}/ship # keep in sync with default ship dir in smpe/bld/get-config.sh
# random MLQ must begin with letter, @, #, or $, max 8 char
RANDOM_MLQ=ZWE$RANDOM  # RANDOM gives a random number between 0 & 32767
INPUT_TXT=input.txt
# FMID numbering is not VRM, just V(ersion)
ZOWE_VERSION_MAJOR=$(echo "${ZOWE_VERSION}" | awk -F. '{print $1}')
# pad ZOWE_VERSION_MAJOR to be at least 3 chars long, then keep last 3
FMID_VERSION=$(echo "00${ZOWE_VERSION_MAJOR}" | sed 's/.*\(...\)$/\1/')
FMID=AZWE${FMID_VERSION}

# define constants specific for Marist server
# to package on another server, we may need different settings
export TMPDIR=/ZOWE/tmp
SMPE_BUILD_HLQ=ZOWEAD3
SMPE_BUILD_VOLSER=ZOWE02

# write data sets list we want to clean up
echo "${SMPE_BUILD_HLQ}.${RANDOM_MLQ}" > ${CURR_PWD}/cleanup-smpe-packaging-datasets.txt

# add rx permission to all smpe files
chmod -R 755 smpe

# create smpe.pax
cd ${CURR_PWD}/smpe/pax
echo "files to be pax'd"
ls -lER .
pax -x os390 -w -f ../../smpe.pax *
cd ${CURR_PWD}

# extract last build log
LAST_BUILD_LOG=$(ls -1 ${CURR_PWD}/smpe/smpe-build-logs* || true)
if [ -n "${LAST_BUILD_LOG}" ]; then
  mkdir -p "${SMPE_BUILD_LOG_DIR}"
  cd "${SMPE_BUILD_LOG_DIR}"
  pax -rf "${LAST_BUILD_LOG}" *
  cd "${CURR_PWD}"
fi

# display all files, including input pax files & extracted log files
echo "[$SCRIPT_NAME] content of $CURR_PWD...."
find . -print

# find input pax files
if [ ! -f zowe.pax ]; then
  echo "[$SCRIPT_NAME][ERROR] Cannot find Zowe package."
  exit 1
fi
if [ ! -f smpe.pax ]; then
  echo "[$SCRIPT_NAME][ERROR] Cannot find SMP/e package."
  exit 1
fi

# get build info from manifest.json
# input:
# {
#   "name": "Zowe",
#   "version": "1.7.1",
#   "description": "Zowe is an open source project created to host technol
#   "license": "EPL-2.0",
#   "homepage": "https://zowe.org",
#   "build": {
#     "branch": "PR-930",
#     "number": "32",
#     "commitHash": "83facefb49826b103d649021ffa51ffca0ac9061",
#     "timestamp": "1576619639516"
#   },
#   ...
# output:
# PR-930
# 1. sed limits data to build { ... } block
#   "build": {
#     "branch": "PR-930",
#     "number": "32",
#     "commitHash": "83facefb49826b103d649021ffa51ffca0ac9061",
#     "timestamp": "1576619639516"
#   },
# 2a. sed strips branch label
#   "build": {
# PR-930",
#     "number": "32",
#     "commitHash": "83facefb49826b103d649021ffa51ffca0ac9061",
#     "timestamp": "1576619639516"
#   },
# 2b. sed removes all lines starting with a blank
# PR-930",
# 2c. sed strips trailing ",
# PR-930
manifest=$(find . -print | grep manifest.json)
BRANCH_NAME=$(sed -n '/ "build": {/,/ },/p' $manifest \
              | sed 's/ *"branch": "//;/^ /d;s/",$//')
BUILD_NUMBER=$(sed -n '/ "build": {/,/ },/p' $manifest \
              | sed 's/ *"number": "//;/^ /d;s/",$//')

# SMPE build expects a text file specifying the files it must process
echo "[$SCRIPT_NAME] preparing ${INPUT_TXT} ..."
echo "${SMPE_BUILD_ROOT}.pax" > "${INPUT_TXT}"
echo "${CURR_PWD}/smpe.pax" >> "${INPUT_TXT}"
echo "[$SCRIPT_NAME] content of ${INPUT_TXT}:"
cat "${INPUT_TXT}"

mkdir -p ${SMPE_BUILD_ROOT}

echo
echo "+-------------------------+"
echo "|+-----------------------+|"
echo "||                       ||"
echo "||  SMPE build starting  ||"
echo "||                       ||"
echo "|+-----------------------+|"
echo "+-------------------------+"
echo

# start SMPE build
#% required
#% -h hlq        use the specified high level qualifier
#% -i inputFile  reference file listing input files to process
#% -r rootDir    use the specified root directory
#% -v vrm        FMID 3-character version/release/modification
#% optional
#% -a alter.sh   execute script before/after install to alter setup
#% -b branch     GitHub branch used for this build
#% -B build      GitHub build number for this branch
#% -d            enable debug messages
#% -E success    exit with RC 0, create file on successful completion
#% -p version    product version
#% -P            fail build if APAR/USERMOD is created instead of PTF
#% -V volume     allocate data sets on specified volume(s)

external=""
echo "BRANCH_NAME=$BRANCH_NAME"
test -n "$BRANCH_NAME" && external="$external -b $BRANCH_NAME"
echo "BUILD_NUMBER=$BUILD_NUMBER"
test -n "$BUILD_NUMBER" && external="$external -B $BUILD_NUMBER"
echo "ZOWE_VERSION=$ZOWE_VERSION"
test -n "$ZOWE_VERSION" && external="$external -p $ZOWE_VERSION"

${CURR_PWD}/smpe/bld/smpe.sh \
  -a ${CURR_PWD}/smpe/bld/alter.sh \
  -d \
  -E "${SMPE_BUILD_SHIP_DIR}/success" \
  -V "${SMPE_BUILD_VOLSER}" \
  -h "${SMPE_BUILD_HLQ}.${RANDOM_MLQ}" \
  -i "${CURR_PWD}/${INPUT_TXT}" \
  -r "${SMPE_BUILD_ROOT}" \
  -v ${FMID_VERSION} \
  $external

echo
echo "+----------------------+"
echo "|+--------------------+|"
echo "||                    ||"
echo "||  SMPE build ended  ||"
echo "||                    ||"
echo "|+--------------------+|"
echo "+----------------------+"
echo

# display all files left behind by SMPE build
echo "[$SCRIPT_NAME] content of ${SMPE_BUILD_ROOT}...."
find ${SMPE_BUILD_ROOT} -print

# see if SMPE build completed successfully
# MUST be done AFTER tasks that must always run after SMPE build
if [ ! -f "${SMPE_BUILD_SHIP_DIR}/success" ]; then
  echo "[$SCRIPT_NAME][ERROR] SMPE build did not complete successfully"
  exit 1
fi

# TODO we no longer need the uppercase tempdir, so this should be obsolete
# remove tmp folder
UC_CURR_PWD=$(echo "${CURR_PWD}" | tr [a-z] [A-Z])
if [ "${UC_CURR_PWD}" != "${CURR_PWD}" ]; then
  # CURR_PWD will be removed after build automatically, we just need to delete
  # the extra temp folder in uppercase created by GIMZIP
  rm -fr "${UC_CURR_PWD}"
fi

# save current build log directory, will be placed in artifactory
cd "${SMPE_BUILD_LOG_DIR}"
pax -w -f "${CURR_PWD}/smpe-build-logs.pax.Z" *

# find the final build results
cd "${SMPE_BUILD_SHIP_DIR}"
SMPE_FMID_ZIP="${FMID}.zip" # keep in sync with smpe/bld/smpe-pd.sh
if [ ! -f "${SMPE_FMID_ZIP}" ]; then
  echo "[$SCRIPT_NAME][ERROR] cannot find SMPE_FMID_ZIP build result '${SMPE_FMID_ZIP}'"
  exit 1
fi
SMPE_PTF_ZIP="$(ls -1 ${FMID}.*.zip || true)" # keep in sync with smpe/bld/smpe-service.sh
if [ ! -f "${SMPE_PTF_ZIP}" ]; then
  echo "[$SCRIPT_NAME][ERROR] cannot find SMPE_PTF_ZIP build result '${SMPE_PTF_ZIP}'"
  exit 1
fi
SMPE_PD_HTM="${FMID}.htm" # keep in sync with smpe/bld/smpe-pd.sh
if [ ! -f "${SMPE_PD_HTM}" ]; then
  echo "[$SCRIPT_NAME][ERROR] cannot find SMPE_PD_HTM build result '${SMPE_PD_HTM}'"
  exit 1
fi
SMPE_PROMOTE_TAR="smpe-promote.tar" # keep in sync with smpe/bld/smpe-service.sh
if [ ! -f "${SMPE_PROMOTE_TAR}" ]; then
  echo "[$SCRIPT_NAME][ERROR] cannot find SMPE_PROMOTE_TAR build result '${SMPE_PROMOTE_TAR}'"
  exit 1
fi

# if ptf-bucket.txt exists then publish PTF, otherwise publish FMID
cd "${SMPE_BUILD_SHIP_DIR}"
if [ -f ${CURR_PWD}/smpe/bld/service/ptf-bucket.txt ]; then       # PTF
  cp  ${SMPE_PTF_ZIP} ${CURR_PWD}/zowe-smpe.zip
  # do not alter existing PD in docs, wipe content of the new one
  rm "${SMPE_BUILD_SHIP_DIR}/${SMPE_PD_HTM}"
  touch "${SMPE_BUILD_SHIP_DIR}/${SMPE_PD_HTM}"
else                                                             # FMID
  cp ${SMPE_FMID_ZIP} ${CURR_PWD}/zowe-smpe.zip
  # doc build pipeline must pick up PD for inclusion
fi

# stage build output for upload to artifactory
cd "${CURR_PWD}"
mv "${SMPE_BUILD_SHIP_DIR}/${SMPE_FMID_ZIP}"  fmid.zip
mv "${SMPE_BUILD_SHIP_DIR}/${SMPE_PD_HTM}" pd.htm
mv "${SMPE_BUILD_SHIP_DIR}/${SMPE_PROMOTE_TAR}" ${SMPE_PROMOTE_TAR}

# prepare rename to original name
# leave fixed name for PD to simplify automated processing by doc build
# leave fixed name for promote.tar to simplify automated processing during promote
echo "mv fmid.zip ${SMPE_FMID_ZIP}" > rename-back.sh.1047
iconv -f IBM-1047 -t ISO8859-1 rename-back.sh.1047 > rename-back.sh

echo "[$SCRIPT_NAME] done"

# files to be uploaded to artifactory:
# ${CURR_PWD}/smpe-build-logs.pax.Z
# ${CURR_PWD}/zowe-smpe.zip          -> goes to zowe.org
# ${CURR_PWD}/fmid.zip
# ${CURR_PWD}/pd.htm                 -> can be a null file
# ${CURR_PWD}/smpe-promote.tar       -> can be a null file
