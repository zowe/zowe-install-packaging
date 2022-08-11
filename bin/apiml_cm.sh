#!/bin/sh

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

#
# APIML Certificate Management
# ============================
#
# User guide: https://github.com/zowe/docs-site/blob/apiml-https/docs/guides/api-mediation-security.md
#
# IBM Java keytool documentation:
# https://www.ibm.com/support/knowledgecenter/en/SSYKE2_8.0.0/com.ibm.java.security.component.80.doc/security-component/keytoolDocs/keytool_overview.html
#

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
    echo "     - trust-keyring - adds a public certificate of a service to APIML keyring"
    echo "     - clean - removes files created by setup"
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
SERVICE_PASSWORD="password"
SERVICE_KEYSTORE="keystore/localhost/localhost.keystore"
SERVICE_TRUSTSTORE="keystore/localhost/localhost.truststore"
SERVICE_DNAME="CN=Zowe Service, OU=API Mediation Layer, O=Zowe Sample, L=Prague, S=Prague, C=CZ"
COMPONENT_DNAME="CN=Zowe Service - {component}, OU=API Mediation Layer, O=Zowe Sample, L=Prague, S=Prague, C=CZ"
SERVICE_EXT="SAN=dns:localhost.localdomain,dns:localhost"
SERVICE_VALIDITY=3650
SERVICE_STORETYPE="PKCS12"
EXTERNAL_CERTIFICATE=
EXTERNAL_CERTIFICATE_ALIAS=
COMPONENT_LEVEL_CERTIFICATES=
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
    echo "> Calling keytool $ARGS"
    if [ "$LOG" != "" ]; then
        keytool "$@" >> $LOG 2>&1
    else
        keytool "$@"
    fi
    RC=$?
    echo "< keytool returned: $RC"
    if [ "$RC" -ne "0" ]; then
        exit 1
    fi
}

function clean_keyring {
    if [[ "${SERVICE_STORETYPE}" == "JCERACFKS" ]]; then
        KEYRING_UTIL="${BASE_DIR}/utils/keyring-util/keyring-util"
        chmod +x $KEYRING_UTIL
        echo ">>>> Removing ${ZOWE_USERID}/${ZOWE_KEYRING} keyring"
        "${KEYRING_UTIL}" delring "${ZOWE_USERID}" "${ZOWE_KEYRING}"
    fi
}

function clean_local_ca {
    rm -f "${LOCAL_CA_FILENAME}.keystore.p12" "${LOCAL_CA_FILENAME}.cer"
    if [[ "${SERVICE_STORETYPE}" == "JCERACFKS" ]]; then
        KEYRING_UTIL="${BASE_DIR}/utils/keyring-util/keyring-util"
        chmod +x "${KEYRING_UTIL}"
        echo ">>>> Disconnecting ${LOCAL_CA_ALIAS} certificate from the ${ZOWE_KEYRING} keyring"
        "${KEYRING_UTIL}" delcert "${ZOWE_USERID}" "${ZOWE_KEYRING}" "${LOCAL_CA_ALIAS}"
        echo ">>>> Removing ${LOCAL_CA_ALIAS} certificate from RACF database"
        "${KEYRING_UTIL}" delcert "${ZOWE_USERID}" "*" "${LOCAL_CA_ALIAS}"
    fi
}

function clean_service {
    rm -f "${SERVICE_KEYSTORE}.p12" "${SERVICE_KEYSTORE}.csr" "${SERVICE_KEYSTORE}_signed.cer" "${SERVICE_TRUSTSTORE}.p12"
    if [[ "${SERVICE_STORETYPE}" == "JCERACFKS" ]]; then
        KEYRING_UTIL="${BASE_DIR}/utils/keyring-util/keyring-util"
        chmod +x "${KEYRING_UTIL}"
        echo ">>>> Disconnecting ${SERVICE_ALIAS} certificate from the ${ZOWE_KEYRING} keyring"
        "${KEYRING_UTIL}" delcert "${ZOWE_USERID}" "${ZOWE_KEYRING}" "${SERVICE_ALIAS}"
        echo ">>>> Removing ${SERVICE_ALIAS} certificate from RACF database"
        "${KEYRING_UTIL}" delcert "${ZOWE_USERID}" "*" "${SERVICE_ALIAS}"
    fi
}

