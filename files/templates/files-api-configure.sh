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

# Add static definition for files-api
cat <<EOF >${STATIC_DEF_CONFIG_DIR}/files-api.ebcidic.yml
#
services:
  - serviceId: datasets
    title: IBM z/OS Datasets
    description: IBM z/OS Datasets REST API service
    catalogUiTileId: datasetsAndUnixFiles
    instanceBaseUrls:
      - https://${ZOWE_EXPLORER_HOST}:${FILES_API_PORT}/
    homePageRelativeUrl:  # Home page is at the same URL
    routedServices:
      - gatewayUrl: api/v1  # [api/ui/ws]/v{majorVersion}
        serviceRelativeUrl: api/v1/datasets
    apiInfo:
      - apiId: org.zowe.data.sets
        gatewayUrl: api/v1
        version: 1.0.0
        documentationUrl: https://${ZOWE_EXPLORER_HOST}:${FILES_API_PORT}/swagger-ui.html
  - serviceId: unixfiles
    title: IBM z/OS Unix Files
    description: IBM z/OS Unix Files REST API service
    catalogUiTileId: datasetsAndUnixFiles
    instanceBaseUrls:
      - https://${ZOWE_EXPLORER_HOST}:${FILES_API_PORT}/
    homePageRelativeUrl:  # Home page is at the same URL
    routedServices:
      - gatewayUrl: api/v1  # [api/ui/ws]/v{majorVersion}
        serviceRelativeUrl: api/v1/unixfiles 
    apiInfo:
      - apiId: org.zowe.unix.files
        gatewayUrl: api/v1
        version: 1.0.0
        documentationUrl: https://${ZOWE_EXPLORER_HOST}:${FILES_API_PORT}/swagger-ui.html
catalogUiTiles:
  datasetsAndUnixFiles:
    title: z/OS Datasets and Unix Files services
    description: IBM z/OS Datasets and Unix Files REST services
EOF
iconv -f IBM-1047 -t IBM-850 ${STATIC_DEF_CONFIG_DIR}/files-api.ebcidic.yml > $STATIC_DEF_CONFIG_DIR/files-api.yml
rm ${STATIC_DEF_CONFIG_DIR}/files-api.ebcidic.yml
chmod 770 $STATIC_DEF_CONFIG_DIR/files-api.yml

. ${ROOT_DIR}/scripts/utils/configureJava.sh
