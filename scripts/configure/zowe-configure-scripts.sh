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
  -e "s#{{root_dir}}#${ZOWE_ROOT_DIR}#" \
  -e "s#{{user_dir}}#${ZOWE_USER_DIR}#" \
  -e "s#{{java_home}}#${ZOWE_JAVA_HOME}#" \
  -e "s#{{files_api_port}}#${ZOWE_EXPLORER_SERVER_DATASETS_PORT}#" \
  -e "s#{{jobs_api_port}}#${ZOWE_EXPLORER_SERVER_JOBS_PORT}#" \
  -e "s#{{jobs_ui_port}}#${ZOWE_EXPLORER_JES_UI_PORT}#"
  -e "s#{{discovery_port}}#${ZOWE_APIM_DISCOVERY_PORT}#" \
  -e "s#{{catalog_port}}#${ZOWE_APIM_CATALOG_PORT}#" \
  -e "s#{{gateway_port}}#${ZOWE_APIM_GATEWAY_PORT}#" \
  -e "s#{{verify_certificates}}#${ZOWE_APIM_VERIFY_CERTIFICATES}#" \
  -e "s#{{zosmf_port}}#${ZOWE_ZOSMF_PORT}#" \
  -e "s#{{zosmf_ip_address}}#${ZOWE_ZOSMF_HOST}#" \
  -e "s#{{zowe_explorer_host}}#${ZOWE_EXPLORER_HOST}#" \
  -e "s#{{zowe_ip_address}}#${ZOWE_IPADDRESS}#" \
  -e "s#{{stc_name}}#${ZOWE_SERVER_PROCLIB_MEMBER}#" \
  -e "s#{{key_alias}}#localhost#" \
  -e "s#{{keystore}}#${ZOWE_ROOT_DIR}/components/api-mediation/keystore/localhost/localhost.keystore.p12#" \
  -e "s#{{keystore_password}}#password#" \
  -e "s#{{truststore}}#${ZOWE_ROOT_DIR}/components/api-mediation/keystore/localhost/localhost.truststore.p12#" \
  -e "s#{{keystore_key}}#${ZOWE_ROOT_DIR}/components/api-mediation/keystore/localhost/localhost.keystore.key#" \
  -e "s#{{keystore_certificate}}#${ZOWE_ROOT_DIR}/components/api-mediation/keystore/localhost/localhost.keystore.cer-ebcdic#" \
  "${ZOWE_ROOT_DIR}/scripts/templates/run-zowe.template.sh" \
  > "${ZOWE_ROOT_DIR}/scripts/internal/run-zowe.sh"

chmod -R 777 $ZOWE_ROOT_DIR/scripts
