/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as zos from 'zos';
import * as common from '../../../libs/common';
import * as config from '../../../libs/config';
import * as java from '../../../libs/java';
import * as shell from '../../../libs/shell';

// This is seen in the certificate-analyser.jar codebase - I hope it does not change over time.
const SECTION_SEPARATOR = '++++++++';

const COMMAND_NAME = 'zwe-validate-certificate';

const VALIDATION_OK = 0;
const VALIDATION_WARN = 1;
const VALIDATION_ERROR = 2;

/*
  This program uses certificate-analyser.jar from the zowe apiml repository.
  It doesnt work on java 8.
  That program is currently capable of verifying that the zowe certificate is valid for zowe,
  And can verify that a remote server is trusted by zowe's truststore.

  It does not seem like the program has extensive CA chain review capability,
  And it's unclear if this program can handle ICSF certificates.
  It's also unclear how to detect something is an ICSF certificate, to avoid checking something we cannot verify anyway.
*/

export function execute(quitOnError?: boolean, level?: string): number {
  const ZOWE_CONFIG=config.getZoweConfig();

  let verifyCertificates = level;
  if (verifyCertificates) {
    verifyCertificates.toUpperCase();
  }
  if (verifyCertificates != 'NONSTRICT' && verifyCertificates != 'STRICT' && verifyCertificates != 'DISABLED') {
    verifyCertificates = ZOWE_CONFIG.zowe.verifyCertificates;
  }

  java.requireJava();

  // Due to schema validation zowe.certificate.* is either missing or complete
  // Check if zowe.certificate is present
  if (!ZOWE_CONFIG.zowe.certificate) {
    common.printErrorAndExit(`Error ZWEL0106E: zowe.certificate.* parameter is required.`, undefined, 106);
  }
  if (!ZOWE_CONFIG.zowe.externalDomains) {
    common.printErrorAndExit(`Error ZWEL0106E: zowe.externalDomains parameter is required.`, undefined, 106);
  }

  const keystoreType = ZOWE_CONFIG.zowe.certificate.keystore.type;
  const keystoreAlias = ZOWE_CONFIG.zowe.certificate.keystore.alias;
  const keystorePass = ZOWE_CONFIG.zowe.certificate.keystore.password;
  const truststoreType = ZOWE_CONFIG.zowe.certificate.truststore.type;
  const truststorePass = ZOWE_CONFIG.zowe.certificate.truststore.password;
  let keystoreLocation = ZOWE_CONFIG.zowe.certificate.keystore.file;
  let truststoreLocation = ZOWE_CONFIG.zowe.certificate.truststore.file;

  let keyringUser;
  if (keystoreType.startsWith('JCE') && keystoreType.endsWith('RACFKS')) {
    keystoreLocation = keystoreLocation.replace('safkeyring', 'safkeyring'+keystoreType.toLowerCase().substring(0, keystoreType.length - 'RACFKS'.length));
    try {
      keyringUser = keystoreLocation.split('://')[1].split('/')[0];
    } catch (e) {
      common.printFormattedWarn(common.MSG_KEY, COMMAND_NAME, `Unexpected keyring format ${keystoreLocation}`);
    }
  } else if (keystoreType != 'PKCS12') {
    common.printFormattedWarn(common.MSG_KEY, COMMAND_NAME, `Keystore unknown type ${keystoreType}`);
  }
  if (truststoreType.startsWith('JCE') && truststoreType.endsWith('RACFKS')) {
    truststoreLocation = truststoreLocation.replace('safkeyring', 'safkeyring'+truststoreType.toLowerCase().substring(0, truststoreType.length - 'RACFKS'.length));
    if (!keyringUser) {
      try {
        keyringUser = truststoreLocation.split('://')[1].split('/')[0];
      } catch (e) {
        common.printFormattedWarn(common.MSG_KEY, COMMAND_NAME, `Unexpected keyring format ${truststoreLocation}`);
      }
    }
  } else if (keystoreType != 'PKCS12') {
    common.printFormattedWarn(common.MSG_KEY, COMMAND_NAME, `Truststore unknown type ${truststoreType}`);
  }
  
  const argsString = `-Djava.protocol.handler.pkgs=com.ibm.crypto.provider -jar ${std.getenv('ZWE_zowe_runtimeDirectory')}/bin/utils/certificate-analyser.jar ` +
    `-k ${keystoreLocation} -kt ${keystoreType} -kp ${keystorePass} -a ${keystoreAlias} ` +
    `-t ${truststoreLocation} -tt ${truststoreType} -tp ${truststorePass} ` +
    `-d ${ZOWE_CONFIG.zowe.externalDomains.join(',')}`;
  
  const result = shell.execOutErrSync('java', ...argsString.split(' '));
  const rc = result.rc;
  
  let configLines = [];
  let output = '';
  if (result.out) {
    configLines = configLines.concat(result.out.split('\n'));
    output += result.out;
  }
  if (result.err) {
    configLines = configLines.concat(result.err.split('\n'));
    output += result.err;
  }

  let certificateInvalid = VALIDATION_OK;
  let configInvalid = VALIDATION_OK;
  
  if (rc == 0) {
    common.printDebug(configLines.filter(line => !line.startsWith(SECTION_SEPARATOR)).join('\n'));
    common.printFormattedInfo(common.MSG_KEY, COMMAND_NAME, "Certificate checks passed.");
  } else {


    // From cert-analyser codebase
    // Only happens if keyring pattern is not matched, should be impossible due with proper schema checking.
    if (output.includes('Incorrect key ring format')) {
      configInvalid = VALIDATION_ERROR;

      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Incorrect key ring format.`);
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Verify the syntax of the keystore and truststore properties in the Zowe YAML.`);
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Review Zowe YAML properties:`);
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `  zowe.certificate.keystore.file: ${ZOWE_CONFIG.zowe.certificate.keystore.file}`);
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `  zowe.certificate.truststore.file: ${ZOWE_CONFIG.zowe.certificate.truststore.file}`);
    }


    // From java, when trying to read a key using type JCECCARACFKS
    if (output.includes('no such provider:')) {
      // TODO we just dont validate ICSF keys at this time.
      configInvalid = VALIDATION_WARN;

      common.printFormattedWarn(common.MSG_KEY, COMMAND_NAME, `Java is unable to read either keystore or truststore due to type.`);
      common.printFormattedWarn(common.MSG_KEY, COMMAND_NAME, `Review Zowe YAML properties:`);
      common.printFormattedWarn(common.MSG_KEY, COMMAND_NAME, `  java.home: ${ZOWE_CONFIG.java.home}`);
      common.printFormattedWarn(common.MSG_KEY, COMMAND_NAME, `  zowe.certificate.keystore.type: ${ZOWE_CONFIG.zowe.certificate.keystore.type}`);
      common.printFormattedWarn(common.MSG_KEY, COMMAND_NAME, `  zowe.certificate.truststore.type: ${ZOWE_CONFIG.zowe.certificate.truststore.type}`);
    }
    // From java, when trying to use type JCEHYBRIDRACFKS when not appropriate
    if (output.includes('Invalid keystore format') ||
        output.includes(keystoreType+' not found') ||
        output.includes(truststoreType+' not found')) {
      configInvalid = VALIDATION_ERROR;

      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Incorrect type given for keystore or truststore.`);
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Review Zowe YAML properties:`);
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `  zowe.certificate.keystore.type: ${ZOWE_CONFIG.zowe.certificate.keystore.type}`);
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `  zowe.certificate.truststore.type: ${ZOWE_CONFIG.zowe.certificate.truststore.type}`);
    }

    // From Java when using ICSF key with JCERACFKS or requesting a key that doesnt exist
    if (output.includes('Cannot read the array length because "certificate" is null') ||
    // From cert-analyser codebase
        output.includes('is not available in keystore')) {
      configInvalid = VALIDATION_ERROR;

      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Could not read certificate. Verify it is present in the keystore and the keystore type is correct.`);
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Review Zowe YAML properties: `);
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `  zowe.certificate.keystore.type: ${ZOWE_CONFIG.zowe.certificate.keystore.type}`);
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `  zowe.certificate.keystore.file: ${ZOWE_CONFIG.zowe.certificate.keystore.file}`);
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `  zowe.certificate.keystore.alias: ${ZOWE_CONFIG.zowe.certificate.keystore.alias}`);
    }

    // From java
    if (output.includes('password was incorrect')) {
      configInvalid = VALIDATION_ERROR;

      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Could not read keystore or truststore. Verify passwords are correct.`);
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Review Zowe YAML properties:`);
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `  zowe.certificate.truststore.password`);
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `  zowe.certificate.truststore.password`);
    }

    // From system
    if (output.includes('EDC5129I')) {
      configInvalid = VALIDATION_ERROR;

      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Keystore or truststore does not exist.`);
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Review Zowe YAML properties:`);
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `  zowe.certificate.keystore.file: ${ZOWE_CONFIG.zowe.certificate.keystore.file}`);
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `  zowe.certificate.truststore.file: ${ZOWE_CONFIG.zowe.certificate.truststore.file}`);
    }
    // From system
    if (output.includes('EDC5111I')) {
      configInvalid = VALIDATION_ERROR;

      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Could not read keystore or truststore. Verify permissions are correct.`);
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Review Zowe YAML properties:`);
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `  zowe.certificate.keystore.file: ${ZOWE_CONFIG.zowe.certificate.keystore.file}`);
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `  zowe.certificate.truststore.file: ${ZOWE_CONFIG.zowe.certificate.truststore.file}`);
    }

    
    // From R_datalib (IRRSDL00)
    // Format:
    //   1) R_datalib (IRRSDL00) error: profile for ring not found (8, 8, 84)
    //   2) R_datalib (IRRSDL00) error: not RACF authorized to use the requested service (8, 8, 8)
    if (output.includes("IRRSDL00")) {
      configInvalid = VALIDATION_ERROR;

      const irrLine = configLines.filter((line) => line.includes('IRRSDL00'))[0];
      const codes = irrLine.substring(0, irrLine.length - 1).split(':')[1].split('(')[1].split(', ');
      const esm = zos.getEsm();
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Could not load keyring. SAF rc=${codes[0]}, ${esm} rc=${codes[1]}, ${esm} rsn=${codes[2]}`);
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Verify that keystore and truststore are valid and accessible to the Zowe STC.`);
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Review Zowe YAML properties:`);
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `  zowe.certificate.keystore.file: ${ZOWE_CONFIG.zowe.certificate.keystore.file}`);
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `  zowe.certificate.truststore.file: ${ZOWE_CONFIG.zowe.certificate.truststore.file}`);
      // codes are strings
      if (codes[2] == '8') {
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Possible cause: User ${keyringUser} does not exist, or Zowe STC does not have permission to read that user's keyring`);
      } else if (codes[2] == '84') {
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Possible cause: Keyring may not exist`);
      }
    }
    
    // From ???
    if (output.includes('no authority to access the private key')) {
      configInvalid = VALIDATION_ERROR;

      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Could not read certificate.`);
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Verify that keystore is valid and accessible to the Zowe STC.`);
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Review Zowe YAML properties:`);
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `  zowe.certificate.keystore.file: ${ZOWE_CONFIG.zowe.certificate.keystore.file}`);
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `  zowe.certificate.keystore.alias: ${ZOWE_CONFIG.zowe.certificate.keystore.alias}`);
    }

    // From cert-analyser codebase
    if (output.includes("The certificate is expired")) {
      certificateInvalid = VALIDATION_ERROR;
      
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Certificate ${keystoreAlias} in keystore ${ZOWE_CONFIG.zowe.certificate.keystore.file} has expired.`);
      try {
        const expirationData = configLines.filter(line => line.startsWith('Expiration data'))[0];
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, expirationData);
      } catch (e) {
        common.printDebug('Expiration data parse error');
      }
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Create a new certificate before using Zowe.`);
    }


    // From cert-analyser codebase
    if (output.includes("Certificate can't be used for client authentication")) {
      common.printFormattedWarn(common.MSG_KEY, COMMAND_NAME, `Certificate EKU missing Client Auth 1.3.6.1.5.5.7.3.2 attribute.`);
      if (verifyCertificates == 'DISABLED') {
        common.printFormattedWarn(common.MSG_KEY, COMMAND_NAME, `Certificate will fail verification when zowe.verifyCertificates is not DISABLED`);
        certificateInvalid = VALIDATION_WARN;
      } else {
        certificateInvalid = VALIDATION_ERROR;

        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Certificate does not meet Zowe's requirements.`);
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Create a new certificate that meets the EKU requirements of Zowe before using Zowe.`);
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `See https://docs.zowe.org/stable/user-guide/configure-certificates#extended-key-usage`);
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Review Zowe YAML properties:`);
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `  zowe.certificate.keystore.file: ${ZOWE_CONFIG.zowe.certificate.keystore.file}`);
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `  zowe.certificate.keystore.alias: ${ZOWE_CONFIG.zowe.certificate.keystore.alias}`);
      }
    }
    // From cert-analyser codebase
    if (output.includes("Certificate can't be used for web server")) {
      common.printFormattedWarn(common.MSG_KEY, COMMAND_NAME, `Certificate EKU missing Server Auth 1.3.6.1.5.5.7.3.1 attribute.`);
      if (verifyCertificates == 'DISABLED') {
        common.printFormattedWarn(common.MSG_KEY, COMMAND_NAME, `Certificate will fail verification when zowe.verifyCertificates is not DISABLED`);
        certificateInvalid = VALIDATION_WARN;
      } else {
        certificateInvalid = VALIDATION_ERROR;

        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Certificate does not meet Zowe's requirements.`);
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Create a new certificate that meets the EKU requirements of Zowe before using Zowe.`);
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `See https://docs.zowe.org/stable/user-guide/configure-certificates#extended-key-usage`);
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Review Zowe YAML properties:`);
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `  zowe.certificate.keystore.file: ${ZOWE_CONFIG.zowe.certificate.keystore.file}`);
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `  zowe.certificate.keystore.alias: ${ZOWE_CONFIG.zowe.certificate.keystore.alias}`);
      }
    }

    // From cert-analyser codebase
    if (output.includes("Not matched hostnames with the certificate:")) {
      common.printFormattedWarn(common.MSG_KEY, COMMAND_NAME, `Certificate ${keystoreAlias} is missing some hostnames from Zowe YAML section zowe.externalDomains`);

      // Print out the list certificate-analyser provides
      let start = false;
      let certificateCount = 0;
      for (let i = 0; i < configLines.length; i++) {
        if (configLines[i].indexOf("Not matched hostnames with the certificate:") != -1) {
          start = true;
        }
        if (start === true) {
          if (configLines[i].startsWith(SECTION_SEPARATOR)) {
            break;
          }
          certificateCount++;
          common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `  ${configLines[i]}`);
        }
      }
      //First line is just the error message
      certificateCount--;
      
      if (verifyCertificates != 'STRICT') {
        common.printFormattedWarn(common.MSG_KEY, COMMAND_NAME, `Certificate will fail verification when zowe.verifyCertificates is STRICT`);
        certificateInvalid = VALIDATION_WARN;
       } else {
        certificateInvalid = VALIDATION_ERROR;

        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Certificate is invalid for the chosen hostnames`);
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `See https://docs.zowe.org/stable/user-guide/configure-certificates#hostname-validity`);
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Take one of these actions before using Zowe:`);
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `A) Create a new certificate that matches the addresses in zowe.externalDomains`);
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `B) Change YAML property zowe.verifyCertificates to NONSTRICT to disable hostname verification`);
        if (ZOWE_CONFIG.zowe.externalDomains.length > certificateCount) {
          common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `C) Remove the unmatched hostnames from zowe.externalDomains`);
        }
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Review Zowe YAML properties:`);
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `  zowe.certificate.keystore.file: ${ZOWE_CONFIG.zowe.certificate.keystore.file}`);
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `  zowe.certificate.keystore.alias: ${ZOWE_CONFIG.zowe.certificate.keystore.alias}`);
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `  zowe.externalDomains: ${ZOWE_CONFIG.zowe.externalDomains.join(',')}`);
      }
    }



    // From cert-analyser codebase
    if (output.includes("No trusted certificate found. Add ")) {
      common.printFormattedWarn(common.MSG_KEY, COMMAND_NAME, `Certificate will fail verification  when zowe.verifyCertificates not DISABLED`);
      if (verifyCertificates == 'DISABLED') {
        configInvalid = VALIDATION_WARN;
      } else {
        configInvalid = VALIDATION_ERROR;

        // Extracts 'Add ... certificate authority to the trust store'
        let addMsg;
        try {
          addMsg = configLines.filter((line)=> line.includes('No trusted certificate found. Add '))[0].split('. ')[0];
        } catch (e) {
          common.printDebug(`Error parsing the 'no trusted certificate line'`);
        }

        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Zowe's truststore is missing Certificate Authorities needed to verify Zowe's certificate.`);
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Review the certificate and add all authorities in the chain into the truststore before using Zowe.`);
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, addMsg);
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Other certificate authorities in the chain may also be missing.`);
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Review Zowe YAML properties:`);
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `  zowe.certificate.keystore.file: ${ZOWE_CONFIG.zowe.certificate.keystore.file}`);
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `  zowe.certificate.keystore.alias: ${ZOWE_CONFIG.zowe.certificate.keystore.alias}`);
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `  zowe.certificate.truststore.file: ${ZOWE_CONFIG.zowe.certificate.truststore.file}`);
      }
    }


    if (configInvalid) {
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Correct the zowe.certificate YAML configuration before using Zowe.`);
    }

    if (configInvalid == VALIDATION_ERROR) {
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, "Configuration is invalid.");
    } else if (configInvalid == VALIDATION_WARN) {
      common.printFormattedWarn(common.MSG_KEY, COMMAND_NAME, "Configuration could not be fully validated.");
    }

    if (certificateInvalid == VALIDATION_ERROR) {
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, "Certificate is invalid.");
    } else if (certificateInvalid == VALIDATION_WARN) {
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, "Certificate has warnings. This would prevent startup with stricter values of zowe.verifyCertificates.");
    }

    common.printFormattedInfo(common.MSG_KEY, COMMAND_NAME, "Output follows:");

    console.log(output);
  }


  if (rc) {
    if (configInvalid == VALIDATION_ERROR || certificateInvalid == VALIDATION_ERROR) {
      if (quitOnError) {
        common.printErrorAndExit("Error ZWEL0323E: Certificate validation failed. Fix errors listed before starting Zowe.", undefined, 323);
      }
      return rc;
    } else {
      return 0; //report Ok to upstream, because just a warning.
    }
  }
  
  return 0;
}
