/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as zos from 'zos';
import * as common from '../../../libs/common';
import * as config from '../../../libs/config';
import * as java from '../../../libs/java';
import * as shell from '../../../libs/shell';

export function execute(quitOnError?: boolean): number {
  const ZOWE_CONFIG=config.getZoweConfig();

  if (ZOWE_CONFIG.components.gateway?.apiml?.security?.auth?.provider == 'zosmf' || ZOWE_CONFIG.components.zaas?.apiml?.security?.auth?.provider == 'zosmf') {
    
    if (!ZOWE_CONFIG.zOSMF.host || !ZOWE_CONFIG.zOSMF.port) {
      //no zosmf
      common.printError(`zOSMF cannot be used because YAML entry zOSMF.host (${ZOWE_CONFIG.zOSMF.host}) or zOSMF.port (${ZOWE_CONFIG.zOSMF.port}) are undefined.`);
      if (quitOnError) {
        common.printErrorAndExit("Error ZWEL0323E: Certificate validation failed. Fix errors listed before starting Zowe.", undefined, 323);
      }
      return 8;
    } else {
      java.requireJava();

      let useTls = ZOWE_CONFIG.components.gateway?.zowe?.network?.server?.tls?.attls;
      if (useTls === undefined) {
        useTls = ZOWE_CONFIG.zowe.network?.server?.tls?.attls;
        if (useTls === undefined) { useTls = true; }
      }

      let hostname = ZOWE_CONFIG.zOSMF.host;
      if (hostname.includes(':') && !hostname.startsWith('[') && !hostname.endsWith(']')) {
        hostname = '['+hostname+']'; //ipv6 accomodation.
      }

      let usingGatewayCert = false;
      if (ZOWE_CONFIG.components.gateway?.certificate) {
        usingGatewayCert = true;
      }

      const keystoreType = ZOWE_CONFIG.components.gateway?.certificate?.keystore?.type || ZOWE_CONFIG.zowe.certificate.keystore.type;
      const keystoreAlias = ZOWE_CONFIG.components.gateway?.certificate?.keystore?.alias || ZOWE_CONFIG.zowe.certificate.keystore.alias;
      const keystorePass = ZOWE_CONFIG.components.gateway?.certificate?.keystore?.password || ZOWE_CONFIG.zowe.certificate.keystore.password;
      const truststoreType = ZOWE_CONFIG.components.gateway?.certificate?.truststore?.type || ZOWE_CONFIG.zowe.certificate.truststore.type;
      const truststorePass = ZOWE_CONFIG.components.gateway?.certificate?.truststore?.password || ZOWE_CONFIG.zowe.certificate.truststore.password;
      let keystoreLocation = ZOWE_CONFIG.components.gateway?.certificate?.keystore?.file || ZOWE_CONFIG.zowe.certificate.keystore.file;
      let truststoreLocation = ZOWE_CONFIG.components.gateway?.certificate?.truststore?.file || ZOWE_CONFIG.zowe.certificate.truststore.file;
      if (keystoreType == 'JCERACFKS') {
        keystoreLocation = keystoreLocation.replace('safkeyring', 'safkeyringjce');
      } else if (keystoreType == 'JCECCARACFKS') {
        keystoreLocation = keystoreLocation.replace('safkeyring', 'safkeyringjcecca');
      } else if (keystoreType == 'JCEHYBRIDRACFKS') {
        keystoreLocation = keystoreLocation.replace('safkeyring', 'safkeyringjcehybrid');
      }
      if (truststoreType == 'JCERACFKS') {
        truststoreLocation = truststoreLocation.replace('safkeyring', 'safkeyringjce');
      } else if (truststoreType == 'JCECCARACFKS') {
        truststoreLocation = truststoreLocation.replace('safkeyring', 'safkeyringjcecca');
      } else if (truststoreType == 'JCEHYBRIDRACFKS') {
        truststoreLocation = truststoreLocation.replace('safkeyring', 'safkeyringjcehybrid');
      }      

      let argsString = `-Djava.protocol.handler.pkgs=com.ibm.crypto.provider -jar ${ZOWE_CONFIG.zowe.runtimeDirectory}/bin/utils/certificate-analyser.jar `+
        `-r ${useTls ? 'https://' : 'http://'}${hostname}${ZOWE_CONFIG.zOSMF.port}/zosmf/info -k ${keystoreLocation} -kt ${keystoreType} -kp ${keystorePass} `+
        `-a ${keystoreAlias} -t ${truststoreLocation} -tt ${truststoreType} -tp ${truststorePass}`;
      
      let result = shell.execOutSync('java', ...argsString.split(' '));
      let rc = result.rc;
      if (rc == 0) {
        common.printFormattedInfo("ZWELS", "zwe-validate-zosmf", "z/OSMF checks passed. Certificates checks passed. Output follows:");
        let configLines = result.out.split('\n').filter((line)=>line != '++++++++');
        console.log(configLines.join('\n'));
      } else {
        let configLines = result.out.split('\n').filter((line)=>line != '++++++++');
        let hasWarning = false;
        //Failed when calling url: "https://192.168.55.28:11443/zosmf/info" Error message: Unsupported or unrecognized SSL message     
        if (result.out.includes('SSL Handshake failed for address')) {
          //SSL Handshake failed for address "https://github.com". Cause of error: PKIX path building failed: sun.security.provider.certpath.SunCertPathBuil... n: unable to find valid certification path to requested target 
          let line = configLines.filter((line)=> line.includes('SSL Handshake failed for address'))[0];
          if (line.includes('unable to find valid certification path to requested target')) {
            if (ZOWE_CONFIG.zowe.verifyCertificates == 'STRICT') {
              common.printFormattedError("ZWELS", "zwe-validate-zosmf", `Zowe cannot trust z/OSMF's certificate using the truststore ${truststoreLocation}.`);
              common.printFormattedError("ZWELS", "zwe-validate-zosmf", `Ensure the truststore has all certificate authorities needed to verify z/OSMF's certificate`);
              common.printFormattedError("ZWELS", "zwe-validate-zosmf", `Ensure the z/OSMF's certificate is valid for hostname ${hostname}`);
            } else {
              hasWarning = true;
              common.printFormattedWarn("ZWELS", "zwe-validate-zosmf", `z/OSMF's certificate either is invalid for the hostname ${hostname} or is not trusted by the Zowe truststore ${truststoreLocation}.`);
              common.printFormattedInfo("ZWELS", "zwe-validate-zosmf", `This may be fixed by ensuring all certificate authorities needed to verify z/OSMF are in Zowe's truststore.`);
              common.printFormattedInfo("ZWELS", "zwe-validate-zosmf", `This may be fixed by ensuring z/OSMF's certificate is valid for hostname ${hostname}`);
              common.printFormattedInfo("ZWELS", "zwe-validate-zosmf", `Zowe will continue to use z/OSMF due to zowe.verifyCertificates=${ZOWE_CONFIG.zowe.verifyCertificates}.`);
            }
          }
        }
        if (result.out.includes('Failed when calling url')) {
          hasWarning = false;
          let line = configLines.filter((line)=> line.includes('Failed when calling url'))[0];
          
          common.printFormattedError("ZWELS", "zwe-validate-zosmf", "Could not reach z/OSMF");
          if (line.includes('Unsupported or unrecognized SSL message')) {
            if (ZOWE_CONFIG.zowe.network.server.tls.attls === true) {
              common.printFormattedError("ZWELS", "zwe-validate'zosmf", "The Zowe YAML has AT-TLS enabled. Ensure that your AT-TLS configuration is correct to access z/OSMF");
            } else {
              common.printFormattedError("ZWELS", "zwe-validate'zosmf", "A TLS error may have occurred. Verify if AT-TLS is being used or not, and if it is interferring with Zowe or z/OSMF's configuration.");
            }
          } else if (line.includes('Connect timed out')) {
              common.printFormattedError("ZWELS", "zwe-validate'zosmf", `The host ${hostname} may not be reachable from this system, or z/OSMF may not be running at ${hostname}:${ZOWE_CONFIG.zOSMF.port}.`);
          } else if (line.includes('errno2=0x')) {
            //Failed when calling url: "https://RS28.rocketsoftware.com:32305/" Error message: EDC8128I Connection refused. (errno2=0x00000000)
            let errno = line.substring(0,line.length-1).split('errno2=0x')[1];
            let message = line.substring(0,line.length-1).split('Error message:')[1];
            let bpxmtextResult = shell.execOutSync('bpxmtext', errno);
            common.printFormattedError("ZWELS", "zwe-validate'zosmf", `z/OSMF may not be running at ${hostname}:${ZOWE_CONFIG.zOSMF.port}. Ensure that it is started before running Zowe, and that Zowe has network permissions to connect to it.`);
            common.printFormattedError("ZWELS", "zwe-validate'zosmf", `Error message: ${message}`);
            common.printFormattedError("ZWELS", "zwe-validate'zosmf", `bpxmtext description of errno2:`);
            console.log(bpxmtextResult.out);
          }
        }


        let certificateInvalid = false;
        let configInvalid=false;
         if (result.out.includes("IRRSDL00")) {
          configInvalid=true;
          //R_datalib (IRRSDL00) error: profile for ring not found (8, 8, 84)
          let irrLine = configLines.filter((line)=> line.includes('IRRSDL00'));
          let codes = irrLine[0].substring(0,irrLine[0].length-1).split(':')[1].split('(')[1].split(', ');
          let esm = zos.getEsm();
          common.printFormattedError("ZWELS", "zwe-validate-zosmf", `Could not load keyring. SAF rc=${codes[0]}, ${esm} rc=${codes[1]}, ${esm} rsn=${codes[2]}`);
          common.printFormattedError("ZWELS", "zwe-validate-zosmf", `Verify that keystore ${keystoreLocation} is valid and accessible to the Zowe STC`);
          common.printFormattedError("ZWELS", "zwe-validate-zosmf", `Verify that truststore ${truststoreLocation} is valid and accessible to the Zowe STC`);
        }
        if (result.out.includes('Incorrect key ring format')) {
          configInvalid=true;
        }
        if (result.out.includes('is not available in keystore')) {
          configInvalid=true;
          common.printFormattedError("ZWELS", "zwe-validate-zosmf", `Could not load certificate ${keystoreAlias}. Verify it is present in keystore ${keystoreLocation}.`);          
        }
        if (result.out.includes("No trusted certificate found.")) {
          //No trusted certificate found. Add " + x509Certificate.getIssuerDN() + " certificate authority to the trust store
          //TODO 
        }
        if (result.out.includes("Certificate can't be used for client authentication")) {
          certificateInvalid=true;
          if (ZOWE_CONFIG.zowe.verifyCertificates != 'DISABLED') {
            common.printFormattedError("ZWELS", "zwe-validate-zosmf", `Certificate ${keystoreAlias} in keystore ${keystoreLocation} does not need Zowe's requirements.`);
            common.printFormattedError("ZWELS", "zwe-validate-zosmf", `Certificate EKU missing Client Auth 1.3.6.1.5.5.7.3.2 attribute.`);
            common.printFormattedError("ZWELS", "zwe-validate-zosmf", `See https://docs.zowe.org/stable/user-guide/configure-certificates#extended-key-usage'`);
            common.printFormattedError("ZWELS", "zwe-validate-zosmf", 'Create a new certificate that meets the EKU requirements of Zowe before using Zowe.');
          }
        }
        if (result.out.includes("Certificate can't be used for web server")) {
          certificateInvalid=true;
          if (ZOWE_CONFIG.zowe.verifyCertificates != 'DISABLED') {
            common.printFormattedError("ZWELS", "zwe-validate-zosmf", `Certificate ${keystoreAlias} in keystore ${keystoreLocation} does not need Zowe's requirements.`);
            common.printFormattedError("ZWELS", "zwe-validate-zosmf", `Certificate EKU missing Server Auth 1.3.6.1.5.5.7.3.1 attribute.`);
            common.printFormattedError("ZWELS", "zwe-validate-zosmf", `See https://docs.zowe.org/stable/user-guide/configure-certificates#extended-key-usage'`);
            common.printFormattedError("ZWELS", "zwe-validate-zosmf", 'Create a new certificate that meets the EKU requirements of Zowe before using Zowe.');
          }
        }
        if (result.out.includes("Not matched hostnames with the certificate:")) {
          if (ZOWE_CONFIG.zowe.verifyCertificates == 'STRICT') {
            certificateInvalid = true;
            //TODO
            common.printFormattedError("ZWELS", "zwe-validate-zosmf", `Certificate ${keystoreAlias} in keystore ${keystoreLocation} is invalid for some hostnames used with Zowe.`);
          }
        }
        if (result.out.includes("The certificate is expired")) {
          certificateInvalid = true;
          if (ZOWE_CONFIG.zowe.verifyCertificates == 'DISABLED') {
            common.printFormattedWarn("ZWELS", "zwe-validate-zosmf", `Certificate ${keystoreAlias} in keystore ${keystoreLocation} has expired.`);
          } else {
            common.printFormattedError("ZWELS", "zwe-validate-zosmf", `Certificate ${keystoreAlias} in keystore ${keystoreLocation} has expired.`);
            common.printFormattedError("ZWELS", "zwe-validate-zosmf", `Create a new certificate before using Zowe.`);
          }
        }

        if (certificateInvalid) {
          if (ZOWE_CONFIG.zowe.verifyCertificates == 'DISABLED') {
            rc = 0; //ignored
            certificateInvalid = false;
          }
        }
        if (configInvalid) {
          common.printFormattedError("ZWELS", "zwe-validate-zosmf", `Correct the ${usingGatewayCert ? 'zowe.certificate' : 'components.gateway.certificate'} YAML configuration before using Zowe.`);
        }

        if (!certificateInvalid && !configInvalid && hasWarning) {
          rc = 0;
        }

        if (rc != 0) {
          common.printFormattedError("ZWELS", "zwe-validate-zosmf", "Validation failed. Output follows:");
        } else {
          common.printFormattedWarn("ZWELS", "zwe-validate-zosmf", "Validation had warnings. Output follows:");
        }

        console.log(configLines.join('\n'));
      }      

      if (rc && quitOnError) {
        common.printErrorAndExit("Error ZWEL0323E: Certificate validation failed. Fix errors listed before starting Zowe.", undefined, 323);
      }

      
      return rc;


    }
  } else {
    common.printFormattedInfo("ZWELS", "zwe-validate-zosmf", "z/OSMF checks skipped due to APIML not using z/OSMF as a security provider.");
    return 0;
  }
}
