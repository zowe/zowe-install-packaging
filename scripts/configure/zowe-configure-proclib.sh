 sed -e "s#{{root_dir}}#${ZOWE_ROOT_DIR}#" \
  "${ZOWE_ROOT_DIR}/scripts/templates/ZOWESVR.template.jcl" \
  > "${ZOWE_ROOT_DIR}/scripts/templates/ZOWESVR.jcl"

# Note: this calls exit code, so can't be run in 'source' mode
$CONFIG_DIR/zowe-copy-proc.sh ${ZOWE_ROOT_DIR}/scripts/templates/ZOWESVR.jcl $ZOWE_SERVER_PROCLIB_MEMBER $ZOWE_SERVER_PROCLIB_DSNAME
