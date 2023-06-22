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
# Copyright Contributors to the Zowe Project. 2018, 2020
#######################################################################

#######################################################################
# Build script
#
# runs on z/OS, before creating zowe.pax
#
#######################################################################
set -x

# expected workspace layout:
# ./content/smpe/
# ./content/templates/
# ./content/zowe-${ZOWE_VERSION}/

# use node v14 to build
export NODE_HOME=/ZOWE/node/node-v14.21.3-os390-s390x

# ---------------------------------------------------------------------
# --- create JCL files
# $1: (input) location of .vtl & .properties files
# $2: (input) base name of .vtl & .properties files, if directory then
#     process all files within, otherwise only the referenced file
# JCL_PATH: (output) location of customized jcl
# ---------------------------------------------------------------------
function _createJCL
{
VTLCLI_PATH="/ZOWE/vtl-cli"        # tools, path must be absolute
# vtl-cli source: https://github.com/plavjanik/vtl-cli

if [ -f "$1/$2.vtl" ]; then
  vtlList="$2.vtl"                             # process just this file
  vtlPath="$1"
elif [ -d "$1/$2" ]; then
  vtlList="$(ls $1/$2/)"           # process all if directory passed in
  vtlPath="$1/${2:-.}"
else
  echo "[$SCRIPT_NAME] $1/$2.vtl not found"
  exit 1
fi

for vtlEntry in $vtlList
do
  if [ "${vtlEntry##*.}" = "vtl" ]       # keep from last . (exclusive)
  then
    vtlBase="${vtlEntry%.*}"            # keep up to last . (exclusive)
    JCL="${JCL_PATH}/${vtlBase}.jcl"
    VTL="${vtlPath}/${vtlEntry}"
    if [ -f ${vtlPath}/${vtlBase}.properties ]; then
      YAML="${vtlPath}/${vtlBase}.properties"
#    elif [ -f ${vtlPath}/${vtlBase}.yaml ]; then
#      YAML="${vtlPath}/${vtlBase}.yaml"
#    elif [ -f ${vtlPath}/${vtlBase}.yml ]; then
#      YAML="${vtlPath}/${vtlBase}.yml"
    else
      echo "[$SCRIPT_NAME] ${vtlPath}/${vtlBase}.properties not found"
      exit 1
    fi

    echo "[$SCRIPT_NAME] creating $JCL"

    # TODO match variables used in .vtl and .properties

    # assumes java is in $PATH
    java -jar ${VTLCLI_PATH}/vtl-cli.jar \
      -ie Cp1140 --yaml-context ${YAML} ${VTL} -o ${JCL} -oe Cp1140
  fi    # vtl found
done
}    # _createJCL

# ---------------------------------------------------------------------
# --- create workflow & JCL files
# $1: (input) location of .xml files
# $2: (input) base name of .xml files, if directory then
#     process all files within, otherwise only the referenced file
# WORKFLOW_PATH: (output) location of customized workflow
# JCL_PATH: (output) location of customized jcl
# ---------------------------------------------------------------------
function _createWorkflow
{
here=$(pwd)
CREAXML_PATH="${here}/templates"   # tools, path must be absolute

if [ -f "$1/$2.xml" ]; then
  xmlList="$2.xml"                             # process just this file
  xmlPath="$1"
elif [ -d "$1/$2" ]; then
  xmlList="$(ls $1/$2/)"           # process all if directory passed in
  xmlPath="$1/${2:-.}"
else
  echo "[$SCRIPT_NAME] $1/$2.xml not found"
  exit 1
fi

for xmlEntry in $xmlList
do
  if [ "${xmlEntry##*.}" = "xml" ]       # keep from last . (exclusive)
  then
    xmlBase="${xmlEntry%.*}"            # keep up to last . (exclusive)
    XML="${here}/${WORKFLOW_PATH}/${xmlBase}.xml"   # use absolute path

    if [ -d ${xmlBase} ]; then
      # TODO ensure workflow yaml has all variables of JCL yamls
    fi
    
    # create JCL related to this workflow
    _createJCL ${xmlPath} ${xmlBase}    # ${xmlBase} can be a directory

    # create workflow
    echo "[$SCRIPT_NAME] creating $XML"
    # inlineTemplate definition in xml expects us to be in $xmlPath
    cd "${xmlPath}"
    ${CREAXML_PATH}/build-workflow.rex -d -i ${xmlEntry} -o ${XML}
    rm -f ${xmlEntry}                # remove to avoid processing twice
    cd -                                 # return to previous directory

    # copy default variable definitions to ${WORKFLOW_PATH}
    if [ -f ${xmlPath}/${xmlBase}.properties ]; then
      YAML="${xmlPath}/${xmlBase}.properties"
#    elif [ -f ${xmlPath}/${xmlBase}.yaml ]; then
#      YAML="${xmlPath}/${xmlBase}.yaml"
#    elif [ -f ${xmlPath}/${xmlBase}.yml ]; then
#      YAML="${xmlPath}/${xmlBase}.yml"
    else
      echo "[$SCRIPT_NAME] ${xmlPath}/${xmlBase}.properties not found"
      exit 1
    fi
    cp "${YAML}" "${WORKFLOW_PATH}/${xmlBase}.properties"
  fi    # xml found
done
}    # _createWorkflow

# ---------------------------------------------------------------------
# --- main --- main --- main --- main --- main --- main --- main ---
# ---------------------------------------------------------------------
SCRIPT_NAME=$(basename "$0")  # $0=./pre-packaging.sh
BASE_DIR=$(cd $(dirname "$0"); pwd)      # <something>/.pax