function create_certificate_authority {
    if [[ "${SERVICE_STORETYPE}" == "JCERACFKS" ]]; then
        echo ">>>> Generate keyring with the local CA private key and local CA public certificate:"
        pkeytool -genkeypair $V -alias "${LOCAL_CA_ALIAS}" -keyalg RSA -keysize 2048 -keystore "safkeyring://${ZOWE_USERID}/${ZOWE_KEYRING}" \
            -dname "${LOCAL_CA_DNAME}" -storetype "${SERVICE_STORETYPE}" -validity "${LOCAL_CA_VALIDITY}" \
            -ext KeyUsage="keyCertSign" -ext BasicConstraints:"critical=ca:true" -J-Djava.protocol.handler.pkgs=com.ibm.crypto.provider
    else
        echo ">>>> Generate keystore with the local CA private key and local CA public certificate:"
        pkeytool -genkeypair $V -alias "${LOCAL_CA_ALIAS}" -keyalg RSA -keysize 2048 -keystore "${LOCAL_CA_FILENAME}.keystore.p12" \
            -dname "${LOCAL_CA_DNAME}" -keypass "${LOCAL_CA_PASSWORD}" -storepass "${LOCAL_CA_PASSWORD}" -storetype ${SERVICE_STORETYPE} -validity ${LOCAL_CA_VALIDITY} \
            -ext KeyUsage="keyCertSign" -ext BasicConstraints:"critical=ca:true"
        chmod 600 "${LOCAL_CA_FILENAME}.keystore.p12"

        echo ">>>> Export local CA public certificate:"
        pkeytool -export $V -alias "${LOCAL_CA_ALIAS}" -file "${LOCAL_CA_FILENAME}.cer" -keystore "${LOCAL_CA_FILENAME}.keystore.p12" -rfc \
            -keypass "${LOCAL_CA_PASSWORD}" -storepass "${LOCAL_CA_PASSWORD}" -storetype ${SERVICE_STORETYPE}
    fi
    if [ `uname` = "OS/390" ]; then
        iconv -f ISO8859-1 -t IBM-1047 "${LOCAL_CA_FILENAME}.cer" > "${LOCAL_CA_FILENAME}.cer-ebcdic"
    fi
}

function add_external_ca {
    echo ">>>> Adding external Certificate Authorities:"
    if [ -n "${EXTERNAL_CA}" ]; then
        I=1
        for FILE in ${EXTERNAL_CA}; do
            cp -v "${FILE}" "${EXTERNAL_CA_FILENAME}.${I}.cer"
            I=$((I+1))
        done
        if [ `uname` = "OS/390" ]; then
            for FILENAME in "${EXTERNAL_CA_FILENAME}".*.cer; do
                iconv -f ISO8859-1 -t IBM-1047 "${FILENAME}" > "${FILENAME}-ebcdic"
            done
        fi
    fi
}

function create_service_certificate_and_csr {
    export_file_id=$1
    if [ -z "${export_file_id}" ]; then
      target_file="${SERVICE_KEYSTORE}"
    else
      target_file="${SERVICE_KEYSTORE}.${export_file_id}"
    fi

    if [[ "${SERVICE_STORETYPE}" == "JCERACFKS" ]]; then
        echo ">>>> Generate service private key and service into the keyring:"
        pkeytool -genkeypair $V -alias "${SERVICE_ALIAS}" -keyalg RSA -keysize 2048 -keystore "safkeyring://${ZOWE_USERID}/${ZOWE_KEYRING}" \
            -storetype ${SERVICE_STORETYPE} -dname "${SERVICE_DNAME}" -validity ${SERVICE_VALIDITY} -J-Djava.protocol.handler.pkgs=com.ibm.crypto.provider

        echo ">>>> Generate CSR for the service certificate in the keyring:"
        pkeytool -certreq $V -alias "${SERVICE_ALIAS}" -keystore "safkeyring://${ZOWE_USERID}/${ZOWE_KEYRING}" -file "${SERVICE_KEYSTORE}.csr" \
            -keyalg RSA -storetype ${SERVICE_STORETYPE} -dname "${SERVICE_DNAME}" -validity ${SERVICE_VALIDITY} -J-Djava.protocol.handler.pkgs=com.ibm.crypto.provider
    else
        if [ -n "${export_file_id}" -o ! -e "${SERVICE_KEYSTORE}.p12" ];
        then
            echo ">>>> Generate service private key and service:"
            pkeytool -genkeypair $V -alias "${SERVICE_ALIAS}" -keyalg RSA -keysize 2048 -keystore "${SERVICE_KEYSTORE}.p12" -keypass "${SERVICE_PASSWORD}" -storepass "${SERVICE_PASSWORD}" \
                -storetype ${SERVICE_STORETYPE} -dname "${SERVICE_DNAME}" -validity ${SERVICE_VALIDITY}

            echo ">>>> Generate CSR for the the service certificate:"
            pkeytool -certreq $V -alias "${SERVICE_ALIAS}" -keystore "${SERVICE_KEYSTORE}.p12" -storepass "${SERVICE_PASSWORD}" -file "${target_file}.csr" \
                -keyalg RSA -storetype ${SERVICE_STORETYPE} -dname "${SERVICE_DNAME}" -validity ${SERVICE_VALIDITY}
        fi
    fi
}

