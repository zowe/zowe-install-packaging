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
# In an earlier step, the build pipeline sent all data to z/OS and
# ensured all text files were converted to EBCDIC. Most data resides
# in ./content/.
#
# This script does last-minute tweaks to the data to be packaged,
# ensuring that ./content/ only holds data that must go in zowe.pax.
# It ends by installing Zowe and create a fingerprint for the runtime
# directory. The post-packaging.sh script is responsible for cleanup.
#
# The next step in the build pipeline will
# 1. create zowe.pax
# 2. call .pax/post-packaging.sh
#
#######################################################################
set -x

# the following directories ($ROOT_DIR/*) are used as input:
# ./content/smpe/
# ./content/templates/
# ./content/zowe-${ZOWE_VERSION}/
# ./mediation/
# Note: ./content/zowe-*/ also holds data prepare-workspace.sh placed 
#       in ascii/zowe-*

# ---------------------------------------------------------------------
# --- create JCL files
# $1: (input) location of .vtl & .properties files
# $2: (input) base name of .vtl & .properties files, if directory then
#     process all files within, otherwise only the referenced file
# JCL_PATH: (output) location of customized jcl
# ---------------------------------------------------------------------
function _createJCL
{
# note: using precompiled version of vtl-cli store on z/OS host 
# source in https://github.com/plavjanik/vtl-cli
VTLCLI_PATH="/ZOWE/vtl-cli"        # tools, path must be absolute

if [ -f "$1/$2.vtl" ]; then
  vtlList="$2.vtl"                             # process just this file
  vtlPath="$1"
elif [ -d "$1/$2" ]; then
  vtlList="$(ls $1/$2/)"           # process all if directory passed in
  vtlPath="$1/${2:-.}"
else
  echo "[$SCRIPT_NAME] $1/$2.vtl not found"
  exit 1                                                         # EXIT
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
      exit 1                                                     # EXIT
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
# note: prepare-workspace.sh placed the workflow tools here  
CREAXML_PATH="${ROOT_DIR}/templates"     # tools, path must be absolute

if [ -f "$1/$2.xml" ]; then
  xmlList="$2.xml"                             # process just this file
  xmlPath="$1"
elif [ -d "$1/$2" ]; then
  xmlList="$(ls $1/$2/)"           # process all if directory passed in
  xmlPath="$1/${2:-.}"
else
  echo "[$SCRIPT_NAME] $1/$2.xml not found"
  exit 1                                                         # EXIT
fi

for xmlEntry in $xmlList
do
  if [ "${xmlEntry##*.}" = "xml" ]       # keep from last . (exclusive)
  then
    xmlBase="${xmlEntry%.*}"            # keep up to last . (exclusive)
    XML="${ROOT_DIR}/${WORKFLOW_PATH}/${xmlBase}.xml" # use absolute path

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
      exit 1                                                     # EXIT
    fi
    cp "${YAML}" "${WORKFLOW_PATH}/${xmlBase}.properties"
  fi    # xml found
done
}    # _createWorkflow

