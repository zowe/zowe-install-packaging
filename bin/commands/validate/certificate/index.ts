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

      java.requireJava();

      const keystoreType = ZOWE_CONFIG.zowe.certificate.keystore.type;
      const keystoreAlias = ZOWE_CONFIG.zowe.certificate.keystore.alias;
      const keystorePass = ZOWE_CONFIG.zowe.certificate.keystore.password;
      const truststoreType = ZOWE_CONFIG.zowe.certificate.truststore.type;
      const truststorePass = ZOWE_CONFIG.zowe.certificate.truststore.password;
      let keystoreLocation = ZOWE_CONFIG.zowe.certificate.keystore.file;
      let truststoreLocation = ZOWE_CONFIG.zowe.certificate.truststore.file;
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
        `-k ${keystoreLocation} -kt ${keystoreType} -kp ${keystorePass} `+
        `-a ${keystoreAlias} -t ${truststoreLocation} -tt ${truststoreType} -tp ${truststorePass}`;
      
      let result = shell.execOutSync('java', ...argsString.split(' '));
      let rc = result.rc;
      if (rc == 0) {
        common.printFormattedInfo("ZWELS", "zwe-validate-certificate", "Certificate checks passed. Output follows:");
        console.log(result.out);
      } else {
        let configLines = result.out.split('\n');

        let certificateInvalid = false;
        let configInvalid=false;
         if (result.out.includes("IRRSDL00")) {
          configInvalid=true;
          //R_datalib (IRRSDL00) error: profile for ring not found (8, 8, 84)
          let irrLine = configLines.filter((line)=> line.includes('IRRSDL00'));
          let codes = irrLine[0].substring(0,irrLine[0].length-1).split(':')[1].split('(')[1].split(', ');
          let esm = zos.getEsm();
          common.printFormattedError("ZWELS", "zwe-validate-certificate", `Could not load keyring. SAF rc=${codes[0]}, ${esm} rc=${codes[1]}, ${esm} rsn=${codes[2]}`);
          common.printFormattedError("ZWELS", "zwe-validate-certificate", `Verify that keystore ${keystoreLocation} is valid and accessible to the Zowe STC`);
          common.printFormattedError("ZWELS", "zwe-validate-certificate", `Verify that truststore ${truststoreLocation} is valid and accessible to the Zowe STC`);
        }
        if (result.out.includes('Incorrect key ring format')) {
          configInvalid=true;
        }
        if (result.out.includes('is not available in keystore')) {
          configInvalid=true;
          common.printFormattedError("ZWELS", "zwe-validate-certificate", `Could not load certificate ${keystoreAlias}. Verify it is present in keystore ${keystoreLocation}.`);          
        }
        if (result.out.includes("No trusted certificate found.")) {
          //No trusted certificate found. Add " + x509Certificate.getIssuerDN() + " certificate authority to the trust store
          //TODO 
        }
        if (result.out.includes("Certificate can't be used for client authentication")) {
          certificateInvalid=true;
          if (ZOWE_CONFIG.zowe.verifyCertificates != 'DISABLED') {
            common.printFormattedError("ZWELS", "zwe-validate-certificate", `Certificate ${keystoreAlias} in keystore ${keystoreLocation} does not need Zowe's requirements.`);
            common.printFormattedError("ZWELS", "zwe-validate-certificate", `Certificate EKU missing Client Auth 1.3.6.1.5.5.7.3.2 attribute.`);
            common.printFormattedError("ZWELS", "zwe-validate-certificate", `See https://docs.zowe.org/stable/user-guide/configure-certificates#extended-key-usage'`);
            common.printFormattedError("ZWELS", "zwe-validate-certificate", 'Create a new certificate that meets the EKU requirements of Zowe before using Zowe.');
          }
        }
        if (result.out.includes("Certificate can't be used for web server")) {
          certificateInvalid=true;
          if (ZOWE_CONFIG.zowe.verifyCertificates != 'DISABLED') {
            common.printFormattedError("ZWELS", "zwe-validate-certificate", `Certificate ${keystoreAlias} in keystore ${keystoreLocation} does not need Zowe's requirements.`);
            common.printFormattedError("ZWELS", "zwe-validate-certificate", `Certificate EKU missing Server Auth 1.3.6.1.5.5.7.3.1 attribute.`);
            common.printFormattedError("ZWELS", "zwe-validate-certificate", `See https://docs.zowe.org/stable/user-guide/configure-certificates#extended-key-usage'`);
            common.printFormattedError("ZWELS", "zwe-validate-certificate", 'Create a new certificate that meets the EKU requirements of Zowe before using Zowe.');
          }
        }
        if (result.out.includes("Not matched hostnames with the certificate:")) {
          if (ZOWE_CONFIG.zowe.verifyCertificates == 'STRICT') {
            certificateInvalid = true;
            //TODO
            common.printFormattedError("ZWELS", "zwe-validate-certificate", `Certificate ${keystoreAlias} in keystore ${keystoreLocation} is invalid for some hostnames used with Zowe.`);
          }
        }
        if (result.out.includes("The certificate is expired")) {
          certificateInvalid = true;
          if (ZOWE_CONFIG.zowe.verifyCertificates == 'DISABLED') {
            common.printFormattedWarn("ZWELS", "zwe-validate-certificate", `Certificate ${keystoreAlias} in keystore ${keystoreLocation} has expired.`);
          } else {
            common.printFormattedError("ZWELS", "zwe-validate-certificate", `Certificate ${keystoreAlias} in keystore ${keystoreLocation} has expired.`);
            common.printFormattedError("ZWELS", "zwe-validate-certificate", `Create a new certificate before using Zowe.`);
          }
        }

        if (certificateInvalid) {
          if (ZOWE_CONFIG.zowe.verifyCertificates == 'DISABLED') {
            rc = 0; //ignored
          }
        }
        if (configInvalid) {
          common.printFormattedError("ZWELS", "zwe-validate-certificate", `Correct the zowe.certificate YAML configuration before using Zowe.`);
        }

        common.printFormattedInfo("ZWELS", "zwe-validate-certificate", "Validation failed. Output follows:");
      }


      if (rc && quitOnError) {
        common.printErrorAndExit("Error ZWEL0323E: Certificate validation failed. Fix errors listed before starting Zowe.", undefined, 323);
      }
            
      return rc;
}
