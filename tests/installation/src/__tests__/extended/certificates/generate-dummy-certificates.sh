#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project. 2021
#######################################################################

#######################################################################
# Generate dummy CA and sign certificate

domain_name=${1:-dummy-domain.com}

# create dummy CA
keytool -genkeypair -v -alias "dummy_ca" -keyalg RSA -keysize 2048 -keystore "dummy_ca.keystore.p12" -dname "CN=ZOWE DUMMY CA, O=International Business Machines Corporation, C=US" -keypass "dummyca" -storepass "dummyca" -storetype PKCS12 -validity 3650 -ext KeyUsage="keyCertSign" -ext BasicConstraints:"critical=ca:true"
# export dummy CA public certificate:
keytool -export -v -alias "dummy_ca" -file "dummy_ca.cer" -keystore "dummy_ca.keystore.p12" -rfc -keypass "dummyca" -storepass "dummyca" -storetype PKCS12
# convert encoding
iconv -f ISO8859-1 -t IBM-1047 "dummy_ca.cer" > "dummy_ca.cer-ebcdic"

# >>>>>>>>>>>>>>>>>>>>>>>> same dummy name
# Generate service private key and service:
keytool -genkeypair -v -alias "dummy_certs" -keyalg RSA -keysize 2048 -keystore "dummy_certs.keystore.p12" -keypass "dummycert" -storepass "dummycert"  -storetype PKCS12 -dname "CN=${domain_name}, OU=ZOWE, O=ibm.com, L=Toronto, ST=Toronto, C=CA" -validity 3650
# Generate CSR for the the service certificate:
keytool -certreq -v -alias "dummy_certs" -keystore "dummy_certs.keystore.p12" -storepass "dummycert" -file "dummy_certs.keystore.csr" -keyalg RSA -storetype PKCS12 -dname "CN=${domain_name}, OU=ZOWE, O=ibm.com, L=Toronto, ST=Toronto, C=CA" -validity 3650
# sign CSR with CA
keytool -gencert -v -infile "dummy_certs.keystore.csr" -outfile "dummy_certs.keystore_signed.cer" -keystore "dummy_ca.keystore.p12" -alias "dummy_ca" -keypass "dummyca" -storepass "dummyca" -storetype PKCS12 -ext "SAN=dns:${domain_name}" -ext KeyUsage:critical=keyEncipherment,digitalSignature,nonRepudiation,dataEncipherment -ext ExtendedKeyUsage=clientAuth,serverAuth -rfc -validity 3650
# Import the Certificate Authority to the keystore:
keytool -importcert -v -trustcacerts -noprompt -file "dummy_ca.cer" -alias "dummy_ca" -keystore "dummy_certs.keystore.p12" -storepass "dummycert" -storetype PKCS12
# Import the signed CSR to the keystore:
keytool -importcert -v -trustcacerts -noprompt -file "dummy_certs.keystore_signed.cer" -alias "dummy_certs" -keystore "dummy_certs.keystore.p12" -storepass "dummycert" -storetype PKCS12
