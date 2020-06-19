#!/bin/sh

#
# APIML Certificate Management
# ============================
#
# User guide: https://github.com/zowe/docs-site/blob/apiml-https/docs/guides/api-mediation-security.md
#
# IBM Java keytool documentation:
# https://www.ibm.com/support/knowledgecenter/en/SSYKE2_8.0.0/com.ibm.java.security.component.80.doc/security-component/keytoolDocs/keytool_overview.html
#

if [ `uname` = "OS/390" ]; then
    export IBM_JAVA_OPTIONS="-Dfile.encoding=IBM-1047"
fi

BASE_DIR=$(dirname "$0")
PARAMS="$@"
PWD=`pwd`

function usage {
    echo "APIML Certificate Management"
    echo "usage: apiml_cm.sh --action <action>"
    echo ""
    echo "  <action> action to be done:"
    echo "     - setup - setups APIML certificate management"
    echo "     - new-service-csr - creates CSR for new service to be signed by external CA"
    echo "     - new-service - adds new service signed by local CA or external CA"
    echo "     - trust - adds a public certificate of a service to APIML truststore"
    echo "     - trust-zosmf - adds public certificates from z/OSMF to APIML truststore"
    echo "     - clean - removes files created by setup"
    echo "     - jwt-keygen - generates and exports JWT key pair"
    echo ""
    echo "  Called with: ${PARAMS}"
}

ACTION=
V=
LOG=

LOCAL_CA_ALIAS="localca"
LOCAL_CA_FILENAME="keystore/local_ca/localca"
LOCAL_CA_DNAME="CN=Zowe Development Instances Certificate Authority, OU=API Mediation Layer, O=Zowe Sample, L=Prague, S=Prague, C=CZ"
LOCAL_CA_PASSWORD="local_ca_password"
LOCAL_CA_VALIDITY=3650
EXTERNAL_CA_FILENAME="keystore/local_ca/extca"
EXTERNAL_CA=

SERVICE_ALIAS="localhost"
JWT_ALIAS="jwtsecret"
SERVICE_PASSWORD="password"
SERVICE_KEYSTORE="keystore/localhost/localhost.keystore"
SERVICE_TRUSTSTORE="keystore/localhost/localhost.truststore"
SERVICE_DNAME="CN=Zowe Service, OU=API Mediation Layer, O=Zowe Sample, L=Prague, S=Prague, C=CZ"
SERVICE_EXT="SAN=dns:localhost.localdomain,dns:localhost"
SERVICE_VALIDITY=3650
SERVICE_STORETYPE="PKCS12"
EXTERNAL_CERTIFICATE=
EXTERNAL_CERTIFICATE_ALIAS=
ZOSMF_CERTIFICATE=

ZOWE_USERID=ZWESVUSR
ZOWE_KEYRING=ZWERING

ALIAS="alias"
CERTIFICATE="no-certificate-specified"

if [ -z ${TEMP_DIR+x} ]; then
    TEMP_DIR=${TMPDIR:-/tmp}
fi

function pkeytool {
    ARGS=$@
    echo "Calling keytool $ARGS"
    if [ "$LOG" != "" ]; then
        keytool "$@" >> $LOG 2>&1
    else
        keytool "$@"
    fi
    RC=$?
    echo "keytool returned: $RC"
    if [ "$RC" -ne "0" ]; then
        exit 1
    fi
}

function clean_keyring {
    if [[ "${SERVICE_STORETYPE}" == "JCERACFKS" ]]; then
        KEYRING_UTIL=${BASE_DIR}/utils/keyring-util/keyring-util
        chmod +x $KEYRING_UTIL
        echo "Removing ${ZOWE_USERID}/${ZOWE_KEYRING} keyring"
        $KEYRING_UTIL delring ${ZOWE_USERID} ${ZOWE_KEYRING}
    fi
}

function clean_local_ca {
    rm -f ${LOCAL_CA_FILENAME}.keystore.p12 ${LOCAL_CA_FILENAME}.cer
    if [[ "${SERVICE_STORETYPE}" == "JCERACFKS" ]]; then
        KEYRING_UTIL=${BASE_DIR}/utils/keyring-util/keyring-util
        chmod +x $KEYRING_UTIL
        echo "Disconnecting ${LOCAL_CA_ALIAS} certificate from the ${ZOWE_KEYRING} keyring"
        $KEYRING_UTIL delcert ${ZOWE_USERID} ${ZOWE_KEYRING} ${LOCAL_CA_ALIAS}
        echo "Removing ${LOCAL_CA_ALIAS} certificate from RACF database"
        $KEYRING_UTIL delcert ${ZOWE_USERID} "*" ${LOCAL_CA_ALIAS}
    fi
}

