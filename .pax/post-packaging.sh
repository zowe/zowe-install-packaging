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
# In an earlier step, the build pipeline created zowe.pax, and left
# us an installed Zowe.
#
# This script preps for future processing in catchall-packaging.sh
# and does SMP/E packaging related work.
#
# The next step in the build pipeline will
# 1. upload zowe.pax and SMP/E related files to Artifactory
# 2. remove all temp data, partilly done by catchall-packaging.sh
#
#######################################################################
set -x

# ---------------------------------------------------------------------
# --- get data passed from pre-packaging.sh
# creates $inst_hlq $inst_root $inst_log, might be NULL
# ---------------------------------------------------------------------
function _getPassedIn
{
echo "[$SCRIPT_NAME] getting data from pre-packaging.sh"
INST_WORK=${ROOT_DIR}/zowe-work    # keep in sync with pre-packaging.sh
INST_PASS=${INST_WORK}/zowe-install.txt # in sync with pre-packaging.sh
scripts=${INST_WORK}               # keep in sync with pre-packaging.sh
unset inst_hlq inst_root inst_log || true  # sync with pre-packaging.sh

if [ ! -f ${INST_PASS} ]; then
  echo "[${SCRIPT_NAME}] pre-packaging.sh did not create ${INST_PASS}"
else
  # get $inst_hlq $inst_root $inst_log
  for var in $(< ${INST_PASS})
  do
    eval $var
  done    # for var

  # show what pre-packaging.sh left us
  echo "[${SCRIPT_NAME}] content \$inst_root: ls -A $inst_root"
  ls -A $inst_root 2>&1 || true
  echo "[${SCRIPT_NAME}] inst_log=$inst_log"
  echo "[${SCRIPT_NAME}] inst_hlq=$inst_hlq"
fi    # ${INST_PASS} exists
}    # _getPassedIn

# ---------------------------------------------------------------------
# --- main --- main --- main --- main --- main --- main --- main ---
# ---------------------------------------------------------------------
# $0=./post-packaging.sh
SCRIPT_NAME=$(basename "$0")
BASE_DIR=$(dirname "$0")      # <something>
cd $BASE_DIR
ROOT_DIR=$(pwd)               # <something>

# get data passed from pre-packaging.sh
_getPassedIn
# you can now use $inst_hlq $inst_root $inst_log, might be NULL

# write data set HLQs we want catchall-packaging.sh to clean up
if [ "$inst_hlq" ]; then
  # keep in sync with catchall-packaging.sh
  echo "$inst_hlq" > ${ROOT_DIR}/cleanup-smpe-packaging-datasets.txt
fi    #

# continue processing ?
if [ "$BUILD_SMPE" != "yes" ]; then
  echo "[$SCRIPT_NAME] not building SMP/E package, skipping."
  exit 0                                                         # EXIT
fi

if [ -z "$ZOWE_VERSION" ]; then
  echo "[$SCRIPT_NAME] ZOWE_VERSION environment variable is missing"
  exit 1                                                         # EXIT
else
  echo "[$SCRIPT_NAME] working on Zowe v${ZOWE_VERSION} ..."
fi

# show what's already present
#echo "[${SCRIPT_NAME}] content \$ROOT_DIR: find ."
#find . || true                            # includes installed product
echo "[${SCRIPT_NAME}] content \$ROOT_DIR: ls -A ."
ls -A . || true

# define constants for this build
# keep in ${ROOT_DIR} so pipeline variable $KEEP_TEMP_FOLDER applies
SMPE_BUILD_ROOT=${ROOT_DIR}/zowe
SMPE_BUILD_LOG_DIR=${SMPE_BUILD_ROOT}/logs # keep in sync with default log dir in smpe/bld/get-config.sh
SMPE_BUILD_SHIP_DIR=${SMPE_BUILD_ROOT}/ship # keep in sync with default ship dir in smpe/bld/get-config.sh
SMPE_BUILD_HLQ=${USER:-${USERNAME:-${LOGNAME}}}
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
SMPE_BUILD_VOLSER=ZOWE02

# add rx permission to all smpe files
chmod -R 755 ${ROOT_DIR}/smpe

# create smpe.pax
cd ${ROOT_DIR}/smpe/pax
echo "files to be pax'd"
ls -lER .
pax -x os390 -w -f ${ROOT_DIR}/smpe.pax *
cd ${ROOT_DIR}

# extract last build log
LAST_BUILD_LOG=$(ls -1 ${ROOT_DIR}/smpe/smpe-build-logs* || true)
if [ -n "${LAST_BUILD_LOG}" ]; then
  mkdir -p "${SMPE_BUILD_LOG_DIR}"
  cd "${SMPE_BUILD_LOG_DIR}"
  pax -rf "${LAST_BUILD_LOG}" *
  cd "${ROOT_DIR}"
fi

# display all files, including input pax files & extracted log files
relative_root=$(echo $inst_root | sed "s!${ROOT_DIR}!.!")
echo "[$SCRIPT_NAME] content of ${ROOT_DIR}.... (excluding installed components)"
find . -print | grep -v "$relative_root/components/"

# find input pax files
if [ ! -f ${ROOT_DIR}/zowe.pax ]; then
  echo "[$SCRIPT_NAME][ERROR] Cannot find Zowe package."
  exit 1                                                         # EXIT
