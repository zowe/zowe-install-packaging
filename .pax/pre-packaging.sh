#!/bin/sh -e
set -x

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018, 2019
################################################################################

SCRIPT_NAME=$(basename "$0")

if [ -z "$ZOWE_VERSION" ]; then
  echo "$SCRIPT_NAME ZOWE_VERSION environment variable is missing"
  exit 1
else
  echo "$SCRIPT_NAME working on Zowe v${ZOWE_VERSION} ..."
fi

# Create mediation PAX
cd mediation
pax -x os390 -w -f ../content/zowe-$ZOWE_VERSION/files/api-mediation-package-0.8.4.pax *
cd ..

# Cleanup working files
rm -rf mediation

echo "$SCRIPT_NAME change scripts to be executable ..."
chmod +x content/zowe-$ZOWE_VERSION/bin/*.sh
chmod +x content/zowe-$ZOWE_VERSION/scripts/*.sh
chmod +x content/zowe-$ZOWE_VERSION/scripts/opercmd
chmod +x content/zowe-$ZOWE_VERSION/scripts/ocopyshr.clist
chmod +x content/zowe-$ZOWE_VERSION/install/*.sh
chmod +x content/templates/vtl/build-workflow.rex

# prepare for SMPE
echo "$SCRIPT_NAME smpe is not part of zowe.pax, moving out ..."
mv content/smpe .

# prepare for workflows

# move create JCL and VTL functionality here
#  Output for JCL and Workflows chmod +x content/zowe-$ZOWE_VERSION/ plus correct dir

# generate boilerplate SECURITY JCL
JCL_PATH="content/zowe-$ZOWE_VERSION/files/jcl"        # output
LOCAL_PATH="content/templates/vtl/ZWESECUR"   # input
VTLCLI_PATH="/ZOWE/vtl-cli"       # tool
for entry in $(ls ${LOCAL_PATH}/)
do
  if [ "${entry##*.}" = "vtl" ]          # keep from last . (exclusive)
  then
    BASE=${entry%.*}                    # keep up to last . (exclusive)
    VTL="${LOCAL_PATH}/${entry}"
    YAML="${LOCAL_PATH}/${BASE}.yml"
    JCL="${JCL_PATH}/${BASE}.jcl"
    # assumes java is in $PATH
    java -jar ${VTLCLI_PATH}/vtl-cli.jar -ie Cp1140 --yaml-context ${YAML} ${VTL} -o ${JCL} -oe Cp1140
  fi
done

# # generate SECURITY workflow
ls "content/templates/vtl/ZWESECUR"
WORKFLOW_PATH="content/zowe-$ZOWE_VERSION/files/workflows"       # output
LOCAL_PATH="content/templates/vtl/ZWESECUR"   # input
SECURWF_TEMPLATE="ZWEWRF02.xml"
> "${WORKFLOW_PATH}/ZOWE_SECURITY_VIF.yml"
> "${WORKFLOW_PATH}/ZOWE_SECURITY_WORKFLOW.xml"
cp ${LOCAL_PATH}/ZWEWRF02.yml ${WORKFLOW_PATH}/ZOWE_SECURITY_VIF.yml
cd "content/templates/vtl/ZWESECUR"
ls
../build-workflow.rex -d -i "../${SECURWF_TEMPLATE}" -o ../../../zowe-$ZOWE_VERSION/files/workflows/ZOWE_SECURITY_WORKFLOW.xml
cd ../../../../

mv content/templates .