function clean_service {
    rm -f ${SERVICE_KEYSTORE}.p12 ${SERVICE_KEYSTORE}.csr ${SERVICE_KEYSTORE}_signed.cer ${SERVICE_TRUSTSTORE}.p12
    if [[ "${SERVICE_STORETYPE}" == "JCERACFKS" ]]; then
        KEYRING_UTIL=${BASE_DIR}/utils/keyring-util/keyring-util
        chmod +x $KEYRING_UTIL
        echo "Disconnecting ${SERVICE_ALIAS} certificate from the ${ZOWE_KEYRING} keyring"
        $KEYRING_UTIL delcert ${ZOWE_USERID} ${ZOWE_KEYRING} ${SERVICE_ALIAS}
        echo "Disconnecting ${JWT_ALIAS} certificate from the ${ZOWE_KEYRING} keyring"
        $KEYRING_UTIL delcert ${ZOWE_USERID} ${ZOWE_KEYRING} ${JWT_ALIAS}
        echo "Removing ${SERVICE_ALIAS} certificate from RACF database"
        $KEYRING_UTIL delcert ${ZOWE_USERID} "*" ${SERVICE_ALIAS}
        echo "Removing ${JWT_ALIAS} certificate from RACF database"
        $KEYRING_UTIL delcert ${ZOWE_USERID} "*" ${JWT_ALIAS}
    fi
}

function create_certificate_authority {
    if [[ "${SERVICE_STORETYPE}" == "JCERACFKS" ]]; then
        echo "Generate keyring with the local CA private key and local CA public certificate:"
        pkeytool -genkeypair $V -alias ${LOCAL_CA_ALIAS} -keyalg RSA -keysize 2048 -keystore safkeyring://${ZOWE_USERID}/${ZOWE_KEYRING} \
            -dname "${LOCAL_CA_DNAME}" -storetype ${SERVICE_STORETYPE} -validity ${LOCAL_CA_VALIDITY} \
            -ext KeyUsage="keyCertSign" -ext BasicConstraints:"critical=ca:true" -J-Djava.protocol.handler.pkgs=com.ibm.crypto.provider

        echo "Export local CA public certificate:"
        pkeytool -export $V -alias ${LOCAL_CA_ALIAS} -file ${LOCAL_CA_FILENAME}.cer -keystore safkeyring://${ZOWE_USERID}/${ZOWE_KEYRING} -rfc \
            -storetype ${SERVICE_STORETYPE} -J-Djava.protocol.handler.pkgs=com.ibm.crypto.provider
    else
        echo "Generate keystore with the local CA private key and local CA public certificate:"
        pkeytool -genkeypair $V -alias ${LOCAL_CA_ALIAS} -keyalg RSA -keysize 2048 -keystore ${LOCAL_CA_FILENAME}.keystore.p12 \
            -dname "${LOCAL_CA_DNAME}" -keypass ${LOCAL_CA_PASSWORD} -storepass ${LOCAL_CA_PASSWORD} -storetype ${SERVICE_STORETYPE} -validity ${LOCAL_CA_VALIDITY} \
            -ext KeyUsage="keyCertSign" -ext BasicConstraints:"critical=ca:true"
        chmod 600 ${LOCAL_CA_FILENAME}.keystore.p12

        echo "Export local CA public certificate:"
        pkeytool -export $V -alias ${LOCAL_CA_ALIAS} -file ${LOCAL_CA_FILENAME}.cer -keystore ${LOCAL_CA_FILENAME}.keystore.p12 -rfc \
            -keypass ${LOCAL_CA_PASSWORD} -storepass ${LOCAL_CA_PASSWORD} -storetype ${SERVICE_STORETYPE}
    fi
    if [ `uname` = "OS/390" ]; then
        iconv -f ISO8859-1 -t IBM-1047 ${LOCAL_CA_FILENAME}.cer > ${LOCAL_CA_FILENAME}.cer-ebcdic
    fi
}

