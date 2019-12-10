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

SCRIPT_NAME=$(basename "$0")
CURR_PWD=$(pwd)

if [ "$BUILD_SMPE" != "yes" ]; then
  echo "[$SCRIPT_NAME] not building SMP/e package, skipping."
  exit 0
fi

if [ -z "${ZOWE_VERSION}" ]; then
  echo "[$SCRIPT_NAME][ERROR] ZOWE_VERSION environment variable is missing"
  exit 1
fi

# add x permission to all smpe files
chmod -R 755 smpe

INPUT_TXT=input.txt
ZOWE_VERSION_MAJOR=$(echo "${ZOWE_VERSION}" | awk -F. '{print $1}')
# pad ZOWE_VERSION_MAJOR to be at least 3 chars long, then keep last 3
FMID_VERSION=$(echo "00${ZOWE_VERSION_MAJOR}" | sed 's/.*\(...\)$/\1/')

#Generate JCL boilerplates
for entry in $(ls "./smpe/pax/ZOSMF/vtls/")
do
  if [ "${entry##*.}" = "vtl" ]
  then
    MVS_PATH="./smpe/pax/MVS/"
    LOCAL_PATH="./smpe/pax/ZOSMF/vtls/"
    VTL=${LOCAL_PATH}${entry} 
    BASE=${VTL%.*}
    YAML=${BASE}".yml"
    JCL=${MVS_PATH}"$(basename -- $BASE).jcl"
    java -jar /ZOWE/vtl-cli/vtl-cli.jar -ie Cp1140 --yaml-context ${YAML} ${VTL} -o ${JCL} -oe Cp1140
  fi
done

# create smpe.pax
cd smpe/pax
pax -x os390 -w -f ../../smpe.pax *
cd ../..

# extract last build log
LAST_BUILD_LOG=$(ls -1 smpe/smpe-build-logs* || true)
if [ -n "${LAST_BUILD_LOG}" ]; then
  mkdir -p "zowe/AZWE${FMID_VERSION}/logs"
  cd "zowe/AZWE${FMID_VERSION}/logs"
  pax -rf "${CURR_PWD}/${LAST_BUILD_LOG}" *
  cd "${CURR_PWD}"
fi

# display extracted files
echo "[$SCRIPT_NAME] content of $CURR_PWD...."
find . -print

# find zowe pax
if [ ! -f zowe.pax ]; then
  echo "[$SCRIPT_NAME][ERROR] Cannot find Zowe package."
  exit 1
fi
if [ ! -f smpe.pax ]; then
  echo "[$SCRIPT_NAME][ERROR] Cannot find SMP/e package."
  exit 1
fi

echo "[$SCRIPT_NAME] preparing ${INPUT_TXT} ..."
echo "${CURR_PWD}/zowe.pax" > "${INPUT_TXT}"
echo "${CURR_PWD}/smpe.pax" >> "${INPUT_TXT}"
echo "[$SCRIPT_NAME] content of ${INPUT_TXT}:"
cat "${INPUT_TXT}"
mkdir -p zowe

# generate random MLQ (must begin with letter, @, #, or $, max 8 char)
RANDOM_MLQ=ZWE$RANDOM  # RANDOM gives a random number between 0 & 32767

# set temp dir (specific value for packaging on Marist server)
TMPDIR=/ZOWE/tmp

# ZOWEAD3 & ZOWE02 are specific values for packaging on Marist server.
# To package on another server, we may need different settings.
# Or if the server is configured properly, we may just remove -V option.
#% required
#% -h hlq        use the specified high level qualifier
#% -i inputFile  reference file listing non-SMPE distribution files
#% -r rootDir    use the specified root directory
#% -v vrm        FMID 3-character version/release/modification
#% optional
#% -a alter.sh   execute script before/after install to alter setup
#% -d            enable debug messages
#% -V volume     allocate data sets on specified volume(s)

./smpe/bld/smpe.sh \
  -V "ZOWE02" \
  -a ./smpe/bld/alter.sh \
  -d \
  -i "${CURR_PWD}/${INPUT_TXT}" \
  -h "ZOWEAD3.${RANDOM_MLQ}" \
  -r "${CURR_PWD}/zowe" \
  -v ${FMID_VERSION}

# remove data sets
# TODO keep if "keep output" is selected in Jenkins
datasets=$(./smpe/bld/get-dsn.rex "ZOWEAD3.${RANDOM_MLQ}.**")
# returns 0 for match, 1 for no match, 8 for error
if test $? -gt 1
then
  echo "$datasets"                       # variable holds error message
  # exit 1
fi    #
# delete data sets
for dsn in $datasets
do
  tsocmd "DELETE '$dsn'"
done    # for dsn

# remove tmp folder
UC_CURR_PWD=$(echo "${CURR_PWD}" | tr [a-z] [A-Z])
if [ "${UC_CURR_PWD}" != "${CURR_PWD}" ]; then
  # CURR_PWD will be removed after build automatically, we just need to delete
  # the extra temp folder in uppercase created by GIMZIP
  rm -fr "${UC_CURR_PWD}"
fi

# get the final build result
ZOWE_SMPE_PAX="AZWE${FMID_VERSION}/gimzip/AZWE${FMID_VERSION}.pax.Z"
if [ ! -f "${CURR_PWD}/zowe/${ZOWE_SMPE_PAX}" ]; then
  echo "[$SCRIPT_NAME][ERROR] cannot find build result ${ZOWE_SMPE_PAX}"
  exit 1
fi
ZOWE_SMPE_README="AZWE${FMID_VERSION}/gimzip/AZWE${FMID_VERSION}.readme.txt"
if [ ! -f "${CURR_PWD}/zowe/${ZOWE_SMPE_README}" ]; then
  echo "[$SCRIPT_NAME][ERROR] cannot find build result ${ZOWE_SMPE_README}"
  exit 1
fi

cd "${CURR_PWD}"
mv "zowe/${ZOWE_SMPE_PAX}" "zowe-smpe.pax"
mv "zowe/${ZOWE_SMPE_README}" "readme.txt"

# check what's in logs
cd "zowe/AZWE${FMID_VERSION}/logs"
pax -w -f "${CURR_PWD}/smpe-build-logs.pax.Z" *

# prepare rename to original name
cd "${CURR_PWD}"
echo "mv zowe-smpe.pax AZWE${FMID_VERSION}.pax.Z" > "rename-back.sh.1047"
echo "mv readme.txt AZWE${FMID_VERSION}.readme.txt" >> "rename-back.sh.1047"
iconv -f IBM-1047 -t ISO8859-1 rename-back.sh.1047 > rename-back.sh
