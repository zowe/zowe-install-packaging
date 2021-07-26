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

FROM zowe-docker-release.jfrog.io/ompzowe/base-node:latest-ubi

##################################
# labels
LABEL name="Zowe Launch Script Image" \
      maintainer="jack-tiefeng.jia@ibm.com" \
      vendor="Zowe" \
      version="0.0.1" \
      release="0" \
      summary="Base Launch Script for Zowe components" \
      description="Base Launch Script for Zowe components"

##################################
# copy license file
RUN mkdir /licenses
COPY zowe/LICENSE /licenses

##################################
# switch context
USER zowe
WORKDIR /home/zowe

##################################
# copy files
COPY zowe .

##################################
# start command
CMD ["/home/zowe/bin/internal/init-container.sh"]
