#!/bin/bash
# Example usage:
# sudo ./copy-jwt-to-zss.sh -c exciting_bhaskara -u MYTSO -rd /u/mytso/docker_tmp
TEMP_DIR=~/.jwttmp
REMOTE_DIR='.jwttmp'
OUT_FILE_NAME=jwtsecret.p12
ZSS_HOST=
ZSS_USER=REMOTE_USER
CONTAINER_NAME=container_name
AUTO_IMPORT=FALSE
P11_TKN_NAME=ZOWE.ZSS.JWTKEYS
P11_TKN_LABEL=KEY_APIML

function usage {
    echo "This script is for transferring the APIML JWT public key created during certificate generation to the Zowe ZSS host."
    echo ""
    echo "usage: sudo copy-jwt-to-zss.sh -[OPTION]"
    echo "or: sudo copy-jwt-to-zss.sh --[OPTION]"
    echo ""
    echo "  Options:"
    echo "     -c [name], --container [name]       - name of zowe docker container. run 'docker ps' for info"
    echo "     -h [ip], --host [ip]                - Zowe ZSS host address. default: ZOWE_ZSS_HOST environment variable from container"
    echo "     -i, --import                        - use this flag to attempt to import APIML public key to PKCS#11 after scp"
    echo "     -o [filename], --out [filename]     - nanme of output file to be copied to remote directory. default: jwtsecret.p12"
    echo "     -u [user], --username [user]        - scp username for connection to remote (Zowe ZSS) host. default: REMOTE_USER" 
    echo "     -td [path], --tempdir [path]        - directory to store temp files from docker container. default: ~/.jwttmp"
    echo "     -rd [path], --remotedir [path]      - directory to copy APIML JWT public key to on remote host. default: .jwttmp"
    echo "     --token_name [name]                 - PKCS#11 token name to use for importing. default: ZOWE.ZSS.JWTKEYS"
    echo "     --token_label [label]               - PKCS#11 token label to use for importing. default: KEY_APIML"
    echo "     --help                              - help"
    echo ""
}

function cleanLocalCopy() {
  rm -f "${FULL_LOCAL_OUT_PATH}"
}

while [ "$1" != "" ]; do
  case $1 in
    -c | --container )    shift
                          CONTAINER_NAME=$1
                          ;;       
    -td | --tempdir )     shift
                          TEMP_DIR=${1%/}
                          ;;               
    -rd | --remotedir )   shift
                          REMOTE_DIR=${1%/}
                          ;;
    -o | --out )          shift
                          OUT_FILE_NAME=$1
                          ;;
    -h | --host )         shift
                          ZSS_HOST=$1
                          ;;
    -i | --import )       AUTO_IMPORT=TRUE
                          ;;
    -u | --username )     shift
                          ZSS_USER=$1
                          ;;
    --token_name )        shift
                          P11_TKN_NAME=$1
                          ;;
    --token_label )       shift
                          P11_TKN_LABEL=$1
                          ;;
    --help )              usage
                          exit
                          ;;
    * )                   echo "Invalid command: $1"
                          usage
                          exit 1
  esac
  shift
done

if ! mkdir -m 700 -p "${TEMP_DIR}"; then
  echo "Couldn't create the local directory ${TEMP_DIR}"
  exit 1
fi

# Automatic deletion of the local copy on exit
trap cleanLocalCopy EXIT

FULL_LOCAL_OUT_PATH="${TEMP_DIR}/${OUT_FILE_NAME}"
echo "OUT PATH=${FULL_LOCAL_OUT_PATH}"
docker cp $CONTAINER_NAME:/global/zowe/keystore/localhost/localhost.keystore.jwtsecret.p12 $FULL_LOCAL_OUT_PATH || {
  echo "Unable to copy the jwtsecret to the localhost";
  exit 1
}

chmod 600 "${FULL_LOCAL_OUT_PATH}"
if [ -z "$ZSS_HOST" ]; then
  ZSS_HOST=$(docker exec $CONTAINER_NAME bash -c 'echo $ZOWE_ZSS_HOST')