fi

if [ ! -f ${ROOT_DIR}/smpe.pax ]; then
  echo "[$SCRIPT_NAME][ERROR] Cannot find SMP/E package."
  exit 1                                                         # EXIT
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
touch "${INPUT_TXT}"
echo "${ROOT_DIR}/zowe.pax" >> "${INPUT_TXT}"
echo "${ROOT_DIR}/smpe.pax" >> "${INPUT_TXT}"
echo "[$SCRIPT_NAME] content of ${INPUT_TXT}:"
cat "${INPUT_TXT}"

mkdir -p ${SMPE_BUILD_ROOT} ${SMPE_BUILD_LOG_DIR}

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
#% -h hlq          use the specified high level qualifier
#% -i inputFile    reference file listing input files to process
#% -r rootDir      use the specified root directory
#% -v vrm          FMID 3-character version/release/modification
#% optional
#% -a alter.sh     execute script before/after install to alter setup
#% -b branch       GitHub branch used for this build
#% -B build        GitHub build number for this branch
#% -d              enable debug messages
#% -E success      exit with RC 0, create file on successful completion
#% -H installHlq   use the specified pre-installed product install MVS
#% -I installDir   use the specified pre-installed product install USS
#% -L install.log  use the specified pre-installed product install log
#% -p version      product version
#% -P              fail build if APAR/USERMOD is created instead of PTF
#% -V volume       allocate data sets on specified volume(s)

external=""
echo "BRANCH_NAME=$BRANCH_NAME"
test -n "$BRANCH_NAME" && external="$external -b $BRANCH_NAME"
echo "BUILD_NUMBER=$BUILD_NUMBER"
test -n "$BUILD_NUMBER" && external="$external -B $BUILD_NUMBER"
echo "ZOWE_VERSION=$ZOWE_VERSION"
test -n "$ZOWE_VERSION" && external="$external -p $ZOWE_VERSION"

opt=""
test -z "${inst_root}" && opt="$opt -a ${ROOT_DIR}/smpe/bld/alter.sh"
opt="$opt -d"
opt="$opt -E ${SMPE_BUILD_SHIP_DIR}/success"
opt="$opt -V ${SMPE_BUILD_VOLSER}"
opt="$opt -h ${SMPE_BUILD_HLQ}.${RANDOM_MLQ}"
opt="$opt -i ${ROOT_DIR}/${INPUT_TXT}"
test -n "${inst_hlq}" && opt="$opt -H ${inst_hlq}"
test -n "${inst_root}" && opt="$opt -I ${inst_root}"
test -n "${inst_log}" && opt="$opt -L ${inst_log}"
opt="$opt -r ${SMPE_BUILD_ROOT}"
opt="$opt -v ${FMID_VERSION}"
${ROOT_DIR}/smpe/bld/smpe.sh  $opt $external

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
echo "[$SCRIPT_NAME] content of ${SMPE_BUILD_ROOT}.... (excluding installed components)"
find ${SMPE_BUILD_ROOT} -print | grep -v "/components/"

# see if SMPE build completed successfully
# MUST be done AFTER tasks that must always run after SMPE build
if [ ! -f "${SMPE_BUILD_SHIP_DIR}/success" ]; then
  echo "[$SCRIPT_NAME][ERROR] SMPE build did not complete successfully"
  exit 1                                                         # EXIT
fi

# TODO we no longer need the uppercase tempdir, so this should be obsolete
# remove tmp folder
UC_ROOT_DIR=$(echo "${ROOT_DIR}" | tr [a-z] [A-Z])
if [ "${UC_ROOT_DIR}" != "${ROOT_DIR}" ]; then
  # ROOT_DIR will be removed after build automatically, we just need to delete
  # the extra temp folder in uppercase created by GIMZIP
  rm -fr "${UC_ROOT_DIR}"
fi

# save current build log directory, will be placed in artifactory
cd "${SMPE_BUILD_LOG_DIR}"
pax -w -f "${ROOT_DIR}/smpe-build-logs.pax.Z" *

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
if [ -f ${ROOT_DIR}/smpe/bld/service/ptf-bucket.txt ]; then       # PTF
  cp  ${SMPE_PTF_ZIP} ${ROOT_DIR}/zowe-smpe.zip
  # do not alter existing PD in docs, wipe content of the new one
  rm "${SMPE_BUILD_SHIP_DIR}/${SMPE_PD_HTM}"
  touch "${SMPE_BUILD_SHIP_DIR}/${SMPE_PD_HTM}"
else                                                             # FMID
  cp ${SMPE_FMID_ZIP} ${ROOT_DIR}/zowe-smpe.zip
  # doc build pipeline must pick up PD for inclusion
fi

# stage build output for upload to artifactory
cd "${ROOT_DIR}"
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
# ${ROOT_DIR}/smpe-build-logs.pax.Z
# ${ROOT_DIR}/zowe.pax               -> goes to zowe.org
# ${ROOT_DIR}/zowe-smpe.zip          -> goes to zowe.org
# ${ROOT_DIR}/fmid.zip
# ${ROOT_DIR}/pd.htm                 -> can be a null file
# ${ROOT_DIR}/smpe-promote.tar       -> can be a null file
