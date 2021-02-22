#!/bin/bash
# Adjust hostname to match Docker host hostname and certificate in server.p12 (-h ...)
# Specify ZOSMF and ZSS hostnames and ports (--env ...)
# Provide location of your certificate if using external one (source=...)
# Certificate folder structure must be identical to a zowe z/os release, minus z/os keyrings
# LAUNCH_COMPONENT_GROUPS valid values out of the box are GATEWAY and DESKTOP or GATEWAY,DESKTOP

DISCOVERY_PORT=7553
GATEWAY_PORT=7554
APP_SERVER_PORT=8544

# You may wish to set --env ZOWE_EXPLOERER_HOST to the value of hostname if iframe apps do not load

#add non-default settings with --env, using same properties as seen in instance.env
#   --env ZOWE_ZLUX_TELNET_PORT=23
docker run -it \
    --env ZOWE_START=1 \
    -h your_hostname \
    --env ZOWE_IP_ADDRESS=your.external.ip \
    --env LAUNCH_COMPONENT_GROUPS=DESKTOP,GATEWAY \
    --env ZOSMF_HOST=your.zosmainframe.com \
    --env ZWED_agent_host=your.zosmainframe.com \
    --env ZOSMF_PORT=11443 \
    --env ZWED_agent_http_port=8542 \
    --expose ${DISCOVERY_PORT} \
    --expose ${GATEWAY_PORT} \
    --expose ${APP_SERVER_PORT} \
    -p ${DISCOVERY_PORT}:${DISCOVERY_PORT} \
    -p ${GATEWAY_PORT}:${GATEWAY_PORT} \
    -p ${APP_SERVER_PORT}:${APP_SERVER_PORT} \
    --env GATEWAY_PORT=${GATEWAY_PORT} \
    --env DISCOVERY_PORT=${DISCOVERY_PORT} \
    --env ZOWE_ZLUX_SERVER_HTTPS_PORT=${APP_SERVER_PORT} \
    ompzowe/server-bundle:latest $@