function add_external_ca {
    echo "Adding external Certificate Authorities:"
    if [ -n "${EXTERNAL_CA}" ]; then
        I=1
        for FILE in ${EXTERNAL_CA}; do
            cp -v ${FILE} ${EXTERNAL_CA_FILENAME}.${I}.cer
            I=$((I+1))
        done
        if [ `uname` = "OS/390" ]; then
            for FILENAME in ${EXTERNAL_CA_FILENAME}.*.cer; do
                iconv -f ISO8859-1 -t IBM-1047 ${FILENAME} > ${FILENAME}-ebcdic
            done
        fi
    fi
}

function create_service_certificate_and_csr {
    if [[ "${SERVICE_STORETYPE}" == "JCERACFKS" ]]; then
        echo "Generate service private key and service into the keyring:"
        pkeytool -genkeypair $V -alias ${SERVICE_ALIAS} -keyalg RSA -keysize 2048 -keystore safkeyring://${ZOWE_USERID}/${ZOWE_KEYRING} \
            -storetype ${SERVICE_STORETYPE} -dname "${SERVICE_DNAME}" -validity ${SERVICE_VALIDITY} -J-Djava.protocol.handler.pkgs=com.ibm.crypto.provider

        echo "Generate CSR for the service certificate in the keyring:"
        pkeytool -certreq $V -alias ${SERVICE_ALIAS} -keystore safkeyring://${ZOWE_USERID}/${ZOWE_KEYRING} -file ${SERVICE_KEYSTORE}.csr \
            -keyalg RSA -storetype ${SERVICE_STORETYPE} -dname "${SERVICE_DNAME}" -validity ${SERVICE_VALIDITY} -J-Djava.protocol.handler.pkgs=com.ibm.crypto.provider
    else
        if [ ! -e "${SERVICE_KEYSTORE}.p12" ];
        then
            echo "Generate service private key and service:"
            pkeytool -genkeypair $V -alias ${SERVICE_ALIAS} -keyalg RSA -keysize 2048 -keystore ${SERVICE_KEYSTORE}.p12 -keypass ${SERVICE_PASSWORD} -storepass ${SERVICE_PASSWORD} \
                -storetype ${SERVICE_STORETYPE} -dname "${SERVICE_DNAME}" -validity ${SERVICE_VALIDITY}

            echo "Generate CSR for the the service certificate:"
            pkeytool -certreq $V -alias ${SERVICE_ALIAS} -keystore ${SERVICE_KEYSTORE}.p12 -storepass ${SERVICE_PASSWORD} -file ${SERVICE_KEYSTORE}.csr \
                -keyalg RSA -storetype ${SERVICE_STORETYPE} -dname "${SERVICE_DNAME}" -validity ${SERVICE_VALIDITY}
        fi
    fi
}

function create_self_signed_service {
    if [ ! -e "${SERVICE_KEYSTORE}.p12" ];
    then
        echo "Generate service private key and service:"
        pkeytool -genkeypair $V -alias ${SERVICE_ALIAS} -keyalg RSA -keysize 2048 -keystore ${SERVICE_KEYSTORE}.p12 -keypass ${SERVICE_PASSWORD} -storepass ${SERVICE_PASSWORD} \
            -storetype PKCS12 -dname "${SERVICE_DNAME}" -validity ${SERVICE_VALIDITY} \
            -ext ${SERVICE_EXT} -ext KeyUsage:critical=keyEncipherment,digitalSignature,nonRepudiation,dataEncipherment -ext ExtendedKeyUsage=clientAuth,serverAuth
    fi
}