function create_self_signed_service {
    if [ ! -e "${SERVICE_KEYSTORE}.p12" ];
    then
        echo ">>>> Generate service private key and service:"
        pkeytool -genkeypair $V -alias "${SERVICE_ALIAS}" -keyalg RSA -keysize 2048 -keystore "${SERVICE_KEYSTORE}.p12" -keypass "${SERVICE_PASSWORD}" -storepass "${SERVICE_PASSWORD}" \
            -storetype PKCS12 -dname "${SERVICE_DNAME}" -validity ${SERVICE_VALIDITY} \
            -ext "${SERVICE_EXT}" -ext KeyUsage:critical=keyEncipherment,digitalSignature,nonRepudiation,dataEncipherment -ext ExtendedKeyUsage=clientAuth,serverAuth
    fi
}

function sign_csr_using_local_ca {
    export_file_id=$1
    if [ -z "${export_file_id}" ]; then
      target_file="${SERVICE_KEYSTORE}"
    else
      target_file="${SERVICE_KEYSTORE}.${export_file_id}"
    fi

     echo ">>>> Sign the CSR using the Certificate Authority:"
    if [[ "${SERVICE_STORETYPE}" == "JCERACFKS" ]]; then
        pkeytool -gencert $V -infile "${target_file}.csr" -outfile "${target_file}_signed.cer" -keystore "safkeyring://${ZOWE_USERID}/${ZOWE_KEYRING}" \
            -alias "${LOCAL_CA_ALIAS}" -storetype ${SERVICE_STORETYPE} \
            -ext "${SERVICE_EXT}" -ext KeyUsage:critical=keyEncipherment,digitalSignature,nonRepudiation,dataEncipherment -ext ExtendedKeyUsage=clientAuth,serverAuth -rfc \
            -validity ${SERVICE_VALIDITY} -J-Djava.protocol.handler.pkgs=com.ibm.crypto.provider
    else
        pkeytool -gencert $V -infile "${target_file}.csr" -outfile "${target_file}_signed.cer" -keystore "${LOCAL_CA_FILENAME}.keystore.p12" \
            -alias "${LOCAL_CA_ALIAS}" -keypass "${LOCAL_CA_PASSWORD}" -storepass "${LOCAL_CA_PASSWORD}" -storetype ${SERVICE_STORETYPE} \
            -ext "${SERVICE_EXT}" -ext KeyUsage:critical=keyEncipherment,digitalSignature,nonRepudiation,dataEncipherment -ext ExtendedKeyUsage=clientAuth,serverAuth -rfc \
            -validity ${SERVICE_VALIDITY}
    fi
}

function import_local_ca_certificate {
    if [[ "${SERVICE_STORETYPE}" == "PKCS12" ]]; then
        echo ">>>> Import the local Certificate Authority to the truststore:"
        pkeytool -importcert $V -trustcacerts -noprompt -file "${LOCAL_CA_FILENAME}.cer" -alias "${LOCAL_CA_ALIAS}" -keystore "${SERVICE_TRUSTSTORE}.p12" -storepass "${SERVICE_PASSWORD}" -storetype ${SERVICE_STORETYPE}
    fi
}

function import_external_ca_certificates {
    if ls "${EXTERNAL_CA_FILENAME}".*.cer 1> /dev/null 2>&1; then
        echo ">>>> Import the external Certificate Authorities to the truststore:"
        I=1
        for FILENAME in "${EXTERNAL_CA_FILENAME}".*.cer; do
            [ -e "$FILENAME" ] || continue
            pkeytool -importcert $V -trustcacerts -noprompt -file "${FILENAME}" -alias "extca${I}" -keystore "${SERVICE_TRUSTSTORE}.p12" -storepass "${SERVICE_PASSWORD}" -storetype PKCS12
            I=$((I+1))
        done
    fi
}

