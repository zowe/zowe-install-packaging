#Inject variables into zowe runtime scripts
sed -e "s#{{stc_name}}#${ZOWE_SERVER_PROCLIB_MEMBER}#" \
    -e "s#{{zowe_prefix}}#${ZOWE_PREFIX}#" \
    -e "s#{{zowe_instance}}#${ZOWE_INSTANCE}#" \
  "${ZOWE_ROOT_DIR}/scripts/templates/zowe-start.template.sh" \
  > "${ZOWE_ROOT_DIR}/scripts/zowe-start.sh" 

sed -e "s#{{zowe_prefix}}#${ZOWE_PREFIX}#" \
    -e "s#{{zowe_instance}}#${ZOWE_INSTANCE}#" \
  "${ZOWE_ROOT_DIR}/scripts/templates/zowe-stop.template.sh" \
  > "${ZOWE_ROOT_DIR}/scripts/zowe-stop.sh" 

sed -e "s#{{java_home}}#${ZOWE_JAVA_HOME}#" \
  -e "s#{{node_home}}#${NODE_HOME}#" \
  -e "s#{{zowe_prefix}}#${ZOWE_PREFIX}#" \
  -e "s#{{zowe_instance}}#${ZOWE_INSTANCE}#" \
  -e "s#{{stc_name}}#${ZOWE_SERVER_PROCLIB_MEMBER}#" \
  "${ZOWE_ROOT_DIR}/scripts/templates/zowe-support.template.sh" \
  > "${ZOWE_ROOT_DIR}/scripts/zowe-support.sh"

sed -e "s#{{node_home}}#${NODE_HOME}#" \
  -e "s#{{zowe_prefix}}#${ZOWE_PREFIX}#" \
  -e "s#{{zowe_instance}}#${ZOWE_INSTANCE}#" \
  "${ZOWE_ROOT_DIR}/scripts/templates/run-zowe.template.sh" \
  > "${ZOWE_ROOT_DIR}/scripts/internal/run-zowe.sh"

chmod -R 777 $ZOWE_ROOT_DIR/scripts