function sign_csr_using_local_ca {
     echo "Sign the CSR using the Certificate Authority:"
    if [[ "${SERVICE_STORETYPE}" == "JCERACFKS" ]]; then
        pkeytool -gencert $V -infile ${SERVICE_KEYSTORE}.csr -outfile ${SERVICE_KEYSTORE}_signed.cer -keystore safkeyring://${ZOWE_USERID}/${ZOWE_KEYRING} \
            -alias ${LOCAL_CA_ALIAS} -storetype ${SERVICE_STORETYPE} \
            -ext ${SERVICE_EXT} -ext KeyUsage:critical=keyEncipherment,digitalSignature,nonRepudiation,dataEncipherment -ext ExtendedKeyUsage=clientAuth,serverAuth -rfc \
            -validity ${SERVICE_VALIDITY} -J-Djava.protocol.handler.pkgs=com.ibm.crypto.provider
    else
        pkeytool -gencert $V -infile ${SERVICE_KEYSTORE}.csr -outfile ${SERVICE_KEYSTORE}_signed.cer -keystore ${LOCAL_CA_FILENAME}.keystore.p12 \
            -alias ${LOCAL_CA_ALIAS} -keypass ${LOCAL_CA_PASSWORD} -storepass ${LOCAL_CA_PASSWORD} -storetype ${SERVICE_STORETYPE} \
            -ext ${SERVICE_EXT} -ext KeyUsage:critical=keyEncipherment,digitalSignature,nonRepudiation,dataEncipherment -ext ExtendedKeyUsage=clientAuth,serverAuth -rfc \
            -validity ${SERVICE_VALIDITY}
    fi
}

function import_local_ca_certificate {
    if [[ "${SERVICE_STORETYPE}" == "PKCS12" ]]; then
        echo "Import the local Certificate Authority to the truststore:"
        pkeytool -importcert $V -trustcacerts -noprompt -file ${LOCAL_CA_FILENAME}.cer -alias ${LOCAL_CA_ALIAS} -keystore ${SERVICE_TRUSTSTORE}.p12 -storepass ${SERVICE_PASSWORD} -storetype ${SERVICE_STORETYPE}
    fi
}

function import_external_ca_certificates {
    if ls ${EXTERNAL_CA_FILENAME}.*.cer 1> /dev/null 2>&1; then
        echo "Import the external Certificate Authorities to the truststore:"
        I=1
        for FILENAME in ${EXTERNAL_CA_FILENAME}.*.cer; do
            [ -e "$FILENAME" ] || continue
            pkeytool -importcert $V -trustcacerts -noprompt -file ${FILENAME} -alias "extca${I}" -keystore ${SERVICE_TRUSTSTORE}.p12 -storepass ${SERVICE_PASSWORD} -storetype PKCS12
            I=$((I+1))
        done
    fi
}

function import_signed_certificate {
    if [[ "${SERVICE_STORETYPE}" == "JCERACFKS" ]]; then
        echo "Import the signed CSR to the keystore:"
        pkeytool -importcert $V -trustcacerts -noprompt -file ${SERVICE_KEYSTORE}_signed.cer -alias ${SERVICE_ALIAS} -keystore safkeyring://${ZOWE_USERID}/${ZOWE_KEYRING} -storetype ${SERVICE_STORETYPE} \
        -J-Djava.protocol.handler.pkgs=com.ibm.crypto.provider
    else
        echo "Import the Certificate Authority to the keystore:"
        pkeytool -importcert $V -trustcacerts -noprompt -file ${LOCAL_CA_FILENAME}.cer -alias ${LOCAL_CA_ALIAS} -keystore ${SERVICE_KEYSTORE}.p12 -storepass ${SERVICE_PASSWORD} -storetype ${SERVICE_STORETYPE}

        echo "Import the signed CSR to the keystore:"
        pkeytool -importcert $V -trustcacerts -noprompt -file ${SERVICE_KEYSTORE}_signed.cer -alias ${SERVICE_ALIAS} -keystore ${SERVICE_KEYSTORE}.p12 -storepass ${SERVICE_PASSWORD} -storetype ${SERVICE_STORETYPE}
    fi
}

