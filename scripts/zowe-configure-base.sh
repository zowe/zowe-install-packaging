# TODO MAYBE- get zosmf host separately rather than assume it's on same host as zowe?
# TODO - change keystore details and location
 sed -e "s#{{root_dir}}#${ZOWE_ROOT_DIR}#" \
  -e "s#{{java_home}}#${ZOWE_JAVA_HOME}#" \
  -e "s#{{files_api_port}}#${ZOWE_EXPLORER_SERVER_DATASETS_PORT}#" \
  -e "s#{{jobs_api_port}}#${ZOWE_EXPLORER_SERVER_JOBS_PORT}#" \
  -e "s#{{zosmf_port}}#${ZOWE_ZOSMF_PORT}#" \
  -e "s#{{zosmf_ip_address}}#${ZOWE_IPADDRESS}#" \
  -e "s#{{stc_name}}#${ZOWE_SERVER_PROCLIB_MEMBER}#" \
  -e "s#{{node_home}}#${NODE_HOME}#" \
  -e "s#{{key_alias}}#localhost#" \
  -e "s#{{keystore}}#${ZOWE_ROOT_DIR}/api-mediation/keystore/localhost/localhost.keystore.p12#" \
  -e "s#{{keystore_password}}#password#" \
  "${ZOWE_ROOT_DIR}/scripts/internal/run-zowe.template.sh" \
  > "${ZOWE_ROOT_DIR}/scripts/internal/run-zowe.sh"