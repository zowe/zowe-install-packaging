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
# set -x

# expected workspace layout:
# ./content/smpe/
# ./content/templates/
# ./content/

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

# use node v16 to build
export NODE_HOME=/ZOWE/node/node-v16.20.1-os390-s390x

ZOWE_ROOT_DIR="${BASE_DIR}/content"

cd "${BASE_DIR}"
# Done with build, remove build folder
rm -rf "${ZOWE_ROOT_DIR}/build"

ZOWE_VERSION=$(cat ${ZOWE_ROOT_DIR}/manifest.json | grep version | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')
# add zwe command to PATH
export PATH=${ZOWE_ROOT_DIR}/bin:${PATH}

if [ -z "$ZOWE_VERSION" ]; then
  echo "[$SCRIPT_NAME] Error: failed to extract version from manifest.json"
  exit 1
else
  echo "[$SCRIPT_NAME] working on Zowe v${ZOWE_VERSION} ..."
fi

# show what's already present
# echo "[$SCRIPT_NAME] content current directory: ls -A $(pwd)/"
# ls -A "$(pwd)/" || true
# should have content of
# - catchall-packaging.sh
# - content
# - post-packaging.sh
# - pre-packaging.sh
# - prepare-workspace.sh
# FIXME: remove/comment this debug code
# cd "${BASE_DIR}" && rm -fr content && rm -fr smpe && rm -fr templates && cp -r content.bak content

echo "[$SCRIPT_NAME] change scripts to be executable ..."
chmod +x "${ZOWE_ROOT_DIR}"/bin/zwe
chmod +x "${ZOWE_ROOT_DIR}"/bin/utils/*.sh
chmod +x "${ZOWE_ROOT_DIR}"/bin/utils/*.rex

echo "[$SCRIPT_NAME] change keyring-util to be executable ..."
chmod +x "${ZOWE_ROOT_DIR}"/bin/utils/keyring-util/keyring-util

echo "[$SCRIPT_NAME] extract zowe-ncert ..."
cd "${ZOWE_ROOT_DIR}/bin/utils"
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
chmod +x templates/*.rex


mkdir -p "${ZOWE_ROOT_DIR}/bin/utils"
configmgr=$(find "${ZOWE_ROOT_DIR}/files" -type f \( -name "configmgr-2*.pax" \) | head -n 1)
echo "[$SCRIPT_NAME] extract configmgr $configmgr"
cd "${ZOWE_ROOT_DIR}/bin/utils"
pax -ppx -rf "${configmgr}"
rm "${configmgr}"
cd "${BASE_DIR}"

configmgr_rexx=$(find "${ZOWE_ROOT_DIR}/files" -type f \( -name "configmgr-rexx*.pax" \) | head -n 1)
echo "[$SCRIPT_NAME] extract configmgr_rexx $configmgr_rexx"
mkdir -p "${ZOWE_ROOT_DIR}/files/SZWELOAD"
cd "${ZOWE_ROOT_DIR}/files/SZWELOAD"
pax -ppx -rf "${configmgr_rexx}"
rm "${configmgr_rexx}"
cd "${BASE_DIR}"


echo "[$SCRIPT_NAME] create dummy zowe.yaml for install"
cat <<EOT >> "${BASE_DIR}/zowe.yaml"
zowe:
  extensionDirectory: "${ZOWE_ROOT_DIR}/components"
  useConfigmgr: false
EOT

echo "[$SCRIPT_NAME] extract components"
mkdir -p "${BASE_DIR}/logs"
mkdir -p "${ZOWE_ROOT_DIR}/components"
for component in launcher zlux-core zss apiml-common-lib common-java-lib apiml-sample-extension gateway cloud-gateway caching-service metrics-service discovery api-catalog jobs-api files-api explorer-jes explorer-mvs explorer-uss; do
  echo "[$SCRIPT_NAME] - ${component}"
  component_file=$(find "${ZOWE_ROOT_DIR}/files" -type f \( -name "${component}*.pax" -o -name "${component}*.zip" \) | head -n 1)
  "${ZOWE_ROOT_DIR}/bin/zwe" \
    components install extract \
    --component-file "${component_file}" \
    --config "${BASE_DIR}/zowe.yaml" \
    --trace \
    --log-dir "${BASE_DIR}/logs"
  rm "${component_file}"
done

echo "[$SCRIPT_NAME] process commands.install hooks"
# not all core components has commands.install
for component in app-server; do
  echo "[$SCRIPT_NAME] - ${component}"
  # FIXME: these environment variables are changed in v2
  ZOWE_ROOT_DIR=${ZOWE_ROOT_DIR} \
  ZWED_INSTALL_DIR=${ZOWE_ROOT_DIR} \
  LOG_FILE="${BASE_DIR}/logs/zwe-components-install-process-hook.log" \
  "${ZOWE_ROOT_DIR}/bin/zwe" \
    components install process-hook \
    --component-name "${component}" \
    --config "${BASE_DIR}/zowe.yaml" \
    --trace \
    --log-dir "${BASE_DIR}/logs"
done

# >>>>>
# this is handled by app-server commands.install hook
# echo "[$SCRIPT_NAME] extract pre-bundled zlux plugins"
# # should have components
# if [ ! -d "${ZOWE_ROOT_DIR}/components/app-server/share" ]; then
#   echo "[$SCRIPT_NAME] Error: app-server directory is not created."
#   exit 1
# fi
# cd "${ZOWE_ROOT_DIR}/components/app-server/share"
# for component in explorer-ip sample-angular-app sample-iframe-app sample-react-app tn3270-ng2 vt-ng2 zlux-editor ; do
#   echo "[$SCRIPT_NAME] - ${component}"
#   mkdir "${ZOWE_ROOT_DIR}/components/app-server/share/${component}"
#   cd "${ZOWE_ROOT_DIR}/components/app-server/share/${component}"
#   pax -ppx -rf "${ZOWE_ROOT_DIR}/files/zlux/"${component}*.pax
#   rm "${ZOWE_ROOT_DIR}/files/zlux/"${component}*.pax
# done
# we don't have tar format plugins now, otherwise we should also use tar to extract

# echo "[$SCRIPT_NAME] move pre-bundled zlux configs"
# cd "${ZOWE_ROOT_DIR}/components/app-server/share"
# chtag -tc 1047 ${ZOWE_ROOT_DIR}/files/zlux/config/*.json
# chtag -tc 1047 ${ZOWE_ROOT_DIR}/files/zlux/config/plugins/*.json
# chmod -R u+w zlux-app-server 2>/dev/null
# mkdir -p zlux-app-server/defaults/ZLUX/pluginStorage/org.zowe.zlux.ng2desktop/ui/launchbar/plugins
# cp -f ${ZOWE_ROOT_DIR}/files/zlux/config/pinnedPlugins.json zlux-app-server/defaults/ZLUX/pluginStorage/org.zowe.zlux.ng2desktop/ui/launchbar/plugins/
# mkdir -p zlux-app-server/defaults/ZLUX/pluginStorage/org.zowe.zlux.bootstrap/plugins
# cp -f ${ZOWE_ROOT_DIR}/files/zlux/config/allowedPlugins.json zlux-app-server/defaults/ZLUX/pluginStorage/org.zowe.zlux.bootstrap/plugins/
# cp -f ${ZOWE_ROOT_DIR}/files/zlux/config/zluxserver.json zlux-app-server/defaults/serverConfig/server.json
# cp -f ${ZOWE_ROOT_DIR}/files/zlux/config/plugins/* zlux-app-server/defaults/plugins

cd "${BASE_DIR}"
echo "[$SCRIPT_NAME] after installed, files directory:"
find "${ZOWE_ROOT_DIR}/files" -type f
rm -fr ${ZOWE_ROOT_DIR}/files/zlux

#1. create SMP/E workflow & JCL
echo "[$SCRIPT_NAME] create SMP/E workflow & JCL"
cd "${BASE_DIR}"
WORKFLOW_PATH="./smpe/pax/USS"
JCL_PATH="./smpe/pax/MVS"
_createWorkflow "./templates" "smpe-install"
# adjust names as these files will be known by SMP/E
mv -f "$WORKFLOW_PATH/smpe-install.xml" "$WORKFLOW_PATH/ZWEWRF01.xml"
mv -f "$WORKFLOW_PATH/smpe-install.properties" "$WORKFLOW_PATH/ZWEYML01.yml"

#2. create all other workflow & JCL, must be last in workflow creation
echo "[$SCRIPT_NAME] create all other workflow & JCL, must be last in workflow creation"
cd "${BASE_DIR}"
WORKFLOW_PATH="./content/files/workflows"
JCL_PATH="./content/files/SZWESAMP"
_createWorkflow "./templates"
if [ -f "${ZOWE_ROOT_DIR}/files/SZWESAMP/ZWESECUR.jcl" ]; then
  mv "${ZOWE_ROOT_DIR}/files/SZWESAMP/ZWESECUR.jcl" "${ZOWE_ROOT_DIR}/files/SZWESAMP/ZWESECUR"
else
  echo "[$SCRIPT_NAME] Error: failed to generate ZWESECUR"
  exit 1
fi

#3. clean up working files
echo "[$SCRIPT_NAME] clean up working files"
rm -rf "./templates"

echo "[$SCRIPT_NAME] compile java utilities ..."
cd "${ZOWE_ROOT_DIR}/bin/utils"
javac HashFiles.java && rm HashFiles.java
javac ExportPrivateKeyLinux.java && rm ExportPrivateKeyLinux.java
javac ExportPrivateKeyZos.java && rm ExportPrivateKeyZos.java

echo "[$SCRIPT_NAME] generate fingerprints"
mkdir -p "${BASE_DIR}/fingerprints"
mkdir -p "${ZOWE_ROOT_DIR}/fingerprint"
cd "${ZOWE_ROOT_DIR}"
find . -name ./SMPE             -prune \
    -o -name "./ZWE*"           -prune \
    -o -name ./fingerprint      -prune \
    -o -type f -print > "${BASE_DIR}/fingerprints/files.in"
java -cp "${ZOWE_ROOT_DIR}/bin/utils" HashFiles "${BASE_DIR}/fingerprints/files.in" | sort > "${ZOWE_ROOT_DIR}/fingerprint/RefRuntimeHash-${ZOWE_VERSION}.txt"
echo "[$SCRIPT_NAME] cleanup fingerprints code"
rm -fr "${BASE_DIR}/fingerprints"

echo "[$SCRIPT_NAME] done"