function import_external_certificate {
    echo "Import the external Certificate Authorities to the keystore:"
    if ls ${EXTERNAL_CA_FILENAME}.*.cer 1> /dev/null 2>&1; then
        I=1
        for FILENAME in ${EXTERNAL_CA_FILENAME}.*.cer; do
            [ -e "$FILENAME" ] || continue
            pkeytool -importcert $V -trustcacerts -noprompt -file ${FILENAME} -alias "extca${I}" -keystore ${SERVICE_KEYSTORE}.p12 -storepass ${SERVICE_PASSWORD} -storetype PKCS12
            I=$((I+1))
        done
    fi

    if [ -n "${EXTERNAL_CERTIFICATE}" ]; then
        if [[ "${SERVICE_STORETYPE}" == "JCERACFKS" ]]; then
            echo "Import the signed certificate and its private key to the keyring:"
            pkeytool -importkeystore $V -destkeystore safkeyring://${ZOWE_USERID}/${ZOWE_KEYRING} -deststoretype ${SERVICE_STORETYPE} -destalias ${SERVICE_ALIAS} \
              -srckeystore ${EXTERNAL_CERTIFICATE} -srcstoretype PKCS12 -srcstorepass ${SERVICE_PASSWORD} -srcalias ${EXTERNAL_CERTIFICATE_ALIAS} \
              -J-Djava.protocol.handler.pkgs=com.ibm.crypto.provider
        else
            echo "Import the signed certificate and its private key to the keystore:"
            pkeytool -importkeystore $V -deststorepass ${SERVICE_PASSWORD} -destkeypass ${SERVICE_PASSWORD} -destkeystore ${SERVICE_KEYSTORE}.p12 -deststoretype ${SERVICE_STORETYPE} -destalias ${SERVICE_ALIAS} \
              -srckeystore ${EXTERNAL_CERTIFICATE} -srcstoretype PKCS12 -srcstorepass ${SERVICE_PASSWORD} -keypass ${SERVICE_PASSWORD} -srcalias ${EXTERNAL_CERTIFICATE_ALIAS}
        fi
    fi
}

function export_service_certificate {
    echo "Export service certificate to the PEM format"
    if [[ "${SERVICE_STORETYPE}" == "PKCS12" ]]; then
        pkeytool -exportcert -alias ${SERVICE_ALIAS} -keystore ${SERVICE_KEYSTORE}.p12 -storetype ${SERVICE_STORETYPE} -storepass ${SERVICE_PASSWORD} -rfc -file ${SERVICE_KEYSTORE}.cer
        if [ `uname` = "OS/390" ]; then
          iconv -f ISO8859-1 -t IBM-1047 ${SERVICE_KEYSTORE}.cer > ${SERVICE_KEYSTORE}.cer-ebcdic
        fi
    fi
}

function export_service_private_key {
    echo "Exporting service private key"
    echo "TEMP_DIR=$TEMP_DIR"
    cat <<EOF >$TEMP_DIR/ExportPrivateKey.java

import java.io.File;
import java.io.FileInputStream;
import java.io.FileWriter;
import java.security.Key;
import java.security.KeyStore;
import java.util.Base64;
import com.ibm.crypto.provider.RACFInputStream;

public class ExportPrivateKey {
    private String keystoreName;
    private String keyStoreType;
    private char[] keyStorePassword;
    private char[] keyPassword;
    private String alias;
    private File exportedFile;

    public void export() throws Exception {
        KeyStore keystore = KeyStore.getInstance(keyStoreType);
        if ("JCERACFKS".equalsIgnoreCase(keyStoreType)) {
            String splits[] = keystoreName.replaceFirst("safkeyring://", "").split("/");
            keystore.load(new RACFInputStream(splits[0], splits[1], keyStorePassword), keyStorePassword);

        } else {
            keystore.load(new FileInputStream(new File(keystoreName)), keyStorePassword);
        }
        Key key = keystore.getKey(alias, keyPassword);
        String encoded = Base64.getEncoder().encodeToString(key.getEncoded());
        FileWriter fw = new FileWriter(exportedFile);
        fw.write("-----BEGIN PRIVATE KEY-----");
        for (int i = 0; i < encoded.length(); i++) {
            if (((i % 64) == 0) && (i != (encoded.length() - 1))) {
                fw.write("\n");
            }
            fw.write(encoded.charAt(i));
        }
        fw.write("\n");
        fw.write("-----END PRIVATE KEY-----\n");
        fw.close();
    }

    public static void main(String args[]) throws Exception {
        ExportPrivateKey export = new ExportPrivateKey();
        export.keystoreName = args[0];
        export.keyStoreType = args[1];
        export.keyStorePassword = args[2].toCharArray();
        export.alias = args[3];
        export.keyPassword = args[4].toCharArray();
        export.exportedFile = new File(args[5]);
        export.export();
    }
}
EOF
    echo "cat returned $?"
    javac ${TEMP_DIR}/ExportPrivateKey.java
    echo "javac returned $?"
    if [[ "${SERVICE_STORETYPE}" == "PKCS12" ]]; then
        java -cp ${TEMP_DIR} ExportPrivateKey ${SERVICE_KEYSTORE}.p12 ${SERVICE_STORETYPE} ${SERVICE_PASSWORD} ${SERVICE_ALIAS} ${SERVICE_PASSWORD} ${SERVICE_KEYSTORE}.key
    fi
    echo "java returned $?"
    rm ${TEMP_DIR}/ExportPrivateKey.java ${TEMP_DIR}/ExportPrivateKey.class
}

