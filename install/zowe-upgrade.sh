#!/bin/sh
set -e
err_report() {
printf "Installation ended with error\nSee log file for more details: ${LOG_FILE} \nreverting update from backup:\n 1. rm -rf ${TARGET_DIR}\n 2. mkdir ${TARGET_DIR}\n 3. cd ${TARGET_DIR}\n 4. pax -ppx -rf ${BACKUP_FILE} \n 5. cp ${TARGET_DIR}/install_log/ZWESIS01 //'${LOADLIB}(ZWESIS01)'\n"
}
trap 'err_report $LINENO' ERR
if [ $# -ne 4 ]
then
echo "Please provide path to your Zowe-1.2.0 installation directory as a first parameter, path to directory with unpaxed Zowe-1.2.0, LOADLIB module dataset name as third parameter and path to backup directory as fourth. " 
echo "Example: ./zowe-upgrade.sh /u/usr/zowe/1.2.0 /u/usr/zowe/builds/zowe-1.3.0 USR.ZOWE.LOADLIB /u/usr/zowe/backup"
exit 1
fi

if [[ $1 = /* ]]
then
export TARGET_DIR="$1"
else
export TARGET_DIR=$(pwd)/$1
fi

if [[ $2 = /* ]]
then
export SRC_DIR="$2"
else
export SRC_DIR=$(pwd)/$2
fi

if [[ $4 = /* ]]
then
export BACKUP_DIR="$4"
else
export BACKUP_DIR=$(pwd)/$4
fi

export LOADLIB="$3"
export _EDC_ADD_ERRNO2=1

# Make the log file
export LOG_DIR=${TARGET_DIR}/install_log
if [[ ! -d ${LOG_DIR} ]]
then
  mkdir -p ${LOG_DIR}
  chmod a+rwx ${LOG_DIR}
fi
export LOG_FILE="update_`date +%Y-%m-%d-%H-%M-%S`.log"
LOG_FILE=${LOG_DIR}/${LOG_FILE}
touch ${LOG_FILE}
chmod a+rw ${LOG_FILE}

echo "Update started at: "`date +%Y-%m-%d-%H-%M-%S` | tee -a ${LOG_FILE}
echo "TARGET_DIR = ${TARGET_DIR}" >> ${LOG_FILE}
echo "SRC_DIR = ${SRC_DIR}" >> ${LOG_FILE}
echo "BACKUP_DIR = ${BACKUP_DIR}" >> ${LOG_FILE}

# extract Zowe version from manifest.json
export ZOWE_VERSION=$(cat ${TARGET_DIR}/manifest.json | grep version | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')
if [ -z "$ZOWE_VERSION" ]; then
  echo "Error: failed to determine Zowe version." | tee -a ${LOG_FILE}
  exit 1
elif [ "$ZOWE_VERSION" != "1.2.0" ]; then
  echo "Error: Zowe ${ZOWE_VERSION} is not supported." | tee -a ${LOG_FILE}
  exit 1
fi

echo "Updating from Zowe version: '$ZOWE_VERSION'" | tee -a ${LOG_FILE}

# backup LOADLIB to USS
echo "Backup LOADLIB to USS:" >> ${LOG_FILE}
cp -v "//'$3(ZWESIS01)'" ${TARGET_DIR}/install_log/ZWESIS01 >> ${LOG_FILE} 2>&1

# backup USS directory prior to update
echo "Backup USS directory prior to update:" >> ${LOG_FILE}
export TEMP_DIR=$BACKUP_DIR/backup_"`date +%Y-%m-%d`"
mkdir -p ${TEMP_DIR} >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
export BACKUP_FILE="${TEMP_DIR}/zowe-$ZOWE_VERSION-"`date +%Y-%m-%d-%H-%M-%S`".pax"
pax -w -f ${BACKUP_FILE} . >> ${LOG_FILE} 2>&1

# create directories
echo "Create Directories:" >> ${LOG_FILE}
mkdir -p ${TARGET_DIR}/jes_explorer >> ${LOG_FILE} 2>&1
mkdir -p ${TARGET_DIR}/mvs_explorer >> ${LOG_FILE} 2>&1
mkdir -p ${TARGET_DIR}/sample-angular-app >> ${LOG_FILE} 2>&1
mkdir -p ${TARGET_DIR}/sample-iframe-app >> ${LOG_FILE} 2>&1
mkdir -p ${TARGET_DIR}/sample-react-app >> ${LOG_FILE} 2>&1
mkdir -p ${TARGET_DIR}/tn3270-ng2 >> ${LOG_FILE} 2>&1
mkdir -p ${TARGET_DIR}/uss_explorer >> ${LOG_FILE} 2>&1
mkdir -p ${TARGET_DIR}/vt-ng2 >> ${LOG_FILE} 2>&1
mkdir -p ${TARGET_DIR}/zlux-app-server/bin >> ${LOG_FILE} 2>&1
mkdir -p ${TARGET_DIR}/zlux-app-server/deploy/instance/ZLUX/pluginStorage/org.zowe.zlux.ng2desktop/ui/launchbar/plugins/ >> ${LOG_FILE} 2>&1
mkdir -p ${TARGET_DIR}/zlux-app-server/deploy/product/ZLUX/pluginStorage/org.zowe.zlux.ng2desktop/ui/launchbar/plugins/ >> ${LOG_FILE} 2>&1
mkdir -p ${TARGET_DIR}/zlux-editor >> ${LOG_FILE} 2>&1
mkdir -p ${TARGET_DIR}/zlux-workflow >> ${LOG_FILE} 2>&1
mkdir -p ${TARGET_DIR}/zosmf-auth >> ${LOG_FILE} 2>&1
mkdir -p ${TARGET_DIR}/zss-auth >> ${LOG_FILE} 2>&1
mkdir -p ${TARGET_DIR}/api-mediation >> ${LOG_FILE} 2>&1
mkdir -p ${TARGET_DIR}/zlux-platform >> ${LOG_FILE} 2>&1

# Copy the Explorer Data Sets API jar
echo "Copy the Explorer Data Sets API jar:" >> ${LOG_FILE}
mkdir -p ${TARGET_DIR}/explorer-data-sets-api >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}/explorer-data-sets-api
cp -v ${SRC_DIR}/files/data-sets-api-server-0.2.2-boot.jar . >> ${LOG_FILE} 2>&1

# Copy the Explorer Jobs API jar
echo "Copy the Explorer Jobs API jar:" >> ${LOG_FILE}
mkdir -p ${TARGET_DIR}/explorer-jobs-api >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}/explorer-jobs-api
cp -v ${SRC_DIR}/files/jobs-api-server-0.2.4-boot.jar . >> ${LOG_FILE} 2>&1

# Unpax the LOADLIB and SAMPLIB
echo "Unpax the LOADLIB and SAMPLIB:" >> ${LOG_FILE}
mkdir -p ${TARGET_DIR}/files/zss >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}/files/zss
pax -rvf ${SRC_DIR}/files/zss.pax -ppx LOADLIB >> ${LOG_FILE} 2>&1
pax -rvf ${SRC_DIR}/files/zss.pax -ppx SAMPLIB >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}

# Unpax modified files
echo "Unpax modified files:" >> ${LOG_FILE}
cd ${TARGET_DIR}/api-mediation
pax -rvf ${SRC_DIR}/files/api-mediation-package-0.8.4.pax -ppx api-catalog-services.jar >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/api-mediation
pax -rvf ${SRC_DIR}/files/api-mediation-package-0.8.4.pax -ppx apiml-auth/lib/apimlAuth.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/api-mediation
pax -rvf ${SRC_DIR}/files/api-mediation-package-0.8.4.pax -ppx apiml-auth/lib/tokenInjector.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/api-mediation
pax -rvf ${SRC_DIR}/files/api-mediation-package-0.8.4.pax -ppx discoverable-client.jar >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/api-mediation
pax -rvf ${SRC_DIR}/files/api-mediation-package-0.8.4.pax -ppx discovery-service.jar >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/api-mediation
pax -rvf ${SRC_DIR}/files/api-mediation-package-0.8.4.pax -ppx enabler-springboot-1.5.9.RELEASE.jar >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/api-mediation
pax -rvf ${SRC_DIR}/files/api-mediation-package-0.8.4.pax -ppx gateway-service.jar >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx README.md >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx package-lock.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/code-point-at/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/cross-spawn/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/decamelize/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/end-of-stream/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/execa/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/get-caller-file/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/get-stream/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/is-fullwidth-code-point/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/is-stream/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/isexe/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/map-age-cleaner/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/mem/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/mimic-fn/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/nice-try/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/npm-run-path/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/number-is-nan/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/once/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/p-defer/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/p-finally/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/p-is-promise/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/path-exists/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/path-key/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/pump/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/require-directory/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/require-main-filename/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/semver/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/set-blocking/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/shebang-command/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/shebang-regex/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/signal-exit/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/string-width/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/strip-eof/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/which/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/wrap-ansi/node_modules/ansi-regex/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/wrap-ansi/node_modules/is-fullwidth-code-point/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/wrap-ansi/node_modules/string-width/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/wrap-ansi/node_modules/strip-ansi/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/wrap-ansi/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/wrappy/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/node_modules/y18n/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/package-lock.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/jes_explorer
pax -rvf ${SRC_DIR}/files/explorer-jes-0.0.21.pax -ppx server/src/index.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx README.md >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx package-lock.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/ansi-regex/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/camelcase/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/cliui/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/code-point-at/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/cross-spawn/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/decamelize/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/end-of-stream/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/execa/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/get-caller-file/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/get-stream/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/is-fullwidth-code-point/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/is-stream/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/isexe/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/map-age-cleaner/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/mem/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/mimic-fn/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/nice-try/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/npm-run-path/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/number-is-nan/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/once/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/p-defer/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/p-finally/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/p-is-promise/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/p-try/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/path-exists/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/path-key/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/pump/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/require-directory/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/require-main-filename/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/semver/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/set-blocking/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/shebang-command/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/shebang-regex/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/signal-exit/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/string-width/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/strip-ansi/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/strip-eof/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/which/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/wrap-ansi/node_modules/ansi-regex/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/wrap-ansi/node_modules/is-fullwidth-code-point/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/wrap-ansi/node_modules/string-width/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/wrap-ansi/node_modules/strip-ansi/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/wrap-ansi/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/wrappy/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/node_modules/y18n/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/package-lock.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/mvs_explorer
pax -rvf ${SRC_DIR}/files/explorer-mvs-0.0.15.pax -ppx server/src/index.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx lib/helloWorld.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx lib/helloWorld.js.map >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx nodeServer/package-lock.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx nodeServer/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx nodeServer/ts/helloWorld.ts >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx nodeServer/tsconfig.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx pluginDefinition.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx web/assets/i18n/messages.de.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx web/assets/i18n/messages.de.xlf >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx web/assets/i18n/messages.en.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx web/assets/i18n/messages.fr.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx web/assets/i18n/messages.fr.xlf >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx web/assets/i18n/messages.ja.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx web/assets/i18n/messages.ja.xlf >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx web/assets/i18n/messages.ru.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx web/assets/i18n/messages.ru.xlf >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx web/assets/i18n/messages.xlf >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx web/assets/i18n/messages.zh.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx web/assets/i18n/messages.zh.xlf >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx web/assets/i18n/pluginDefinition.i18n.de.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx web/assets/i18n/pluginDefinition.i18n.zh.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx web/main.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx web/main.js.map >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx webClient/package-lock.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx webClient/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx webClient/src/app/app.component.css >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx webClient/src/app/app.component.html >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx webClient/src/app/app.component.ts >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx webClient/src/app/app.module.ts >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx webClient/src/assets/i18n/messages.de.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx webClient/src/assets/i18n/messages.de.xlf >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx webClient/src/assets/i18n/messages.en.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx webClient/src/assets/i18n/messages.fr.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx webClient/src/assets/i18n/messages.fr.xlf >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx webClient/src/assets/i18n/messages.ja.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx webClient/src/assets/i18n/messages.ja.xlf >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx webClient/src/assets/i18n/messages.ru.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx webClient/src/assets/i18n/messages.ru.xlf >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx webClient/src/assets/i18n/messages.xlf >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx webClient/src/assets/i18n/messages.zh.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx webClient/src/assets/i18n/messages.zh.xlf >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx webClient/src/assets/i18n/pluginDefinition.i18n.de.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx webClient/src/assets/i18n/pluginDefinition.i18n.zh.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-angular-app
pax -rvf ${SRC_DIR}/files/zlux/sample-angular-app.pax -ppx webClient/xliffmerge.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-iframe-app
pax -rvf ${SRC_DIR}/files/zlux/sample-iframe-app.pax -ppx web/html/index.html >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-iframe-app
pax -rvf ${SRC_DIR}/files/zlux/sample-iframe-app.pax -ppx web/js/main.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-react-app
pax -rvf ${SRC_DIR}/files/zlux/sample-react-app.pax -ppx pluginDefinition.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-react-app
pax -rvf ${SRC_DIR}/files/zlux/sample-react-app.pax -ppx web/assets/i18n/i18n.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-react-app
pax -rvf ${SRC_DIR}/files/zlux/sample-react-app.pax -ppx web/assets/i18n/pluginDefinition.i18n.de.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-react-app
pax -rvf ${SRC_DIR}/files/zlux/sample-react-app.pax -ppx web/assets/i18n/pluginDefinition.i18n.fr.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-react-app
pax -rvf ${SRC_DIR}/files/zlux/sample-react-app.pax -ppx web/assets/i18n/pluginDefinition.i18n.ja.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-react-app
pax -rvf ${SRC_DIR}/files/zlux/sample-react-app.pax -ppx web/assets/i18n/pluginDefinition.i18n.ru.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-react-app
pax -rvf ${SRC_DIR}/files/zlux/sample-react-app.pax -ppx web/assets/i18n/pluginDefinition.i18n.zh.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-react-app
pax -rvf ${SRC_DIR}/files/zlux/sample-react-app.pax -ppx web/main.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-react-app
pax -rvf ${SRC_DIR}/files/zlux/sample-react-app.pax -ppx web/main.js.map >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-react-app
pax -rvf ${SRC_DIR}/files/zlux/sample-react-app.pax -ppx webClient/package-lock.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-react-app
pax -rvf ${SRC_DIR}/files/zlux/sample-react-app.pax -ppx webClient/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-react-app
pax -rvf ${SRC_DIR}/files/zlux/sample-react-app.pax -ppx webClient/src/App.tsx >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-react-app
pax -rvf ${SRC_DIR}/files/zlux/sample-react-app.pax -ppx webClient/src/SamplePage.tsx >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-react-app
pax -rvf ${SRC_DIR}/files/zlux/sample-react-app.pax -ppx webClient/src/assets/i18n/i18n.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-react-app
pax -rvf ${SRC_DIR}/files/zlux/sample-react-app.pax -ppx webClient/src/assets/i18n/pluginDefinition.i18n.de.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-react-app
pax -rvf ${SRC_DIR}/files/zlux/sample-react-app.pax -ppx webClient/src/assets/i18n/pluginDefinition.i18n.fr.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-react-app
pax -rvf ${SRC_DIR}/files/zlux/sample-react-app.pax -ppx webClient/src/assets/i18n/pluginDefinition.i18n.ja.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-react-app
pax -rvf ${SRC_DIR}/files/zlux/sample-react-app.pax -ppx webClient/src/assets/i18n/pluginDefinition.i18n.ru.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-react-app
pax -rvf ${SRC_DIR}/files/zlux/sample-react-app.pax -ppx webClient/src/assets/i18n/pluginDefinition.i18n.zh.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/sample-react-app
pax -rvf ${SRC_DIR}/files/zlux/sample-react-app.pax -ppx webClient/src/index.tsx >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/tn3270-ng2
pax -rvf ${SRC_DIR}/files/zlux/tn3270-ng2.pax -ppx _defaultTN3270.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/tn3270-ng2
pax -rvf ${SRC_DIR}/files/zlux/tn3270-ng2.pax -ppx pluginDefinition.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/tn3270-ng2
pax -rvf ${SRC_DIR}/files/zlux/tn3270-ng2.pax -ppx web/main.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/tn3270-ng2
pax -rvf ${SRC_DIR}/files/zlux/tn3270-ng2.pax -ppx web/main.js.map >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx README.md >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx package-lock.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/code-point-at/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/cross-spawn/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/decamelize/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/end-of-stream/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/execa/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/get-caller-file/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/get-stream/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/is-fullwidth-code-point/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/is-stream/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/isexe/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/map-age-cleaner/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/mem/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/mimic-fn/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/nice-try/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/npm-run-path/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/number-is-nan/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/once/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/p-defer/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/p-finally/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/p-is-promise/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/p-try/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/path-exists/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/path-key/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/pump/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/require-directory/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/require-main-filename/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/semver/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/set-blocking/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/shebang-command/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/shebang-regex/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/signal-exit/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/string-width/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/strip-eof/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/which/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/wrap-ansi/node_modules/ansi-regex/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/wrap-ansi/node_modules/is-fullwidth-code-point/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/wrap-ansi/node_modules/string-width/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/wrap-ansi/node_modules/strip-ansi/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/wrap-ansi/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/wrappy/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/node_modules/y18n/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/package-lock.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/uss_explorer
pax -rvf ${SRC_DIR}/files/explorer-uss-0.0.13.pax -ppx server/src/index.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/vt-ng2
pax -rvf ${SRC_DIR}/files/zlux/vt-ng2.pax -ppx _defaultVT.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/vt-ng2
pax -rvf ${SRC_DIR}/files/zlux/vt-ng2.pax -ppx pluginDefinition.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/vt-ng2
pax -rvf ${SRC_DIR}/files/zlux/vt-ng2.pax -ppx web/main.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/vt-ng2
pax -rvf ${SRC_DIR}/files/zlux/vt-ng2.pax -ppx web/main.js.map >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-manager/bootstrap/package-lock.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-manager/bootstrap/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-manager/bootstrap/pluginDefinition.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-manager/bootstrap/web/main.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-manager/bootstrap/web/main.js.gz >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-manager/bootstrap/web/main.js.map >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-manager/bootstrap/web/main.js.map.gz >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-manager/system-apps/app-prop-viewer/web/main.js.map >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-manager/system-apps/system-settings-preferences/pluginDefinition.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-manager/system-apps/system-settings-preferences/web/main.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-manager/system-apps/system-settings-preferences/web/main.js.map >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-manager/virtual-desktop/nodeServer/package-lock.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-manager/virtual-desktop/package-lock.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-manager/virtual-desktop/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-manager/virtual-desktop/pluginDefinition.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-manager/virtual-desktop/src/app/application-manager/application-manager.service.ts >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-manager/virtual-desktop/src/app/plugin-manager/plugin-factory/iframe/iframe-plugin-factory.ts >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-manager/virtual-desktop/src/app/shared/named-elements.ts >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-manager/virtual-desktop/src/app/window-manager/mvd-window-manager/launchbar/shared/launchbar-items/plugin-launchbar-item.ts >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-manager/virtual-desktop/tsconfig.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-manager/virtual-desktop/web/desktop.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-manager/virtual-desktop/web/desktop.js.gz >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-manager/virtual-desktop/web/desktop.js.map >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-manager/virtual-desktop/web/desktop.js.map.gz >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-manager/virtual-desktop/web/externals.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-manager/virtual-desktop/web/externals.js.gz >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-manager/virtual-desktop/web/main.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-manager/virtual-desktop/web/main.js.gz >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-server/README.md >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/zlux-app-server/bin
pax -rvf ${SRC_DIR}/files/zss.pax -ppx zssServer >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-server/config/generate_zlux_certificates.sh >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-server/deploy/product/ZLUX/serverConfig/generate_zlux_certificates.sh >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-server/doc/swagger/fileapi.yaml >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-server/doc/swagger/security-mgmt-api.yaml >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-server/lib/zluxArgs.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-app-server/package-lock.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-build/build.log >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-build/build_ng2.xml >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-build/core-plugins.properties >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-build/version.properties >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/zlux-editor
pax -rvf ${SRC_DIR}/files/zlux/zlux-editor.pax -ppx pluginDefinition.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/zlux-editor
pax -rvf ${SRC_DIR}/files/zlux/zlux-editor.pax -ppx web/main.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/zlux-editor
pax -rvf ${SRC_DIR}/files/zlux/zlux-editor.pax -ppx web/main.js.gz >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/zlux-editor
pax -rvf ${SRC_DIR}/files/zlux/zlux-editor.pax -ppx web/main.js.map >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/zlux-editor
pax -rvf ${SRC_DIR}/files/zlux/zlux-editor.pax -ppx web/main.js.map.gz >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/zlux-platform
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-platform/interface/src/index.d.ts >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/zlux-platform
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-platform/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/lib/auth-manager.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/lib/index.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/lib/plugin-loader.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/lib/sessionStore.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/lib/webapp.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/lib/webauth.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/@types/chai/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/@types/cookiejar/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/@types/node/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/@types/superagent/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/accept-language-parser/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/accepts/HISTORY.md >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/accepts/README.md >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/accepts/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/ajv/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/argparse/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/array-flatten/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/asn1/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/assert-plus/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/assertion-error/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/async-limiter/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/async/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/asynckit/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/aws-sign2/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/aws4/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/balanced-match/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/bcrypt-pbkdf/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/bluebird/js/browser/bluebird.core.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/bluebird/js/browser/bluebird.core.min.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/bluebird/js/browser/bluebird.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/bluebird/js/browser/bluebird.min.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/bluebird/js/release/debuggability.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/bluebird/js/release/promise.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/bluebird/js/release/schedule.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/bluebird/js/release/util.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/bluebird/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/body-parser/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/brace-expansion/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/bytes/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/caseless/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/chai-http/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/chai/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/check-error/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/combined-stream/lib/combined_stream.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/combined-stream/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/combined-stream/yarn.lock >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/component-emitter/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/concat-map/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/content-disposition/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/content-type/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/cookie-parser/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/cookie-signature/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/cookie/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/cookiejar/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/core-util-is/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/crc/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/dashdash/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/debug/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/deep-eql/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/delayed-stream/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/depd/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/destroy/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/ecc-jsbn/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/ee-first/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/encodeurl/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/escape-html/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/esprima/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/etag/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/eureka-js-client/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/express-session/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/express-static-gzip/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/express-ws/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/express/node_modules/statuses/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/express/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/extend/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/extsprintf/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/fast-deep-equal/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/fast-json-stable-stringify/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/finalhandler/node_modules/statuses/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/finalhandler/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/forever-agent/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/form-data/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/formidable/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/forwarded/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/fresh/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/fs.realpath/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/get-func-name/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/getpass/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/glob/LICENSE >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/glob/README.md >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/glob/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/har-schema/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/har-validator/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/http-errors/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/http-signature/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/iconv-lite/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/inflight/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/inherits/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/ip-regex/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/ipaddr.js/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/is-ip/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/is-typedarray/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/isarray/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/isstream/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/js-yaml/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/jsbn/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/json-schema-traverse/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/json-schema/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/json-stringify-safe/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/jsprim/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/lodash/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/media-typer/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/merge-descriptors/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/methods/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/mime-db/HISTORY.md >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/mime-db/db.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/mime-db/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/mime-types/HISTORY.md >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/mime-types/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/mime/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/minimatch/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/ms/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/negotiator/HISTORY.md >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/negotiator/lib/charset.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/negotiator/lib/encoding.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/negotiator/lib/language.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/negotiator/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/oauth-sign/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/on-finished/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/on-headers/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/once/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/parseurl/HISTORY.md >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/parseurl/README.md >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/parseurl/index.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/parseurl/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/path-is-absolute/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/path-to-regexp/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/pathval/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/performance-now/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/process-nextick-args/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/proxy-addr/HISTORY.md >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/proxy-addr/README.md >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/proxy-addr/node_modules/ipaddr.js/LICENSE >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/proxy-addr/node_modules/ipaddr.js/ipaddr.min.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/proxy-addr/node_modules/ipaddr.js/lib/ipaddr.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/proxy-addr/node_modules/ipaddr.js/lib/ipaddr.js.d.ts >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/proxy-addr/node_modules/ipaddr.js/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/proxy-addr/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/psl/data/rules.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/psl/dist/psl.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/psl/dist/psl.min.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/psl/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/punycode/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/qs/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/random-bytes/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/range-parser/HISTORY.md >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/range-parser/README.md >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/range-parser/index.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/range-parser/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/raw-body/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/readable-stream/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/request/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/require-from-string/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/safe-buffer/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/safer-buffer/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/semver/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/send/node_modules/statuses/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/send/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/serve-static/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/setprototypeof/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/sprintf-js/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/sshpk/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/statuses/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/string_decoder/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/superagent/node_modules/debug/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/superagent/node_modules/ms/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/superagent/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/tough-cookie/node_modules/punycode/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/tough-cookie/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/tunnel-agent/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/tweetnacl/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/type-detect/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/type-is/HISTORY.md >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/type-is/README.md >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/type-is/index.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/type-is/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/uid-safe/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/unpipe/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/uri-js/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/util-deprecate/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/utils-merge/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/uuid/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/vary/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/verror/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/wrappy/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/node_modules/ws/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/package-lock.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/plugins/config/doc/swagger/data.yaml >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/plugins/config/lib/configService.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/plugins/config/pluginDefinition.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/plugins/terminal-proxy/lib/terminalProxy.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/plugins/terminal-proxy/pluginDefinition.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-server-framework/test/webapp/config.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-shared/src/dts/htmlObfuscator.d.ts >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-shared/src/logging/package-lock.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-shared/src/logging/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-shared/src/obfuscator/htmlObfuscator.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-shared/src/obfuscator/htmlObfuscator.js.map >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-shared/src/obfuscator/htmlObfuscator.ts >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-shared/src/obfuscator/package-lock.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-shared/src/obfuscator/package.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-shared/src/obfuscator/pluginDefinition.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-shared/src/obfuscator/tsconfig.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
pax -rvf ${SRC_DIR}/files/zlux/zlux-core.pax -ppx zlux-shared/src/obfuscator/tslint.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/zlux-workflow
pax -rvf ${SRC_DIR}/files/zlux/zlux-workflow.pax -ppx lib/zosmf-service.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/zlux-workflow
pax -rvf ${SRC_DIR}/files/zlux/zlux-workflow.pax -ppx lib/zosmf-tracker-service.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/zlux-workflow
pax -rvf ${SRC_DIR}/files/zlux/zlux-workflow.pax -ppx pluginDefinition.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/zlux-workflow
pax -rvf ${SRC_DIR}/files/zlux/zlux-workflow.pax -ppx web/main.js.map >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/zosmf-auth
pax -rvf ${SRC_DIR}/files/zlux/zosmf-auth.pax -ppx lib/zosmfAuth.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/zosmf-auth
pax -rvf ${SRC_DIR}/files/zlux/zosmf-auth.pax -ppx pluginDefinition.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/zss-auth
pax -rvf ${SRC_DIR}/files/zlux/zss-auth.pax -ppx CONTRIBUTING.md >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/zss-auth
pax -rvf ${SRC_DIR}/files/zlux/zss-auth.pax -ppx lib/safprofile.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/zss-auth
pax -rvf ${SRC_DIR}/files/zlux/zss-auth.pax -ppx package-lock.json >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
cd ${TARGET_DIR}/zss-auth
pax -rvf ${SRC_DIR}/files/zlux/zss-auth.pax -ppx test/safprofile-test.js >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}

# update scripts
cp -v ${SRC_DIR}/scripts/zowe-verify.sh ${TARGET_DIR}/scripts/zowe-verify.sh >> ${LOG_FILE} 2>&1
cd ${TARGET_DIR}
sed -e 's/Dapiml.security.zosmfServiceId/Dapiml.security.auth.zosmfServiceId/g' ${TARGET_DIR}/api-mediation/scripts/api-mediation-start-catalog.sh > temp && mv temp ${TARGET_DIR}/api-mediation/scripts/api-mediation-start-catalog.sh >> ${LOG_FILE} 2>&1
sed -e 's/Dapiml.security.verifySslCertificatesOfServices/Dapiml.security.ssl.verifySslCertificatesOfServices/g' ${TARGET_DIR}/api-mediation/scripts/api-mediation-start-catalog.sh  > temp && mv temp ${TARGET_DIR}/api-mediation/scripts/api-mediation-start-catalog.sh >> ${LOG_FILE} 2>&1
chmod a+x ${TARGET_DIR}/api-mediation/scripts/api-mediation-start-catalog.sh
sed -e 's/Dapiml.discovery.staticApiDefinitionsDirectory/Dapiml.discovery.staticApiDefinitionsDirectories/g' ${TARGET_DIR}/api-mediation/scripts/api-mediation-start-discovery.sh > temp && mv temp ${TARGET_DIR}/api-mediation/scripts/api-mediation-start-discovery.sh >> ${LOG_FILE} 2>&1
sed -e 's/Dapiml.security.verifySslCertificatesOfServices/Dapiml.security.ssl.verifySslCertificatesOfServices/g' ${TARGET_DIR}/api-mediation/scripts/api-mediation-start-discovery.sh > temp && mv temp ${TARGET_DIR}/api-mediation/scripts/api-mediation-start-discovery.sh >> ${LOG_FILE} 2>&1
chmod a+x ${TARGET_DIR}/api-mediation/scripts/api-mediation-start-discovery.sh
sed -e 's/Dapiml.security.verifySslCertificatesOfServices/Dapiml.security.ssl.verifySslCertificatesOfServices/g' ${TARGET_DIR}/api-mediation/scripts/api-mediation-start-gateway.sh > temp && mv temp ${TARGET_DIR}/api-mediation/scripts/api-mediation-start-gateway.sh >> ${LOG_FILE} 2>&1
sed -e 's/Dapiml.security.zosmfServiceId/Dapiml.security.auth.zosmfServiceId/g' ${TARGET_DIR}/api-mediation/scripts/api-mediation-start-gateway.sh > temp && mv temp ${TARGET_DIR}/api-mediation/scripts/api-mediation-start-gateway.sh >> ${LOG_FILE} 2>&1
chmod a+x ${TARGET_DIR}/api-mediation/scripts/api-mediation-start-gateway.sh
sed -e 's/localhost//g' ${TARGET_DIR}/zlux-app-server/deploy/instance/ZLUX/pluginStorage/org.zowe.terminal.tn3270/sessions/_defaultTN3270.json > temp && mv temp ${TARGET_DIR}/zlux-app-server/deploy/instance/ZLUX/pluginStorage/org.zowe.terminal.tn3270/sessions/_defaultTN3270.json >> ${LOG_FILE} 2>&1
chmod a+x ${TARGET_DIR}/zlux-app-server/deploy/instance/ZLUX/pluginStorage/org.zowe.terminal.tn3270/sessions/_defaultTN3270.json
sed -e 's/localhost//g' ${TARGET_DIR}/zlux-app-server/deploy/instance/ZLUX/pluginStorage/org.zowe.terminal.vt/sessions/_defaultVT.json > temp && mv temp ${TARGET_DIR}/zlux-app-server/deploy/instance/ZLUX/pluginStorage/org.zowe.terminal.vt/sessions/_defaultVT.json >> ${LOG_FILE} 2>&1
chmod a+x ${TARGET_DIR}/zlux-app-server/deploy/instance/ZLUX/pluginStorage/org.zowe.terminal.vt/sessions/_defaultVT.json

# update version of Explorer Jobs API jar
echo "Update version of Explorer Jobs API jar:" >> ${LOG_FILE}
sed -e 's/jobs-api-server-0.2.1-boot.jar/jobs-api-server-0.2.4-boot.jar/g' ${TARGET_DIR}/explorer-jobs-api/scripts/jobs-api-server-start.sh > temp && mv temp ${TARGET_DIR}/explorer-jobs-api/scripts/jobs-api-server-start.sh >> ${LOG_FILE} 2>&1
chmod a+x ${TARGET_DIR}/explorer-jobs-api/scripts/jobs-api-server-start.sh

# update version of Explorer Data Sets API jar
echo "Update version of Explorer Data Sets API jar:" >> ${LOG_FILE}
sed -e 's/data-sets-api-server-0.1.1-boot.jar/data-sets-api-server-0.2.2-boot.jar/g' ${TARGET_DIR}/explorer-data-sets-api/scripts/data-sets-api-server-start.sh > temp && mv temp ${TARGET_DIR}/explorer-data-sets-api/scripts/data-sets-api-server-start.sh >> ${LOG_FILE} 2>&1
chmod a+x ${TARGET_DIR}/explorer-data-sets-api/scripts/data-sets-api-server-start.sh

# copy updated LOADLIB to PDS
echo "Copy updated LOADLIB to PDS:" >> ${LOG_FILE}
cp -X -v ${TARGET_DIR}/files/zss/LOADLIB/ZWESIS01 "//'$3(ZWESIS01)'" >> ${LOG_FILE}

# copy manifest.json to root folder
echo "Copy manifest.json to root folder:" >> ${LOG_FILE}
cd ${TARGET_DIR}
cp -v ${SRC_DIR}/manifest.json . >> ${LOG_FILE} 2>&1

echo "Update of Zowe '$ZOWE_VERSION' completed into directory ${TARGET_DIR}" | tee -a ${LOG_FILE}

echo "Update log location:  ${LOG_FILE}"