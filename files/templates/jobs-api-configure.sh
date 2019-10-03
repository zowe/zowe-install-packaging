#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project. 2019, 2019
#######################################################################

# Add static definition for jobs-api
cat <<EOF >${STATIC_DEF_CONFIG_DIR}/jobs-api.ebcidic.yml
#
services:
  - serviceId: jobs
    title: IBM z/OS Jobs
    description: IBM z/OS Jobs REST API service
    catalogUiTileId: jobs
    instanceBaseUrls:
      - https://${ZOWE_EXPLORER_HOST}:${JOBS_API_PORT}/
    homePageRelativeUrl:
    routedServices:
      - gatewayUrl: api/v1
        serviceRelativeUrl: api/v1/jobs
    apiInfo:
      - apiId: com.ibm.jobs
        gatewayUrl: api/v1
        version: 1.0.0
        documentationUrl: https://${ZOWE_EXPLORER_HOST}:${JOBS_API_PORT}/swagger-ui.html
catalogUiTiles:
  jobs:
    title: z/OS Jobs services
    description: IBM z/OS Jobs REST services
EOF
iconv -f IBM-1047 -t IBM-850 ${STATIC_DEF_CONFIG_DIR}/jobs-api.ebcidic.yml > $STATIC_DEF_CONFIG_DIR/jobs-api.yml
rm ${STATIC_DEF_CONFIG_DIR}/jobs-api.ebcidic.yml
chmod 770 $STATIC_DEF_CONFIG_DIR/jobs-api.yml

#Make sure Java is available on the path - TODO needed at all, move to a all zowe setup/validate?
export JAVA_HOME=$ZOWE_JAVA_HOME
if [[ ":$PATH:" == *":$JAVA_HOME/bin:"* ]]; then
  echo "ZOWE_JAVA_HOME already exists on the PATH"
else
  echo "Appending ZOWE_JAVA_HOME/bin to the PATH..."
  export PATH=$PATH:$JAVA_HOME/bin
  echo "Done."
fi