function setup_local_ca {
    clean_local_ca
    create_certificate_authority
    add_external_ca
    echo "Listing generated files for local CA:"
    ls -l ${LOCAL_CA_FILENAME}*
}

function new_service_csr {
    clean_service
    create_service_certificate_and_csr
    echo "Listing generated files for service:"
    if [[ "${SERVICE_STORETYPE}" != "JCERACFKS" ]]; then
        ls -l ${SERVICE_KEYSTORE}* ${SERVICE_TRUSTSTORE}*
    fi
}

function new_service {
    clean_service
    if [ -n "${EXTERNAL_CERTIFICATE}" ]; then
        import_external_certificate
    else
        create_service_certificate_and_csr
        sign_csr_using_local_ca
        import_signed_certificate
    fi
    import_local_ca_certificate
    import_external_ca_certificates
    export_service_certificate
    export_service_private_key
    echo "Listing generated files for service:"
    if [[ "${SERVICE_STORETYPE}" != "JCERACFKS" ]]; then
        ls -l ${SERVICE_KEYSTORE}* ${SERVICE_TRUSTSTORE}*
    fi
}

function new_self_signed_service {
    clean_service
    create_self_signed_service
    import_local_ca_certificate
    export_service_certificate
    export_service_private_key
    echo "Listing generated files for self-signed service:"
    ls -l ${SERVICE_KEYSTORE}*
}

function trust {
    echo "Import a certificate to the truststore:"
    pkeytool -importcert $V -trustcacerts -noprompt -file ${CERTIFICATE} -alias "${ALIAS}" -keystore ${SERVICE_TRUSTSTORE}.p12 -storepass ${SERVICE_PASSWORD} -storetype PKCS12

    if [[ "${SERVICE_STORETYPE}" == "JCERACFKS" ]] && [[ "${GENERATE_CERTS_FOR_KEYRING}" != "false" ]]; then
        keytool -importcert $V -trustcacerts -noprompt -file ${CERTIFICATE} -alias "${ALIAS}" -keystore safkeyring://${ZOWE_USERID}/${ZOWE_KEYRING} -storetype ${SERVICE_STORETYPE} \
            -J-Djava.protocol.handler.pkgs=com.ibm.crypto.provider
    fi
}

function jwt_key_gen_and_export {
    echo "Generates key pair for JWT token secret and exports the public key"
    if [[ "${SERVICE_STORETYPE}" == "JCERACFKS" ]]; then
        pkeytool -genkeypair $V -alias ${JWT_ALIAS} -keyalg RSA -keysize 2048 -keystore safkeyring://${ZOWE_USERID}/${ZOWE_KEYRING} \
          -dname "${SERVICE_DNAME}" -storetype ${SERVICE_STORETYPE} -validity ${SERVICE_VALIDITY} -J-Djava.protocol.handler.pkgs=com.ibm.crypto.provider
        export_jwt_from_keyring
    else
        pkeytool -genkeypair $V -alias ${JWT_ALIAS} -keyalg RSA -keysize 2048 -keystore ${SERVICE_KEYSTORE}.p12 \
        -dname "${SERVICE_DNAME}" -keypass ${SERVICE_PASSWORD} -storepass ${SERVICE_PASSWORD} -storetype ${SERVICE_STORETYPE} -validity ${SERVICE_VALIDITY}
        pkeytool -export -rfc -alias ${JWT_ALIAS} -keystore ${SERVICE_KEYSTORE}.p12 -storepass ${SERVICE_PASSWORD} -keypass ${SERVICE_PASSWORD} -storetype ${SERVICE_STORETYPE} \
        -file ${SERVICE_KEYSTORE}.${JWT_ALIAS}.pem
    fi
}