function import_signed_certificate {
    export_file_id=$1
    if [ -z "${export_file_id}" ]; then
      target_file="${SERVICE_KEYSTORE}"
    else
      target_file="${SERVICE_KEYSTORE}.${export_file_id}"
    fi

    if [[ "${SERVICE_STORETYPE}" == "JCERACFKS" ]]; then
        echo ">>>> Import the signed CSR to the keystore:"
        pkeytool -importcert $V -trustcacerts -noprompt -file "${target_file}_signed.cer" -alias "${SERVICE_ALIAS}" -keystore "safkeyring://${ZOWE_USERID}/${ZOWE_KEYRING}" -storetype ${SERVICE_STORETYPE} \
        -J-Djava.protocol.handler.pkgs=com.ibm.crypto.provider
    else

        keytool -v -list -noprompt -alias "${LOCAL_CA_ALIAS}" -keystore "${SERVICE_KEYSTORE}.p12" -storepass "${SERVICE_PASSWORD}" -storetype ${SERVICE_STORETYPE} >/dev/null 2>/dev/null
        if [ "$?" != "0" ]; then
            echo ">>>> Import the Certificate Authority to the keystore:"
            pkeytool -importcert $V -trustcacerts -noprompt -file "${LOCAL_CA_FILENAME}.cer" -alias "${LOCAL_CA_ALIAS}" -keystore "${SERVICE_KEYSTORE}.p12" -storepass "${SERVICE_PASSWORD}" -storetype ${SERVICE_STORETYPE}
        fi

        echo ">>>> Import the signed CSR to the keystore:"
        pkeytool -importcert $V -trustcacerts -noprompt -file "${target_file}_signed.cer" -alias "${SERVICE_ALIAS}" -keystore "${SERVICE_KEYSTORE}.p12" -storepass "${SERVICE_PASSWORD}" -storetype ${SERVICE_STORETYPE}
    fi
}

function import_external_certificate {
    echo ">>>> Import the external Certificate Authorities to the keystore:"
    if ls "${EXTERNAL_CA_FILENAME}".*.cer 1> /dev/null 2>&1; then
        I=1
        for FILENAME in "${EXTERNAL_CA_FILENAME}".*.cer; do
            [ -e "$FILENAME" ] || continue
            pkeytool -importcert $V -trustcacerts -noprompt -file "${FILENAME}" -alias "extca${I}" -keystore "${SERVICE_KEYSTORE}.p12" -storepass "${SERVICE_PASSWORD}" -storetype PKCS12
            I=$((I+1))
        done
    fi

    if [ -n "${EXTERNAL_CERTIFICATE}" ]; then
        if [[ "${SERVICE_STORETYPE}" == "JCERACFKS" ]]; then
            echo ">>>> Import the signed certificate and its private key to the keyring:"
            pkeytool -importkeystore $V -destkeystore "safkeyring://${ZOWE_USERID}/${ZOWE_KEYRING}" -deststoretype ${SERVICE_STORETYPE} -destalias "${SERVICE_ALIAS}" \
              -srckeystore "${EXTERNAL_CERTIFICATE}" -srcstoretype PKCS12 -srcstorepass "${SERVICE_PASSWORD}" -srcalias "${EXTERNAL_CERTIFICATE_ALIAS}" \
              -J-Djava.protocol.handler.pkgs=com.ibm.crypto.provider
        else
            echo ">>>> Import the signed certificate and its private key to the keystore:"
            pkeytool -importkeystore $V -deststorepass "${SERVICE_PASSWORD}" -destkeypass "${SERVICE_PASSWORD}" -destkeystore "${SERVICE_KEYSTORE}.p12" -deststoretype ${SERVICE_STORETYPE} -destalias "${SERVICE_ALIAS}" \
              -srckeystore "${EXTERNAL_CERTIFICATE}" -srcstoretype PKCS12 -srcstorepass "${SERVICE_PASSWORD}" -keypass "${SERVICE_PASSWORD}" -srcalias "${EXTERNAL_CERTIFICATE_ALIAS}"
        fi
    fi
}

function export_service_certificate {
    export_file_id=$1
    if [ -z "${export_file_id}" ]; then
      target_file="${SERVICE_KEYSTORE}"
    else
      target_file="${SERVICE_KEYSTORE}.${export_file_id}"
    fi

    echo ">>>> Export service certificate to the PEM format"
    if [[ "${SERVICE_STORETYPE}" == "PKCS12" ]]; then
        pkeytool -exportcert -alias "${SERVICE_ALIAS}" -keystore "${SERVICE_KEYSTORE}.p12" -storetype ${SERVICE_STORETYPE} -storepass "${SERVICE_PASSWORD}" -rfc -file "${target_file}.cer"
        if [ `uname` = "OS/390" ]; then
          iconv -f ISO8859-1 -t IBM-1047 "${target_file}.cer" > "${target_file}.cer-ebcdic"
        fi
    fi
}