if [ -z "$ZOWE_VERSION" ]; then
  echo "[$SCRIPT_NAME] ZOWE_VERSION environment variable is missing"
  exit 1
else
  echo "[$SCRIPT_NAME] working on Zowe v${ZOWE_VERSION} ..."
fi

# show what's already present
echo "[$SCRIPT_NAME] content current directory: ls -A $(pwd)/"
ls -A "$(pwd)/" || true

echo "[$SCRIPT_NAME] change scripts to be executable ..."
chmod +x content/zowe-$ZOWE_VERSION/bin/*.sh
chmod +x content/zowe-$ZOWE_VERSION/scripts/*.sh
chmod +x content/zowe-$ZOWE_VERSION/scripts/opercmd
chmod +x content/zowe-$ZOWE_VERSION/scripts/ocopyshr.clist
chmod +x content/zowe-$ZOWE_VERSION/install/*.sh
chmod +x content/templates/*.rex

echo "[$SCRIPT_NAME] change keyring-util to be executable ..."
chmod +x content/zowe-$ZOWE_VERSION/bin/utils/keyring-util/keyring-util

echo "[$SCRIPT_NAME] extract zowe-ncert ..."
cd content/zowe-$ZOWE_VERSION/bin/utils
mkdir -p ncert
cd ncert
pax -ppx -rf ../zowe-ncert-*.pax
rm -f ../zowe-ncert-*.pax
cd "${BASE_DIR}"

# prepare for SMPE
echo "[$SCRIPT_NAME] smpe is not part of zowe.pax, moving it out ..."
mv ./content/smpe  .

# workflow customization
# >>>
echo "[$SCRIPT_NAME] templates is not part of zowe.pax, moving it out ..."
mv ./content/templates  .

#1. create SMP/E workflow & JCL
WORKFLOW_PATH="./smpe/pax/USS"
JCL_PATH="./smpe/pax/MVS"
_createWorkflow "./templates" "smpe-install"
# adjust names as these files will be known by SMP/E
mv -f "$WORKFLOW_PATH/smpe-install.xml" "$WORKFLOW_PATH/ZWEWRF01.xml"
mv -f "$WORKFLOW_PATH/smpe-install.properties" "$WORKFLOW_PATH/ZWEYML01.yml"

#2. create all other workflow & JCL, must be last in workflow creation
WORKFLOW_PATH="./content/zowe-$ZOWE_VERSION/files/workflows"
JCL_PATH="./content/zowe-$ZOWE_VERSION/files/jcl"
_createWorkflow "./templates"

#3. clean up working files
rm -rf "./templates"

# <<<

# # . . . . . . . . . . . start of fingerprint . . . . . . . . . . . . . . . . . . . . . . .

# This is the script where we create the fingerprint in the zowe.pax file.
# To do this, we will create a runtime directory, somewhat like smpe.sh does today,
# by running zowe-install.sh

# For the moment, I will let smpe.sh continue to create its own runtime folder, but this creation
# will be removed later for efficiency.

# Note that zowe-install.sh creates USS files ... but also datasets, which need to be deleted.
# TODO
# To delete them, amend catchall-packaging.sh in this directory.

# # Generate reference hash keys of runtime files
echo "----- Generate reference hash keys of runtime files -----"
echo Installing Zowe in temporary runtime directory
mkdir zowe-runtime-dir 
userid=${USER:-${USERNAME:-${LOGNAME}}}
tempDSNlevel=T$(($$ % 10000000)) # the lower 7 digits of the PID
./content/zowe-$ZOWE_VERSION/install/zowe-install.sh -i zowe-runtime-dir -l logs -h $userid.$tempDSNlevel # temp DSN based on PID
find logs -name "zowe-install-*.log" -type f | xargs -i sh -c 'echo ">>>>>>>>>>>>>>>>>>>>>>>> {} >>>>>>>>>>>>>>>>>>>>>>>" && cat {} && echo "<<<<<<<<<<<<<<<<<<<<<<<< {} <<<<<<<<<<<<<<<<<<<<<<<"'
for szweDSN in SZWESAMP SZWEAUTH # delete temp DSNs 
do
  tsocmd delete $tempDSNlevel.$szweDSN # 1> /dev/null 2> /dev/null
done
utilsDir=`pwd`/content/zowe-$ZOWE_VERSION/scripts/utils 
mkdir $utilsDir/hash # create work directory
cp content/zowe-$ZOWE_VERSION/files/HashFiles.java $utilsDir/hash

# Compile the hash program and calculate the checksums of runtime
./content/zowe-$ZOWE_VERSION/bin/zowe-generate-checksum.sh `pwd`/zowe-runtime-dir $utilsDir/hash 

# save derived runtime hash file and class into the source tree that will be PAXed
mkdir -p content/zowe-$ZOWE_VERSION/fingerprint
cp   $utilsDir/hash/RefRuntimeHash.txt content/zowe-$ZOWE_VERSION/fingerprint/RefRuntimeHash-$ZOWE_VERSION.txt 
cp   $utilsDir/hash/HashFiles.class    content/zowe-$ZOWE_VERSION/bin/internal

rm -r $utilsDir/hash # delete work directory
rm -r zowe-runtime-dir # delete runtime directory.  TODO: Don't do this when smpe.sh does not create its own.  

echo "----- Hash keys of runtime files were generated -----"
# # . . . . . . . . . . end of fingerprint . . . . . . . . . . . . . . . . . . . . . . . . .

echo "[$SCRIPT_NAME] done"