function export_jwt_from_keyring {
        pkeytool -export -rfc -alias ${JWT_ALIAS} -keystore safkeyring://${ZOWE_USERID}/${ZOWE_KEYRING} -storetype ${SERVICE_STORETYPE} \
          -file ${SERVICE_KEYSTORE}.${JWT_ALIAS}.pem -J-Djava.protocol.handler.pkgs=com.ibm.crypto.provider
}

function zosmf_jwt_public_key {
    echo "Retrieves z/OSMF JWT public key and stores it to ${SERVICE_KEYSTORE}.${JWT_ALIAS}.pem"
    java -Xms16m -Xmx32m -Xquickstart \
        -Dfile.encoding=UTF-8 \
        -Djava.io.tmpdir=${TEMP_DIR} \
        -Dapiml.security.ssl.verifySslCertificatesOfServices=${VERIFY_CERTIFICATES} \
        -Dserver.ssl.trustStore=${SERVICE_TRUSTSTORE}.p12 \
        -Dserver.ssl.trustStoreType=PKCS12 \
        -Dserver.ssl.trustStorePassword=${SERVICE_PASSWORD} \
        -Djava.protocol.handler.pkgs=com.ibm.crypto.provider \
        -cp ${BASE_DIR}/../components/api-mediation/gateway-service.jar \
        -Dloader.main=org.zowe.apiml.gateway.security.login.zosmf.SaveZosmfPublicKeyConsoleApplication \
        org.springframework.boot.loader.PropertiesLauncher \
        https://${ZOWE_ZOSMF_HOST}:${ZOWE_ZOSMF_PORT} ${SERVICE_KEYSTORE}.${JWT_ALIAS}.pem "${LOCAL_CA_ALIAS}" \
        ${LOCAL_CA_FILENAME}.keystore.p12 PKCS12 ${LOCAL_CA_PASSWORD} ${LOCAL_CA_PASSWORD}
}