fi
echo "Creating the temp directory on the remote system"
if ! ssh $ZSS_USER@$ZSS_HOST "mkdir -m 700 -p $REMOTE_DIR"; then
  echo "Unable to create the directory ${ZSS_HOST}:${REMOTE_DIR}"
  exit 1
fi
echo "Initiating scp file transfer to ${ZSS_USER}@${ZSS_HOST}"
if ! scp $FULL_LOCAL_OUT_PATH $ZSS_USER@$ZSS_HOST:$REMOTE_DIR/$OUT_FILE_NAME ; then
    echo "Unable to write ${ZSS_HOST}:${REMOTE_DIR}/${OUT_FILE_NAME}. File may already exist or user may have insufficient write permissions."
    exit 1
else
  echo "APIML public key successfully transferred to Zowe ZSS host. File may need to be tagged as ISO8859 before importing"
  if [[ "${AUTO_IMPORT}" == "TRUE" ]]; then
    if ! ssh $ZSS_USER@$ZSS_HOST "chtag -tc ISO8859-1 ${REMOTE_DIR}/${OUT_FILE_NAME} && gskkyman -i -t ${P11_TKN_NAME} -l ${P11_TKN_LABEL} -p ${REMOTE_DIR}/${OUT_FILE_NAME}" ; then
      echo "Unable to import key to PKCS#11 on ZSS host using token name ${P11_TKN_NAME} and token label ${P11_TKN_LABEL}"
      echo "Keeping the file ${ZSS_HOST}:${REMOTE_DIR}/${OUT_FILE_NAME} intact so it can be debugged."
      exit 1
    else
      echo "Successfully imported APIML public key on zowe ZSS host"
      echo "Deleting the ${OUT_FILE_NAME}."
      if ! ssh $ZSS_USER@$ZSS_HOST "rm -f ${REMOTE_DIR}/${OUT_FILE_NAME}"; then
        echo "Couldn't delete the remote copy from ${ZSS_HOST}:${REMOTE_DIR}/${OUT_FILE_NAME}"
      fi
    fi
  fi
fi
# if [ -z "$PASSWORD" ]; then
#   if ! scp $FULL_LOCAL_OUT_PATH $ZSS_USER@$ZSS_HOST:$REMOTE_DIR/$OUT_FILE_NAME ; then
#     echo "Unable to write ${ZSS_HOST}:${REMOTE_DIR}/${OUT_FILE_NAME}. File may already exist or user may have insufficient write permissions."
#   else
#     if [[ "${AUTO_IMPORT}" == "TRUE" ]]; then
#       if ! ssh $ZSS_USER@$ZSS_HOST "gskkyman -i -t ${P11_TKN_NAME} -l ${P11_TKN_LABEL} -p ${REMOTE_DIR}/${OUT_FILE_NAME}" ; then
#         echo "Unable to import key to PKCS#11 on ZSS host using token name ${P11_TKN_NAME} and token label ${P11_TKN_LABEL}"
#       else
#         echo "Big success guy"
#       fi
#     fi
#   fi
# else
#   echo "Password is set"
#   if ! echo "${PASSWORD}" | scp $FULL_LOCAL_OUT_PATH $ZSS_USER@$ZSS_HOST:$REMOTE_DIR/$OUT_FILE_NAME ; then
#     echo "Unable to write ${ZSS_HOST}:${REMOTE_DIR}/${OUT_FILE_NAME}. File may already exist or user may have insufficient write permissions."
#   else
#     echo "APIML public key successfully transferred to Zowe ZSS host. File may need to be tagged as ISO8859 before importing"
#     if [[ "${AUTO_IMPORT}" == "TRUE" ]]; then
#       echo "Auto import true, pass: ${PASSWORD}"
#       if ! echo "${PASSWORD}" | ssh $ZSS_USER@$ZSS_HOST "gskkyman -i -t ${P11_TKN_NAME} -l ${P11_TKN_LABEL} -p ${REMOTE_DIR}/${OUT_FILE_NAME}" ; then
#         echo "Unable to import key to PKCS#11 on ZSS host using token name ${P11_TKN_NAME} and token label ${P11_TKN_LABEL}"
#       else
#         echo "Successfully imported APIML public key on zowe ZSS host"
#       fi
#     fi
#   fi
# fi
