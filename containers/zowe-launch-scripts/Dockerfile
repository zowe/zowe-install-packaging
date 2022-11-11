#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project.
#######################################################################

# base image tag
ARG ZOWE_BASE_IMAGE=2.0.2-ubuntu

FROM zowe-docker-release.jfrog.io/ompzowe/base-node:${ZOWE_BASE_IMAGE}

##################################
# labels
LABEL name="Zowe Launch Script Image" \
      maintainer="jack-tiefeng.jia@ibm.com" \
      vendor="Zowe" \
      version="0.0.0" \
      release="0" \
      summary="Base Launch Script for Zowe components" \
      description="Base Launch Script for Zowe components"

##################################
# switch context
USER zowe:zowe
WORKDIR /component

##################################
# copy files
COPY --chown=zowe:zowe zowe .
COPY --chown=zowe:zowe zowe/LICENSE /licenses

##################################
# start command
CMD ["/bin/sh", "-c", "/component/bin/zwe internal container init"]