# ---------------------------------------------------------------------
# --- create fingerprint of Zowe's runtime directory files
# ---------------------------------------------------------------------
function _createFingerprint
{
# Here we create the fingerprint embedded in the zowe.pax file.
# To do this, we will create a runtime directory, and install Zowe. 
# Next we calculate and save the fingerprint of the installed USS files.

# keep in ${ROOT_DIR} so pipeline variable $KEEP_TEMP_FOLDER applies
INST_SOURCE=${ROOT_DIR}/content/zowe-${ZOWE_VERSION}
INST_TARGET=${ROOT_DIR}/zowe-runtime
INST_WORK=${ROOT_DIR}/zowe-work   # keep in sync with post-packaging.sh
INST_PASS=${INST_WORK}/zowe-install.txt   # sync with post-packaging.sh
mkdir -p ${INST_TARGET} ${INST_WORK}

userid=${USER:-${USERNAME:-${LOGNAME}}}
mlq=T$(($$ % 10000000))                 # the lower 7 digits of the PID
INST_HLQ=${userid}.${mlq}

echo "[$SCRIPT_NAME] install Zowe in temporary runtime directory"
# Note: 
# - SMP/E build will reuse this install in post-packaging.sh, 
#   cleanup is done by catchall-packaging.sh
# - do not create ${INST_PASS} when SMP/E build must use  "-a alter.sh"
#   to tweak the Zowe install before packaging

# install Zowe
${INST_SOURCE}/install/zowe-install.sh \
  -h ${INST_HLQ} \
  -i ${INST_TARGET} \
  -l ${INST_WORK}
echo "[$SCRIPT_NAME] install RC=$?" # TODO I've seen this script continue
# after install had RC 1, and "#!/bin/sh -e" was in effect

inst_log="$(ls ${INST_WORK}/zowe-install-*.log)"
echo "[$SCRIPT_NAME] show install log"
cat $inst_log

# save info to pass to post-packaging.sh
touch ${INST_PASS}
echo "inst_hlq=${INST_HLQ}"     >> ${INST_PASS} # sync with post-packaging.sh
echo "inst_root=${INST_TARGET}" >> ${INST_PASS} # sync with post-packaging.sh
echo "inst_log=$inst_log"       >> ${INST_PASS} # sync with post-packaging.sh

echo "[$SCRIPT_NAME] generate reference hash keys of runtime files"

# copy tools
cp ${INST_SOURCE}/files/HashFiles.java ${INST_WORK}/

# compile the hash program and calculate the checksums of runtime
${INST_SOURCE}/bin/zowe-generate-checksum.sh \
  ${INST_TARGET} \
  ${INST_WORK}

# save derived runtime hash file and class into the source tree that will be PAXed
mkdir -p ${INST_SOURCE}/fingerprint
cp ${INST_WORK}/RefRuntimeHash.txt \
   ${INST_SOURCE}/fingerprint/RefRuntimeHash-${ZOWE_VERSION}.txt
cp ${INST_WORK}/HashFiles.class \
   ${INST_SOURCE}/bin/internal/

# save derived runtime hash file and class into the runtime dir for inclusion by SMP/E build
mkdir -p ${INST_TARGET}/fingerprint
cp ${INST_WORK}/RefRuntimeHash.txt \
   ${INST_TARGET}/fingerprint/RefRuntimeHash-${ZOWE_VERSION}.txt
cp ${INST_WORK}/HashFiles.class \
   ${INST_TARGET}/bin/internal/

echo "[$SCRIPT_NAME] cleanup after generating Hash keys done in catchall-packaging.sh"
}    # _createFingerprint

# ---------------------------------------------------------------------
# --- main --- main --- main --- main --- main --- main --- main ---
# ---------------------------------------------------------------------
# $0=./pre-packaging.sh
SCRIPT_NAME=$(basename "$0")  
BASE_DIR=$(dirname "$0")      # <something>
cd $BASE_DIR
ROOT_DIR=$(pwd)               # <something>

if [ -z "$ZOWE_VERSION" ]; then
  echo "[$SCRIPT_NAME] ZOWE_VERSION environment variable is missing"
  exit 1
else
  echo "[$SCRIPT_NAME] working on Zowe v${ZOWE_VERSION} ..."
fi

# show what's already present
echo "[${SCRIPT_NAME}] content \$ROOT_DIR: find ."
find . || true

# create mediation PAX
echo "[$SCRIPT_NAME] create mediation pax"
cd ./mediation
MEDIATION_PATH=$ROOT_DIR/content/zowe-$ZOWE_VERSION/files
# TODO do we really want to use a fixed package VRM?
pax -x os390 -w -f ${MEDIATION_PATH}/api-mediation-package-0.8.4.pax *
cd $ROOT_DIR
# clean up working files
rm -rf ./mediation

# TODO correct upstream
# fix wrong name for File Explorer API: data-sets-api-server-*.jar -> files-api-server-*.jar
echo "[$SCRIPT_NAME] correct File Explorer API jar name"
cd ./content/zowe-$ZOWE_VERSION/files
jar=$(ls -t data-sets-api-server-*.jar 2>/dev/null | head -1)
if [ -f "$jar" ]; then 
  mv ${jar} files${jar#data-sets} 
fi  
cd $ROOT_DIR

echo "[$SCRIPT_NAME] change scripts to be executable ..."
chmod +x ./content/zowe-$ZOWE_VERSION/bin/*.sh
chmod +x ./content/zowe-$ZOWE_VERSION/scripts/*.sh
chmod +x ./content/zowe-$ZOWE_VERSION/scripts/opercmd
chmod +x ./content/zowe-$ZOWE_VERSION/scripts/ocopyshr.clist
chmod +x ./content/zowe-$ZOWE_VERSION/install/*.sh
chmod +x ./content/templates/*.rex

# prepare for SMPE
echo "[$SCRIPT_NAME] smpe is not part of zowe.pax, moving it out ..."
mv ./content/smpe  .

# workflow customization
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

# end of workflow customization

# MUST BE LAST - create fingerprint of Zowe's runtime directory files
_createFingerprint

echo "[$SCRIPT_NAME] done"