function import_external_certificate_to_truststore {
    if [[ -n "${EXTERNAL_CERTIFICATE}" ]] && [[ "${SERVICE_STORETYPE}" == "PKCS12" ]]; then
        echo ">>>> Import external certificate to the truststore"
        CERTIFICATE="${SERVICE_KEYSTORE}.cer"
        ALIAS=extca0
        trust
    fi
}

# This check/code duplication is due to com.ibm.crypto.provider being need for z/os keyring support and
# does not exist on other operating systems and will fail in docker or in development environments.
# And Java does not support conditional import.
function export_service_private_key {
    export_file_id=$1
    if [ -z "${export_file_id}" ]; then
      target_file="${SERVICE_KEYSTORE}"
    else
      target_file="${SERVICE_KEYSTORE}.${export_file_id}"
    fi

    echo ">>>> Exporting service private key"
    echo "TEMP_DIR=$TEMP_DIR"

    if [ `uname` = "OS/390" ]; then
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
    else
        cat <<EOF >$TEMP_DIR/ExportPrivateKey.java

import java.io.File;
import java.io.FileInputStream;
import java.io.FileWriter;
import java.security.Key;
import java.security.KeyStore;
import java.util.Base64;

public class ExportPrivateKey {
    private File keystoreFile;
    private String keyStoreType;
    private char[] keyStorePassword;
    private char[] keyPassword;
    private String alias;
    private File exportedFile;

    public void export() throws Exception {
        KeyStore keystore = KeyStore.getInstance(keyStoreType);
        keystore.load(new FileInputStream(keystoreFile), keyStorePassword);
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
        export.keystoreFile = new File(args[0]);
        export.keyStoreType = args[1];
        export.keyStorePassword = args[2].toCharArray();
        export.alias = args[3];
        export.keyPassword = args[4].toCharArray();
        export.exportedFile = new File(args[5]);
        export.export();
    }
}
EOF
    fi
    echo "< cat returned $?"
    javac "${TEMP_DIR}/ExportPrivateKey.java"
    echo "< javac returned $?"
    if [ `uname` = "OS/390" ]; then
        if [[ "${SERVICE_STORETYPE}" == "PKCS12" ]]; then
            java -cp "${TEMP_DIR}" ExportPrivateKey "${SERVICE_KEYSTORE}.p12" ${SERVICE_STORETYPE} "${SERVICE_PASSWORD}" "${SERVICE_ALIAS}" "${SERVICE_PASSWORD}" "${target_file}.key"
        fi
    else
        java -cp "${TEMP_DIR}" ExportPrivateKey "${SERVICE_KEYSTORE}.p12" PKCS12 "${SERVICE_PASSWORD}" "${SERVICE_ALIAS}" "${SERVICE_PASSWORD}" "${target_file}.key"
    fi
    echo "< java returned $?"
    rm "${TEMP_DIR}/ExportPrivateKey.java" "${TEMP_DIR}/ExportPrivateKey.class"
}

function setup_local_ca {
    clean_local_ca
    create_certificate_authority
    add_external_ca
    echo ">>>> Listing generated files for local CA:"
    ls -l "${LOCAL_CA_FILENAME}"*
}

function new_service_csr {
    clean_service
    create_service_certificate_and_csr
    echo ">>>> Listing generated files for service:"
    if [[ "${SERVICE_STORETYPE}" != "JCERACFKS" ]]; then
        ls -l "${SERVICE_KEYSTORE}"* "${SERVICE_TRUSTSTORE}"*
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
    import_external_certificate_to_truststore
    echo ">>>> Listing generated files for service:"
    if [[ "${SERVICE_STORETYPE}" != "JCERACFKS" ]]; then
        ls -l "${SERVICE_KEYSTORE}"* "${SERVICE_TRUSTSTORE}"*
    fi
}

function new_self_signed_service {
    clean_service
    create_self_signed_service
    import_local_ca_certificate
    export_service_certificate
    export_service_private_key
    echo ">>>> Listing generated files for self-signed service:"
    ls -l "${SERVICE_KEYSTORE}"*
}

function append_service {
    service_id=$1

    if [ -n "${EXTERNAL_CERTIFICATE}" ]; then
        import_external_certificate
    else
        create_service_certificate_and_csr "${service_id}"
        sign_csr_using_local_ca "${service_id}"
        import_signed_certificate "${service_id}"
    fi
    export_service_certificate "${service_id}"
    export_service_private_key "${service_id}"
    echo ">>>> Listing generated files for service ${service_id}:"
    if [[ "${SERVICE_STORETYPE}" != "JCERACFKS" ]]; then
        ls -l "${SERVICE_KEYSTORE}"* "${SERVICE_TRUSTSTORE}"*
    fi
}