function trust_zosmf {
  echo ${ZOSMF_CERTIFICATE}
  if [[ -z "${ZOSMF_CERTIFICATE}" ]]; then
    echo "Getting certificates from z/OSMF host"
    CER_DIR=`dirname ${SERVICE_TRUSTSTORE}`/temp
    TEMP_CERT_FILE=temp-zosmf-cert
    rm -rf CER_DIR=`dirname ${SERVICE_TRUSTSTORE}`/temp &> /dev/null
    mkdir -p $CER_DIR
    ALIAS="zosmf"

    KEYTOOL_COMMAND="-printcert -sslserver ${ZOWE_ZOSMF_HOST}:${ZOWE_ZOSMF_PORT} -J-Dfile.encoding=UTF8"
    # Check that the keytool command is okay and remote connection works. It prints out error messages
    # and ends the program if an error occurs.
    pkeytool ${KEYTOOL_COMMAND} -rfc

    # First, print out ZOSMF certificates fingerprints for a user to check
    # We call keytool directly because the pkeytool messes the output that we want to display
    if [[ "$LOG" != "" ]]; then
      echo "z/OSMF certificate fingerprint:" >&5
      keytool ${KEYTOOL_COMMAND} | grep -e 'Owner:' -e 'SHA1:' -e 'SHA256:' -e 'MD5' >&5
    else
      echo "z/OSMF certificate fingerprint:"
      keytool ${KEYTOOL_COMMAND} | grep -e 'Owner:' -e 'SHA1:' -e 'SHA256:' -e 'MD5'
    fi
    # keytool should work here but we check RC just in case
    echo "z/OSMF certificate fingerprint: keytool returned: $RC"
    RC=$?
    if [ "$RC" -ne "0" ]; then
        exit 1
    fi

    # We call keytool directly because the pkeytool messes the output that we need to parse afterwards
    keytool ${KEYTOOL_COMMAND} -rfc > ${CER_DIR}/${TEMP_CERT_FILE}
    # keytool should work now but we check RC just in case
    RC=$?
    echo "z/OSMF certificate to temp file: keytool returned: $RC"
    if [ "$RC" -ne "0" ]; then
        exit 1
    fi
    # parse keytool output into separate files
    csplit -s -k -f ${CER_DIR}/${ALIAS} ${CER_DIR}/${TEMP_CERT_FILE} /-----END\ CERTIFICATE-----/1 \
      {$(expr `grep -c -e '-----END CERTIFICATE-----' ${CER_DIR}/${TEMP_CERT_FILE}` - 1)}
    for entry in ${CER_DIR}/${ALIAS}*; do
      [ -e "$entry" ] || continue
      CERTIFICATE=${entry}
      entry=${entry##*/}
      ALIAS=${entry%.cer}
      trust
    done

    # clean up temporary files
    rm -rf ${CER_DIR}
  else
    echo "Getting zosmf certificates from file"
    for entry in ${ZOSMF_CERTIFICATE}; do
      CERTIFICATE=${entry}
      entry=${entry##*/}
      ALIAS=${entry%.*}
      trust
    done
  fi
}

function toUpperCase {
    echo $1 | tr '[:lower:]' '[:upper:]'
}

while [ "$1" != "" ]; do
    case $1 in
        -a | --action )         shift
                                ACTION=$1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        -v | --verbose )        V="-v"
                                ;;
        --local-ca-alias )      shift
                                LOCAL_CA_ALIAS=$1
                                ;;
        --log )                 shift
                                export LOG=$1
                                exec 5>&1 >>$LOG
                                ;;
        --local-ca-filename )   shift
                                LOCAL_CA_FILENAME=$1
                                ;;
        --local-ca-dname )      shift
                                LOCAL_CA_DNAME=$1
                                ;;
        --local-ca-password )   shift
                                LOCAL_CA_PASSWORD=$1
                                ;;
        --local-ca-validity )   shift
                                LOCAL_CA_VALIDITY=$1
                                ;;
        --service-alias )       shift
                                SERVICE_ALIAS=$1
                                ;;
        --jwt-alias )           shift
                                JWT_ALIAS=$1
                                ;;
        --service-ext )         shift
                                SERVICE_EXT=$1
                                ;;
        --service-keystore )    shift
                                SERVICE_KEYSTORE=$1
                                ;;
        --service-truststore )  shift
                                SERVICE_TRUSTSTORE=$1
                                ;;
        --service-storetype )  shift
                                SERVICE_STORETYPE=`toUpperCase $1`
                                ;;
        --service-dname )       shift
                                SERVICE_DNAME=$1
                                ;;
        --service-password )    shift
                                SERVICE_PASSWORD=$1
                                ;;
        --service-validity )    shift
                                SERVICE_VALIDITY=$1
                                ;;
        --external-certificate ) shift
                                EXTERNAL_CERTIFICATE=$1
                                ;;
        --external-certificate-alias ) shift
                                EXTERNAL_CERTIFICATE_ALIAS=$1
                                ;;
        --external-ca )         shift
                                EXTERNAL_CA="${EXTERNAL_CA} $1"
                                ;;
        --external-ca-filename ) shift
                                EXTERNAL_CA_FILENAME=$1
                                ;;
        --zosmf-certificate )   shift
                                ZOSMF_CERTIFICATE=$1
                                ;;
        --zowe-keyring )       shift
                                ZOWE_KEYRING=$1
                                ;;
        --zowe-userid )        shift
                                ZOWE_USERID=$1
                                ;;
        --certificate )         shift
                                CERTIFICATE=$1
                                ;;
        --alias )               shift
                                ALIAS=$1
                                ;;
        * )                     echo "Unexpected parameter: $1"
                                usage
                                exit 1
    esac
    shift
done

case $ACTION in
    clean)
        clean_keyring
        clean_local_ca
        clean_service
        ;;
    setup)
        clean_keyring
        setup_local_ca
        new_service
        jwt_key_gen_and_export
        ;;
    add-external-ca)
        add_external_ca
        ;;
    new-service-csr)
        new_service_csr
        ;;
    new-service)
        new_service
        ;;
    jwt-keygen)
        jwt_key_gen_and_export
        ;;
    new-self-signed-service)
        new_self_signed_service
        ;;
    trust)
        trust
        ;;
    trust-zosmf)
        trust_zosmf
        if [[ "${SERVICE_STORETYPE}" == "JCERACFKS" ]] && [[ "${GENERATE_CERTS_FOR_KEYRING}" == "false" ]]; then
          export_jwt_from_keyring
        fi
        zosmf_jwt_public_key
        ;;
    cert-key-export)
        export_service_certificate
        export_service_private_key
        ;;
    *)
        usage
        exit 1
esac
