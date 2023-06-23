FROM ompzowe/zowecicd-node12-java8:v2.1 as builder

# allow to customize which Zowe build to build from
# There are 3 possible values:
# 1. ZOWE_BUILD=: empty, which will try to find the local zowe.pax in same directory. The build has to be named as zowe.pax.
# 2. ZOWE_BUILD=latest: will download the most recent official release and use it as base build
# 3. ZOWE_BUILD=<url>: will download Zowe build from this url and use it as base build
ARG ZOWE_BUILD=

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget \
    groff iproute2 moreutils pax && \
    rm -rf /var/lib/apt/lists/*

EXPOSE 7553/tcp
EXPOSE 7554/tcp
EXPOSE 8544/tcp

#ENV ZOWE_ZOSMF_HOST='zosmf.host.com'
#ENV ZOWE_ZSS_HOST='zss.host.com'
#ENV ZWED_agent_host='zwed.host.com'
ENV ZOWE_EXPLORER_HOST='localhost'
ENV ZOWE_IP_ADDRESS=0.0.0.0

ENV ZOWE_ZOSMF_PORT='443'
#ENV ZOWE_ZSS_SERVER_PORT='00000'
ENV ZWED_agent_https_port='8542'

ENV LAUNCH_COMPONENT_GROUPS=DESKTOP,GATEWAY

RUN mkdir /home/zowe/utils && \
    mkdir /home/zowe/samples
COPY utils/ /home/zowe/utils/
COPY start.sh /home/zowe/samples/
COPY NOTICE.txt LICENSE.txt /home/zowe/

RUN cd /home/zowe/utils/autoconv && \
    npm install && \
    npm run build && \
    rm -rf node_modules src samples *.js *.json .editorconfig *ignore *.md && \
    ln -s ./autoconv/bin/autoconv ../autoconv.sh

# copy run.sh and optional zowe.pax
COPY run.sh run_inner.sh /home/zowe/
COPY zowe.pax* /tmp

# download zowe build if specified
RUN /home/zowe/utils/download-zowe-build.sh "${ZOWE_BUILD}"

# 1. Convert content of pax files from ebcdic to ASCII
# 2. replace or remove some zos specific parameters
# 3. Install zowe, then remove installer files
RUN mv /home/zowe/run_inner.sh /home/zowe/.run_inner.sh && \
    mkdir -p /tmp/zowe-install && cd /tmp/zowe-install && \
    tar -xvf ../zowe.pax --strip 1 && \
    find . -type f -iregex '.*\.\(rexx\|js\|sh\|json\|jcl\|yaml\|clist\|env\)$' -exec sh -c "conv '{}' | sponge '{}'" \; && \
    find . -type f -name '*.sh' -exec sh -c "sed -i 's/-Xquickstart//' {}" \; && \
    find . -type f -name '*.sh' -exec sh -c "sed -i 's/-ppx/-pp/' {}" \; && \
    find . -type f -name '*.sh' -exec sh -c "sed -i 's/iconv -f IBM-1047 -t IBM-850/cat/' {}" \; && \
    find . -type f -name '*.sh' -exec sh -c "chmod +x {}" \; && \
    echo "exit 0" > scripts/opercmd && \
    sed -i 's/java version/openjdk version/' scripts/utils/validate-java.sh && \
    \
    \
    cd /tmp/zowe-install/files && \
    mv app-server-*.pax zlux && \
    for f in *.pax; do \
        echo "Processing ebcdic pax $f" && \
        cd /tmp/zowe-install/files &&\
        rm -rf tmp && \
        mkdir tmp && \
        cd tmp && \
        pax -rf ../$f && \
        rm ../$f && \
        find . -type f -iregex '.*\.\(rexx\|js\|sh\|json\|jcl\|yaml\|clist\|html\|template\|css\|svg\|map\|gz\|env\)$' -exec sh -c "conv '{}' | sponge '{}'" \; && \
        find . -type f -name '*.sh' -exec sh -c "sed -i 's/-Xquickstart//' {}" \; && \
        pax -wf ../$f . && \
        cd .. ;  \
    done && \
    rm -f zss*.pax && \
    cd zlux && \
    for f in *.pax; do \
        echo "Processing tagged pax $f" &&\
        cd /tmp/zowe-install/files/zlux &&\
        rm -rf tmp &&\
        mkdir tmp &&\
        cd tmp &&\
        pax -rf ../$f &&\
        rm ../$f &&\
        find . -type f -iregex '.*\.\(sh\)$' -exec sh -c "conv '{}' | sponge '{}'" \; && \
        find . -type f -name '*.sh' -exec sh -c "sed -i 's/-Xquickstart//' {}" \; &&\
        find . -type f -name '*.sh' -exec sh -c "sed -i 's/-px //' {}" \; && \
        pax -wf ../$f . &&\
        cd .. ; \
    done && \
    mv app-server-*.pax .. && \
    \
    \
    /tmp/zowe-install/install/zowe-install.sh -i /home/zowe/install -l /home/zowe/logs && \
  	bash -c "/home/zowe/install/bin/zowe-configure-instance.sh -c /home/zowe/instance" && \
    \
    \
    cd /home/zowe/install/components/explorer-ui-server && \
    rm -rf node_modules && \
    npm install --only=prod --ignore-scripts && \
    cd /home/zowe/install/components && \
    find */bin -type f -name '*.sh' -exec sh -c "sed -i 's/-Xquickstart//' {}" \;

# Could be modified during runtime, back it up.
RUN cp /home/zowe/instance/instance.env /home/zowe/instance/instance.env.bkp \
    && cp /home/zowe/install/bin/zowe-setup-certificates.env /home/zowe/install/bin/zowe-setup-certificates.env.bkp

FROM ompzowe/zowecicd-node12-java8:v2.1

EXPOSE 7553/tcp
EXPOSE 7554/tcp
EXPOSE 8544/tcp

#ENV ZOWE_ZOSMF_HOST='zosmf.host.com'
#ENV ZOWE_ZSS_HOST='zss.host.com'
#ENV ZWED_agent_host='zwed.host.com'
ENV ZOWE_EXPLORER_HOST='localhost'
ENV ZOWE_IP_ADDRESS=0.0.0.0

ENV ZOWE_ZOSMF_PORT='443'
#ENV ZOWE_ZSS_SERVER_PORT='00000'
ENV ZWED_agent_https_port='8542'

# authorization needs to point to zss endpoint
ENV APIML_SECURITY_AUTHORIZATION_PROVIDER=endpoint
ENV APIML_SECURITY_AUTHORIZATION_ENDPOINT_ENABLED=true

ENV LAUNCH_COMPONENT_GROUPS=DESKTOP,GATEWAY

COPY --chown=zowe:zowe --from=builder /home/zowe /home/zowe
RUN chmod a+x /home/zowe/*.sh /home/zowe/.run_inner.sh

ENTRYPOINT ["/home/zowe/run.sh"]