function trust {
    echo ">>>> Import a certificate to the truststore:"
    pkeytool -importcert $V -trustcacerts -noprompt -file "${CERTIFICATE}" -alias "${ALIAS}" -keystore "${SERVICE_TRUSTSTORE}.p12" -storepass "${SERVICE_PASSWORD}" -storetype PKCS12

    if [[ "${SERVICE_STORETYPE}" == "JCERACFKS" ]] && [[ "${GENERATE_CERTS_FOR_KEYRING}" != "false" ]]; then
        # this may fail if the user has imported CAs to keyring. but we don't know how user configured ZWEKRING, so just retry
        trust_keyring
    fi
}

function trust_keyring {
    echo ">>>> Import a certificate to the keyring:"

    # FIXME: this function may fail in several ways
    # - missing permission on class RDATALIB, possible happens when importing external CAs into keyring
    #   check https://www.ibm.com/docs/en/zos/2.3.0?topic=library-racf-authorization for details.
    #   possible error message:
    #     keytool error (likely untranslated): java.io.IOException: R_datalib (IRRSDL00) error: not RACF authorized to use the requested service (8, 8, 8)
    # - importing z/OSMF certificate back to keyring may see RACF reason code "The certificate exists under a different user.", which is under IZUSVR
    # Proper way to trust for keyring should use ZWEKRING jcl and set these parameters:
    # - ITRMZWCA
    # - ROOTZWCA
    # - ROOTZFCA
    #
    # Alternative way to use keyring-util, but error should be same
    # KEYRING_UTIL="${BASE_DIR}/utils/keyring-util/keyring-util"
    # "${KEYRING_UTIL}" IMPORT "${ZOWE_USERID}" "${ZOWE_KEYRING}" "${ALIAS}" CERTAUTH "${SERVICE_TRUSTSTORE}.p12" "${SERVICE_PASSWORD}"

    keytool -importcert $V -trustcacerts -noprompt -file ${CERTIFICATE} -alias "${ALIAS}" -keystore "safkeyring://${ZOWE_USERID}/${ZOWE_KEYRING}" -storetype ${SERVICE_STORETYPE} \
            -J-Djava.protocol.handler.pkgs=com.ibm.crypto.provider
}




function compare_domain_with_wildcards {
  pattern=$(echo "$1" | tr '[:upper:]' '[:lower:]'})
  domain=$(echo "$2" | tr '[:upper:]' '[:lower:]'})
  
  if [ "${pattern}" = "${domain}" ] || [[ ${domain} == ${pattern} ]]; then
    echo "true"
  fi
}

function validate_certificate_domain {
  host=$1
  port=$2
  host=$(echo "${host}" | tr '[:upper:]' '[:lower:]')

  echo ">>>> validate certificate of ${host}:${port}"

  # get first certificate, ignore CAs
  cert=$(keytool -printcert -sslserver "${host}:${port}" | sed '/Certificate #1/q')
  if [ -z "${cert}" ]; then
    >&2 echo "Error: failed to load certificate of ${host}:${port} to validate"
    return 1
  fi

  owner=$(echo "${cert}" | grep -i "Owner:" | awk -F":" '{print $2;}')
  common_name=
  old_IFS="${IFS}"
  IFS=,
  for prop in $owner; do
    key=$(echo "${prop}" | sed 's/^ *//g' | awk -F"=" '{print $1;}')
    val=$(echo "${prop}" | sed 's/^ *//g' | awk -F"=" '{print $2;}')
    if [ "${key}" = "CN" ]; then
      common_name="${val}"
    fi
  done
  IFS="${old_IFS}"

  if [ -z "${common_name}" ]; then
    >&2 echo "Error: failed to find common name of the certificate"
    return 2
  fi
  echo "${host} certificate has common name ${common_name}"

  if [ "$(compare_domain_with_wildcards "${common_name}" "${host}")" != "true" ]; then
    echo "${host} doesn't match certificate common name, check subject alternate name(s)"
    san=$(echo "${cert}" | sed -e '1,/2.5.29.17/d' | sed '/ObjectId/q')
    dnsnames=$(echo "${san}" | grep -i DNSName | tr , '\n' | tr -d '[]' | awk -F":" '{print $2;}' | sed 's/^ *//g' | sed 's/ *$//g')
    if [ -n "${dnsnames}" ]; then
      echo "certificate has these subject alternate name(s):"
      echo "${dnsnames}"
      match=
      for dnsname in ${dnsnames} ; do
        if [ "$(compare_domain_with_wildcards "${dnsname}" "${host}")" = "true" ]; then
          match=true
        fi
      done
      if [ "${match}" != "true" ]; then
        >&2 echo "Error: ${host} doesn't match any of the certificate common name and subject alternate name(s)"
        return 4
      fi
    else
      >&2 echo "Error: ${host} certificate doesn't have subject alternate name(s)"
      return 3
    fi
  fi
  echo "certificate of ${host}:${port} has valid common name and/or subject alternate name(s)"
  return 0
}

