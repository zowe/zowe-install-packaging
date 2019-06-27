 sed -e "s#{{root_dir}}#${ZOWE_ROOT_DIR}#" \
  "${ZOWE_ROOT_DIR}/scripts/templates/ZOWESVR.template.jcl" \
  > "${ZOWE_ROOT_DIR}/scripts/templates/ZOWESVR.jcl"

$INSTALL_DIR/scripts/zowe-copy-proc.sh ${ZOWE_ROOT_DIR}/scripts/templates/ZOWESVR.jcl $ZOWE_SERVER_PROCLIB_MEMBER $ZOWE_SERVER_PROCLIB_DSNAME
