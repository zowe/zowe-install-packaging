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

# create smpe.pax
cd smpe/pax
pax -x os390 -w -f ../../smpe.pax *
cd ../..

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

# ZOWEAD3 and ZOWE02 is specific parameter for packaging on Marist server.
# To package on another server, we may need different settings.
# Or if the server is configured properly, may just remove -V option.
#% required
#% -h hlq        use the specified high level qualifier
#% -i inputFile  reference file listing non-SMPE distribution files
#% -r rootDir    use the specified root directory
#% -v vrm        FMID 3-character version/release/modification
#% optional
#% -d            enable debug messages
#% -V volume     allocate data sets on specified volume(s)
./smpe/bld/smpe.sh \
  -i "${CURR_PWD}/${INPUT_TXT}" \
  -h "ZOWEAD3" \
  -V "ZOWE02" \
  -v ${FMID_VERSION} \
  -r "${CURR_PWD}/zowe" \
  -d

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

# prepare rename to original name
echo "mv zowe-smpe.pax AZWE${FMID_VERSION}.pax.Z" > "rename-back.sh.1047"
echo "mv readme.txt AZWE${FMID_VERSION}.readme.txt" >> "rename-back.sh.1047"
iconv -f IBM-1047 -t ISO8859-1 rename-back.sh.1047 > rename-back.sh