function trust_zosmf {
  echo "${ZOSMF_CERTIFICATE}"
  if [[ -z "${ZOSMF_CERTIFICATE}" ]]; then
    echo ">>>> Getting certificates from z/OSMF host"
    CER_DIR=`dirname "${SERVICE_TRUSTSTORE}"`/temp
    TEMP_CERT_FILE=temp-zosmf-cert
    rm -rf CER_DIR=`dirname "${SERVICE_TRUSTSTORE}"`/temp &> /dev/null
    mkdir -p "${CER_DIR}"
    ALIAS="zosmf"

    KEYTOOL_COMMAND="-printcert -sslserver ${ZOWE_ZOSMF_HOST}:${ZOWE_ZOSMF_PORT} -J-Dfile.encoding=UTF8"
    # Check that the keytool command is okay and remote connection works. It prints out error messages
    # and ends the program if an error occurs.
    pkeytool ${KEYTOOL_COMMAND} -rfc

    # First, print out ZOSMF certificates fingerprints for a user to check
    # We call keytool directly because the pkeytool messes the output that we want to display
    if [[ "$LOG" != "" ]]; then
      echo "> z/OSMF certificate fingerprint:" >&5
      keytool ${KEYTOOL_COMMAND} | grep -e 'Owner:' -e 'SHA1:' -e 'SHA256:' -e 'MD5' >&5
    else
      echo "> z/OSMF certificate fingerprint:"
      keytool ${KEYTOOL_COMMAND} | grep -e 'Owner:' -e 'SHA1:' -e 'SHA256:' -e 'MD5'
    fi
    # keytool should work here but we check RC just in case
    echo "< z/OSMF certificate fingerprint: keytool returned: $RC"
    RC=$?
    if [ "$RC" -ne "0" ]; then
        exit 1
    fi

    # We call keytool directly because the pkeytool messes the output that we need to parse afterwards
    keytool ${KEYTOOL_COMMAND} -rfc > "${CER_DIR}/${TEMP_CERT_FILE}"
    # keytool should work now but we check RC just in case
    RC=$?
    echo "< z/OSMF certificate to temp file: keytool returned: $RC"
    if [ "$RC" -ne "0" ]; then
        exit 1
    fi
    # parse keytool output into separate files
    csplit -s -k -f "${CER_DIR}/${ALIAS}" "${CER_DIR}/${TEMP_CERT_FILE}" /-----END\ CERTIFICATE-----/1 \
      {$(expr `grep -c -e '-----END CERTIFICATE-----' "${CER_DIR}/${TEMP_CERT_FILE}"` - 1)}
    for entry in "${CER_DIR}/${ALIAS}"*; do
      [ -s "$entry" ] || continue
      CERTIFICATE=${entry}
      entry=${entry##*/}
      ALIAS=${entry%.cer}
      trust
    done

    # clean up temporary files
    rm -rf "${CER_DIR}"

    if [ "${VERIFY_CERTIFICATES}" = "true" ]; then
      # validate if ZOWE_ZOSMF_HOST matches certificate common name or SAN
      validate_certificate_domain "${ZOWE_ZOSMF_HOST}" "${ZOWE_ZOSMF_PORT}"
      if [ "$?" != "0" ]; then
        >&2 echo "Error: z/OSMF certficate has invalid common name or subject alternate name(s), please update the certificate so Zowe Gateway can communicate with z/OSMF properly."
        >&2 echo "If you cannot modify z/OSMF certificate, you will need to disable strict certificate verification by setting VERIFY_CERTIFICATES to false but keeping NONSTRICT_VERIFY_CERTIFICATES as true."
        exit 98
      fi
    fi
  else
    echo ">>>> Getting zosmf certificates from file"
    for entry in "${ZOSMF_CERTIFICATE}"; do
      CERTIFICATE=${entry}
      entry=${entry##*/}
      ALIAS=${entry%.*}
      trust
    done

    # FIXME: should we also validate ZOSMF_CERTIFICATE domain?
  fi
}

function generate_component_level_certificates {
  if [ -z "${COMPONENT_LEVEL_CERTIFICATES}" ]; then
    # no action needed
    return 0
  fi
  if [ -n "${EXTERNAL_CERTIFICATE}" ]; then
    # user is using external certificates
    return 0
  fi
  echo ">>>> Generate component-level certificates for: ${COMPONENT_LEVEL_CERTIFICATES}"
  OLD_SERVICE_ALIAS=${SERVICE_ALIAS}
  OLD_SERVICE_DNAME=${SERVICE_DNAME}
  OLD_EXTERNAL_CERTIFICATE=${EXTERNAL_CERTIFICATE}
  OLD_EXTERNAL_CERTIFICATE_ALIAS=${EXTERNAL_CERTIFICATE_ALIAS}
  for SERVICE_ALIAS in $(echo "${COMPONENT_LEVEL_CERTIFICATES}" | sed -e 's#,# #g'); do
    # check if component is using external certificate
    EXTERNAL_CERTIFICATE=
    for one_component_def in $(echo "${EXTERNAL_COMPONENT_CERTIFICATES}" | sed -e 's#:# #g'); do
      component=$(echo "${one_component_def}" | awk -F":" '{print $1;}')
      component_cert=$(echo "${one_component_def}" | awk -F":" '{print $2;}')
      if [ "${component}" = "${SERVICE_ALIAS}" ]; then
        EXTERNAL_CERTIFICATE="${component_cert}"
        break
      fi
    done
    EXTERNAL_CERTIFICATE_ALIAS=
    for one_component_def in $(echo "${EXTERNAL_COMPONENT_CERTIFICATES}" | sed -e 's#:# #g'); do
      component=$(echo "${one_component_def}" | awk -F":" '{print $1;}')
      component_alias=$(echo "${one_component_def}" | awk -F":" '{print $2;}')
      if [ "${component}" = "${SERVICE_ALIAS}" ]; then
        EXTERNAL_CERTIFICATE_ALIAS="${component_alias}"
        break
      fi
    done
    if [ -n "${EXTERNAL_CERTIFICATE}" -a -z "${EXTERNAL_CERTIFICATE_ALIAS}" ] || [ -n "${EXTERNAL_CERTIFICATE}" -a -z "${EXTERNAL_CERTIFICATE_ALIAS}" ]; then
      >&2 echo "Error: external certificate definition of component ${SERVICE_ALIAS} is not complete. You may miss either certificate or alias."
      exit 1
    fi
    echo "- component ${SERVICE_ALIAS}"
    if [ -n "${EXTERNAL_CERTIFICATE}" -a -n "${EXTERNAL_CERTIFICATE_ALIAS}" ]; then
      echo "  using external certificate ${EXTERNAL_CERTIFICATE} with alias ${EXTERNAL_CERTIFICATE_ALIAS}"
    fi
    SERVICE_DNAME=$(echo "${COMPONENT_DNAME}" | sed -e "s#{component}#${SERVICE_ALIAS}#")
    # generate, sign and trust certificate
    append_service "${SERVICE_ALIAS}"
  done
  SERVICE_ALIAS=${OLD_SERVICE_ALIAS}
  SERVICE_DNAME=${OLD_SERVICE_DNAME}
  EXTERNAL_CERTIFICATE=${OLD_EXTERNAL_CERTIFICATE}
  EXTERNAL_CERTIFICATE_ALIAS=${OLD_EXTERNAL_CERTIFICATE_ALIAS}
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
        --verify-certificates )   shift
                                VERIFY_CERTIFICATES=$1
                                ;;
        --nonstrict-verify-certificates )   shift
                                NONSTRICT_VERIFY_CERTIFICATES=$1
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
        --component-level-certs ) shift
                                COMPONENT_LEVEL_CERTIFICATES=$1
                                ;;
        --external-component-certificates ) shift
                                EXTERNAL_COMPONENT_CERTIFICATES=$1
                                ;;
        --external-component-certificate-aliases ) shift
                                EXTERNAL_COMPONENT_CERTIFICATE_ALIASES=$1
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
        generate_component_level_certificates
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
    new-self-signed-service)
        new_self_signed_service
        ;;
    trust)
        trust
        ;;
    trust-keyring)
        trust_keyring
        ;;
    trust-zosmf)
        trust_zosmf
        ;;
    cert-key-export)
        export_service_certificate
        export_service_private_key
        ;;
    *)
        usage
        exit 1
esac
