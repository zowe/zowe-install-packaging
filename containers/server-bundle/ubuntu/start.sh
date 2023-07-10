#!/bin/bash
# Adjust hostname to match Docker host hostname and certificate in server.p12 (-h ...)
# Specify ZOSMF and ZSS hostnames and ports (--env ...)
# Provide location of your certificate if using external one (source=...)
# Certificate folder structure must be identical to a zowe z/os release, minus z/os keyrings
# LAUNCH_COMPONENT_GROUPS valid values out of the box are GATEWAY and DESKTOP or GATEWAY,DESKTOP

DISCOVERY_PORT=7553
GATEWAY_PORT=7554
APP_SERVER_PORT=7556
# If using external instance (recommended), put the path to it on the host computer here
# EXT_INSTANCE_PATH=



if [ -d "${EXT_INSTANCE_PATH}" ]; then
  full_instance_path=$(cd ${EXT_INSTANCE_PATH} && pwd)
  instance_mount="-v ${full_instance_path}:/home/zowe/external_instance:rw"
fi

# You may wish to set --env ZOWE_EXPLOERER_HOST to the value of hostname if iframe apps do not load

#add non-default settings with --env, using same properties as seen in instance.env
#   --env ZWED_TN3270_PORT=23
docker run -it \
    --env ZOWE_START=1 \
    -h your_hostname \
    --env ZOWE_IP_ADDRESS=your.external.ip \
    --env LAUNCH_COMPONENT_GROUPS=DESKTOP,GATEWAY \
    --env ZOSMF_HOST=your.zosmainframe.com \
    --env ZWED_agent_host=your.zosmainframe.com \
    --env ZOSMF_PORT=11443 \
    --env ZWED_agent_https_port=7557 \
    -p ${DISCOVERY_PORT}:7553 \
    -p ${GATEWAY_PORT}:7554 \
    -p ${APP_SERVER_PORT}:7556 \
    ${instance_mount} \
    ompzowe/server-bundle:latest $@
