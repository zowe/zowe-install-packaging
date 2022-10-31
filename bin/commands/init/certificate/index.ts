/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'std';
import * as zoslib from '../../../libs/zos';
import * as zosdataset from '../../../libs/zos-dataset';
import * as common from '../../../libs/common';
import * as stringlib from '../../../libs/string';
import * as jsonlib from '../../../libs/json';
import * as shell from '../../../libs/shell';
import * as config from '../../../libs/config';

export function execute() {

  common.printLevel1Message(`APF authorize load libraries`);

  // Constants
  // This is made because there's some dynamic var name assignment going on below,
  // So we keep it all in an object rather than doing evals into a global
  const CERT_PARMS: any = {};

  // Validation
  common.requireZoweYaml();
  const zoweConfig = config.getZoweConfig();

  // read prefix and validate
  const prefix=zoweConfig.zowe?.setup?.dataset?.prefix;
  if (!prefix) {
    common.printErrorAndExit(`Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }
  // read JCL library and validate
  const jcllib=zoweConfig.zowe.setup.dataset.jcllib;
  if (!jcllib) {
    common.printErrorAndExit(`Error ZWEL0157E: Zowe custom JCL library (zowe.setup.dataset.jcllib) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }
  let securityProduct=zoweConfig.zowe.setup.security?.product;
  let securityUsersZowe=zoweConfig.zowe.setup.security?.users?.zowe;
  let securityGroupsAdmin=zoweConfig.zowe.setup.security?.groups?.admin;
  // read cert type and validate
  const certType=zoweConfig.zowe.setup.certificate?.type;
  if (!certType) {
    common.printErrorAndExit(`Error ZWEL0157E: Certificate type (zowe.setup.certificate.type) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }
  if (certType != "PKCS12" && certType != "JCERACFKS") {
    common.printErrorAndExit(`Error ZWEL0164E: Value of certificate type (zowe.setup.certificate.type) defined in Zowe YAML configuration file is invalid. Valid values are PKCS12 or JCERACFKS.`, undefined, 164);
  }
  // read cert dname
  ['caCommonName', 'commonName', 'orgUnit', 'org', 'locality', 'state', 'country'].forEach((item:string)=> {
    CERT_PARMS[`dname_${item}`] = zoweConfig.zowe.setup.certificate.dname ? zoweConfig.zowe.setup.certificate.dname[item] : undefined;
  });
  // read cert validity
  const certValidity=zoweConfig.zowe.setup.certificate.validity;
  if (certType == "PKCS12") {
    // read keystore info
    ['directory', 'lock', 'name', 'password', 'caAlias', 'caPassword'].forEach((item:string) => {
      CERT_PARMS[`pkcs12_${item}`] = zoweConfig.zowe.setup.certificate.pkcs12 ? zoweConfig.zowe.setup.certificate.pkcs12[item] : undefined;
    });
    if (!CERT_PARMS.pkcs12Directory) {
      common.printErrorAndExit(`Error ZWEL0157E: Keystore directory (zowe.setup.certificate.pkcs12.directory) is not defined in Zowe YAML configuration file.`, undefined, 157);
    }
    // read keystore import info
    ['keystore', 'password', 'alias'].forEach((item:string)=> {
      CERT_PARMS[`pkcs12Import_${item}`] = zoweConfig.zowe.setup.certificate.pkcs12.import ? zoweConfig.zowe.setup.certificate.pkcs12.import[item] : undefined;
    });
    if (CERT_PARMS.pkcs12ImportKeystore) {
      if (!CERT_PARMS.pkcs12ImportPassword) {
        common.printErrorAndExit(`Error ZWEL0157E: Password for import keystore (zowe.setup.certificate.pkcs12.import.password) is not defined in Zowe YAML configuration file.`, undefined, 157);
      }
      if (!CERT_PARMS.pkcs12ImportAlias) {
        common.printErrorAndExit(`Error ZWEL0157E: Certificate alias of import keystore (zowe.setup.certificate.pkcs12.import.alias) is not defined in Zowe YAML configuration file.`, undefined, 157);
      }
    }
  } else if  (certType == "JCERACFKS") {
    CERT_PARMS.keyringOption=1;
    // read keyring info
    ['owner', 'name', 'label', 'caLabel'].forEach((item:string) => {
      CERT_PARMS[`keyring_${item}`] = zoweConfig.zowe.setup.certificate.keyring ? zoweConfig.zowe.setup.certificate.keyring[item] : undefined;
    });
    if (!CERT_PARMS.keyringName) {
      common.printErrorAndExit(`Error ZWEL0157E: Zowe keyring name (zowe.setup.certificate.keyring.name) is not defined in Zowe YAML configuration file.`, undefined, 157);
    }
    CERT_PARMS.keyringImportDsName = zoweConfig.zowe.setup.certificate.keyring.import ? zoweConfig.zowe.setup.certificate.keyring.import.dsName : undefined;
    CERT_PARMS.keyringImportPassword = zoweConfig.zowe.setup.certificate.keyring.import ? zoweConfig.zowe.setup.certificate.keyring.import.password : undefined;
    if (CERT_PARMS.keyringImportDsName) {
      CERT_PARMS.keyringOption=3;
      if (!CERT_PARMS.keyringImportPassword) {
        common.printErrorAndExit(`Error ZWEL0157E: The password for data set storing importing certificate (zowe.setup.certificate.keyring.import.password) is not defined in Zowe YAML configuration file.`, undefined, 157);
      }
    }
    CERT_PARMS.keyringConnectUser = zoweConfig.zowe.setup.certificate.keyring.connect ? zoweConfig.zowe.setup.certificate.keyring.connect.user : undefined;
    CERT_PARMS.keyringConnectLabel = zoweConfig.zowe.setup.certificate.keyring.connect ? zoweConfig.zowe.setup.certificate.keyring.connect.label : undefined;
    if (CERT_PARMS.keyringConnectLabel) {
      CERT_PARMS.keyringOption=2;
    }
  }
  // read keystore domains
  const certImportCAs=zoweConfig.zowe.setup.certificate.importCertificateAuthorities ? zoweConfig.zowe.setup.certificate.importCertificateAuthorities.join(',') : '';
  // read keystore domains
  let certDomains=zoweConfig.zowe.setup.certificate.san ? zoweConfig.zowe.setup.certificate.san.join(',') : '';
  if (!certDomains) {
    certDomains=zoweConfig.zowe.externalDomains ? zoweConfig.zowe.externalDomains.join(',') : '';
  }
  // read z/OSMF info
  ['user', 'ca'].forEach((item:string)=> {
    CERT_PARMS[`zosmf_${item}`] =  zoweConfig.zowe.setup.certificate.keyring.zOSMF ? zoweConfig.zowe.setup.certificate.keyring.zOSMF[item] : undefined;
  });
  ['host', 'port'].forEach((item: string)=> {
    CERT_PARMS[`zosmf_${item}`] = zoweConfig.zOSMF ? zoweConfig.zOSMF[item] : undefined;
  });
  let verifyCertificates = zoweConfig.zowe.verifyCertificates ? zoweConfig.zowe.verifyCertificates.toUpperCase() : undefined;
  if (verifyCertificates == "STRICT" || verifyCertificates == "NONSTRICT") {
    CERT_PARMS.keyringTrustZosmf="--trust-zosmf";
    CERT_PARMS.zosmfHost = std.getenv('zosmf_host');
    CERT_PARMS.zosmfPort = std.getenv('zosmf_port');
  } else {
    common.printMessage(`Warning: Skipping step to get and trust zOSMF's certificates. If certificate verification is turned on later, this step must be done manually or the keystore will need to be regenerated`);
    // no need to trust z/OSMF service
  }

  // set default values
  if (!securityProduct) {
    securityProduct='RACF';
  }
  if (!securityUsersZowe) {
    securityUsersZowe=std.getenv('ZWE_PRIVATE_DEFAULT_ZOWE_USER');
  }
  if (!securityGroupsAdmin) {
    securityGroupsAdmin=std.getenv('ZWE_PRIVATE_DEFAULT_ADMIN_GROUP');
  }
  if (certType == "PKCS12") {
    if (!CERT_PARMS.pkcs12CaAlias) {
      CERT_PARMS.pkcs12CaAlias='localCa';
    }
    if (!CERT_PARMS.pkcs12CaPassword) {
      CERT_PARMS.pkcs12CaPassword='localCaPassword';
    }
    if (!CERT_PARMS.pkcs12Name) {
      CERT_PARMS.pkcs12Name='localhost';
    }
    if (!CERT_PARMS.pkcs12Password) {
      CERT_PARMS.pkcs12Password='password';
    }
  } else if  (certType == "JCERACFKS") {
    if (!CERT_PARMS.keyringOwner) {
      CERT_PARMS.keyringOwner=securityUsersZowe;
    }
    if (!CERT_PARMS.keyringLabel) {
      CERT_PARMS.keyringLabel='localhost';
    }
    if (CERT_PARMS.keyringOption == 1) {
      if (!CERT_PARMS.keyringCaLabel) {
        CERT_PARMS.keyringCaLabel='localca';
      }
    } else {
      // for import case, this variable is not used
      delete CERT_PARMS.keyringCaLabel;
    }
    if (!CERT_PARMS.zosmfCa && securityProduct == "RACF" && CERT_PARMS.zosmfHost) {
      CERT_PARMS.zosmfCa="_auto_";
    }
  }
  CERT_PARMS.pkcs12NameLc=CERT_PARMS.pkcs12Name.toLowerCase();
  CERT_PARMS.pkcs12CaAliasLc=CERT_PARMS.pkcs12CaAlias.toLowerCase();
  // what PEM format CAs we should tell Zowe to use
  delete CERT_PARMS.yamlPemCas;

  if (certType == "PKCS12") {
    if (CERT_PARMS.pkcs12ImportKeystore) {
      // import from another keystore
      shell.execSync('sh', '-c', 'zwe '+
                     `certificate pkcs12 import `+
                     `--keystore "${CERT_PARMS.pkcs12Directory}/${CERT_PARMS.pkcs12Name}/${CERT_PARMS.pkcs12Name}.keystore.p12" `+
                     `--password "${CERT_PARMS.pkcs12Password}" `+
                     `--alias "${CERT_PARMS.pkcs12Name}" `+
                     `--source-keystore "${CERT_PARMS.pkcs12ImportKeystore}" `+
                     `--source-password "${CERT_PARMS.pkcs12ImportPassword}" `+
                     `--source-alias "${CERT_PARMS.pkcs12ImportAlias}"`);
    } else {
      // create CA
      shell.execSync('sh', '-c', 'zwe '+
                     `certificate pkcs12 create ca `+
                     `--keystore-dir "${CERT_PARMS.pkcs12Directory}" `+
                     `--alias "${CERT_PARMS.pkcs12CaAlias}" `+
                     `--password "${CERT_PARMS.pkcs12CaPassword}" `+
                     `--common-name "${CERT_PARMS.dnameCaCommonName}" `+
                     `--org-unit "${CERT_PARMS.dnameOrgUnit}" `+
                     `--org "${CERT_PARMS.dnameOrg}" `+
                     `--locality "${CERT_PARMS.dnameLocality}" `+
                     `--state "${CERT_PARMS.dnameState}" `+
                     `--country "${CERT_PARMS.dnameCountry}" `+
                     `--validity "${certValidity}"`);

      // export CA cert in PEM format
      shell.execSync('sh', '-c', 'zwe '+
                     `certificate pkcs12 export `+
                     `--keystore "${CERT_PARMS.pkcs12Directory}/${CERT_PARMS.pkcs12CaAlias}/${CERT_PARMS.pkcs12CaAlias}.keystore.p12" `+
                     `--password "${CERT_PARMS.pkcs12CaPassword}"`);

      CERT_PARMS.yamlPemCas=`${CERT_PARMS.pkcs12Directory}/${CERT_PARMS.pkcs12CaAlias}/${CERT_PARMS.pkcs12CaAliasLc}.cer`;

      // create default cert
      shell.execSync('sh', '-c', 'zwe '+
                     `certificate pkcs12 create cert `+
                     `--keystore-dir "${CERT_PARMS.pkcs12Directory}" `+
                     `--keystore "${CERT_PARMS.pkcs12Name}" `+
                     `--alias "${CERT_PARMS.pkcs12Name}" `+
                     `--password "${CERT_PARMS.pkcs12Password}" `+
                     `--common-name "${CERT_PARMS.dnameCaCommonName}" `+
                     `--org-unit "${CERT_PARMS.dnameOrgUnit}" `+
                     `--org "${CERT_PARMS.dnameOrg}" `+
                     `--locality "${CERT_PARMS.dnameLocality}" `+
                     `--state "${CERT_PARMS.dnameState}" `+
                     `--country "${CERT_PARMS.dnameCountry}" `+
                     `--validity "${certValidity}" `+
                     `--ca-alias "${CERT_PARMS.pkcs12CaAlias}" `+
                     `--ca-password "${CERT_PARMS.pkcs12CaPassword}" `+
                     `--domains "${certDomains}"`);
    }

    // import extra CAs if they are defined
    if (certImportCAs) {
      // also imported to keystore to maintain full chain
      shell.execSync('sh', '-c', 'zwe '+
                     `certificate pkcs12 import `+
                     `--keystore "${CERT_PARMS.pkcs12Directory}/${CERT_PARMS.pkcs12Name}/${CERT_PARMS.pkcs12Name}.keystore.p12" `+
                     `--password "${CERT_PARMS.pkcs12Password}" `+
                     `--alias "" `+
                     `--source-keystore "" `+
                     `--source-password "" `+
                     `--source-alias "" `+
                     `--trust-cas "${certImportCAs}"`);

      shell.execSync('sh', '-c', 'zwe '+
                     `certificate pkcs12 import `+
                     `--keystore "${CERT_PARMS.pkcs12Directory}/${CERT_PARMS.pkcs12Name}/${CERT_PARMS.pkcs12Name}.truststore.p12" `+
                     `--password "${CERT_PARMS.pkcs12Password}" `+
                     `--alias "" `+
                     `--source-keystore "" `+
                     `--source-password "" `+
                     `--source-alias "" `+
                     `--trust-cas "${certImportCAs}"`);
    }

    // trust z/OSMF
    if (CERT_PARMS.zosmfHost && CERT_PARMS.zosmfPort) {
      shell.execSync('sh', '-c', 'zwe '+
                     `certificate pkcs12 trust-service `+
                     `--service-name "z/OSMF" `+
                     `--keystore-dir "${CERT_PARMS.pkcs12Directory}" `+
                     `--keystore "${CERT_PARMS.pkcs12Name}" `+
                     `--password "${CERT_PARMS.pkcs12Password}" `+
                     `--host "${CERT_PARMS.zosmfHost}" `+
                     `--port "${CERT_PARMS.zosmfPort}" `+
                     `--alias "zosmf"`);
    }

    // export all certs in PEM format
    shell.execSync('sh', '-c', 'zwe '+
                   `certificate pkcs12 export `+
                   `--keystore "${CERT_PARMS.pkcs12Directory}/${CERT_PARMS.pkcs12Name}/${CERT_PARMS.pkcs12Name}.keystore.p12" `+
                   `--password "${CERT_PARMS.pkcs12Password}" `+
                   `--private-keys "${CERT_PARMS.pkcs12Name}"`);
    shell.execSync('sh', '-c', 'zwe '+
                   `certificate pkcs12 export `+
                   `--keystore "${CERT_PARMS.pkcs12Directory}/${CERT_PARMS.pkcs12Name}/${CERT_PARMS.pkcs12Name}.truststore.p12" `+
                   `--password "${CERT_PARMS.pkcs12Password}" `+
                   `--private-keys ""`);

    // after we export truststore, the imported CAs will be exported as extca*.cer
    if (certImportCAs) {
      const getImportedCAs=shell.execOutSync('sh', '-c', `find "${CERT_PARMS.pkcs12Directory}/"${CERT_PARMS.pkcs12Name}" -name 'extca*.cer' -type f 2>&1`);
      if (getImportedCAs.rc == 0) {
        const importedCAs = getImportedCAs.out.split('\n').join(',');
        if (!CERT_PARMS.yamlPemCas) {
          CERT_PARMS.yamlPemCas=importedCAs;
        } else {
          CERT_PARMS.yamlPemCas+=`,${importedCAs}`;
        }
      }
    }

    // lock keystore directory with proper permission
    // - group permission is none
    // NOTE: njq returns `null` or empty for boolean false, so let's check true
    if (CERT_PARMS.pkcs12Lock && (CERT_PARMS.pkcs12Lock.toLowerCase() == "true")) {
      shell.execSync('sh', '-c', 'zwe '+
                     `certificate pkcs12 lock `+
                     `--keystore-dir "${CERT_PARMS.pkcs12Directory}" `+
                     `--user "${securityUsersZowe}" `+
                     `--group "${securityGroupsAdmin}" `+
                     `--group-permission none`);
    }

    // update zowe.yaml
    if (std.getenv('ZWE_CLI_PARAMETER_UPDATE_CONFIG') == "true") {
      common.printLevel1Message(`Update certificate configuration to ${std.getenv('ZWE_CLI_PARAMETER_CONFIG')}`);
      const updateObj = {
        zowe: {
          certificate: {
            keystore: {
              type: 'PKCS12',
              file: `${CERT_PARMS.pkcs12Directory}/${CERT_PARMS.pkcs12Name}/${CERT_PARMS.pkcs12Name}.keystore.p12`,
              password: CERT_PARMS.pkcs12Password,
              alias: CERT_PARMS.pkcs12NameLc
            },
            truststore: {
              type: 'PKCS12',
              file: `${CERT_PARMS.pkcs12Directory}/${CERT_PARMS.pkcs12Name}/${CERT_PARMS.pkcs12Name}.truststore.p12`,
              password: CERT_PARMS.pkcs12Password
            },
            pem: {
              key: `${CERT_PARMS.pkcs12Directory}/${CERT_PARMS.pkcs12Name}/${CERT_PARMS.pkcs12NameLc}.key`,
              certificate: `${CERT_PARMS.pkcs12Directory}/${CERT_PARMS.pkcs12Name}/${CERT_PARMS.pkcs12NameLc}.cer`,
              certificateAuthorities: CERT_PARMS.yamlPemCas
            }
          }
        }
      };
      jsonlib.updateZoweYamlFromObj(std.getenv('ZWE_CLI_PARAMETER_CONFIG'), updateObj);
      common.printLevel2Message(`Zowe configuration is updated successfully.`);
    } else {
      common.printLevel1Message(`Update certificate configuration to ${std.getenv('ZWE_CLI_PARAMETER_CONFIG')}`);
      common.printMessage(`Please manually update to these values:`);
      common.printMessage(``);
      common.printMessage(`zowe:`);
      common.printMessage(`  certificate:`);
      common.printMessage(`    keystore:`);
      common.printMessage(`      type: PKCS12`);
      common.printMessage(`      file: ${CERT_PARMS.pkcs12Directory}/${CERT_PARMS.pkcs12Name}/${CERT_PARMS.pkcs12Name}.keystore.p12"`);
      common.printMessage(`      password: ${CERT_PARMS.pkcs12Password}"`);
      common.printMessage(`      alias: ${CERT_PARMS.pkcs12NameLc}"`);
      common.printMessage(`    truststore:`);
      common.printMessage(`      type: PKCS12`);
      common.printMessage(`      file: ${CERT_PARMS.pkcs12Directory}/${CERT_PARMS.pkcs12Name}/${CERT_PARMS.pkcs12Name}.truststore.p12"`);
      common.printMessage(`      password: ${CERT_PARMS.pkcs12Password}"`);
      common.printMessage(`    pem:`);
      common.printMessage(`      key: ${CERT_PARMS.pkcs12Directory}/${CERT_PARMS.pkcs12Name}/${CERT_PARMS.pkcs12NameLc}.key"`);
      common.printMessage(`      certificate: ${CERT_PARMS.pkcs12Directory}/${CERT_PARMS.pkcs12Name}/${CERT_PARMS.pkcs12NameLc}.cer"`);
      common.printMessage(`      certificateAuthorities: "${CERT_PARMS.yamlPemCas}"`);
      common.printMessage(``);
      common.printLevel2Message(`Zowe configuration requires manual updates.`);
    }

  } else if (certType == "JCERACFKS") {
    // FIXME: how do we check if keyring exists without permission on RDATALIB?
    // should we clean up before creating new
    if (std.getenv('ZWE_CLI_PARAMETER_ALLOW_OVERWRITE') == "true") {
      // warning
      common.printMessage(`Warning ZWEL0300W: Keyring "safkeyring:///${CERT_PARMS.keyringOwner}/${CERT_PARMS.keyringName}" will be overwritten during configuration.`);

      shell.execSync('sh', '-c', 'zwe '+
                     `certificate keyring-jcl clean `+
                     `--dataset-prefix "${prefix}" `+
                     `--jcllib "${jcllib}" `+
                     `--keyring-owner "${CERT_PARMS.keyringOwner}" `+
                     `--keyring-name "${CERT_PARMS.keyringName}" `+
                     `--alias "${CERT_PARMS.keyringLabel}" `+
                     `--ca-alias "${CERT_PARMS.keyringCaLabel}" `+
                     `--security-product "${securityProduct}"`);
    } else {
      // error
      // common.printErrorAndExit(`Error ZWEL0158E: Keyring "safkeyring:///${CERT_PARMS.keyringOwner}/${CERT_PARMS.keyringName}" already exists.`, undefined, 158
    }

    switch (CERT_PARMS.keyringOption) {
      case 1:
        // generate new cert in keyring
        shell.execSync('sh', '-c', 'zwe '+
                       `certificate keyring-jcl generate `+
                       `--dataset-prefix "${prefix}" `+
                       `--jcllib "${jcllib}" `+
                       `--keyring-owner "${CERT_PARMS.keyringOwner}" `+
                       `--keyring-name "${CERT_PARMS.keyringName}" `+
                       `--alias "${CERT_PARMS.keyringLabel}" `+
                       `--ca-alias "${CERT_PARMS.keyringCaLabel}" `+
                       `--trust-cas "${certImportCAs}" `+
                       `--common-name "${CERT_PARMS.dnameCommonName}" `+
                       `--org-unit "${CERT_PARMS.dnameOrgUnit}" `+
                       `--org "${CERT_PARMS.dnameOrg}" `+
                       `--locality "${CERT_PARMS.dnameLocality}" `+
                       `--state "${CERT_PARMS.dnameState}" `+
                       `--country "${CERT_PARMS.dnameCountry}" `+
                       `--validity "${certValidity}" `+
                       `--security-product "${securityProduct}" `+
                       `--domains "${certDomains}" `+
                       `"${CERT_PARMS.keyringTrustZosmf}" `+
                       `--zosmf-ca "${CERT_PARMS.zosmfCa}" `+
                       `--zosmf-user "${CERT_PARMS.zosmfUser}`);
      
        CERT_PARMS.yamlKeyringLabel=CERT_PARMS.keyringLabel;
        // keyring string for self-signed CA
        CERT_PARMS.yamlPemCas=`safkeyring:////${CERT_PARMS.keyringOwner}/${CERT_PARMS.keyringName}&${CERT_PARMS.keyringCaLabel}`;
        break;
      case 2:
        // connect existing certs to zowe keyring
        shell.execSync('sh', '-c', 'zwe '+
                       `certificate keyring-jcl connect `+
                       `--dataset-prefix "${prefix}" `+
                       `--jcllib "${jcllib}" `+
                       `--keyring-owner "${CERT_PARMS.keyringOwner}" `+
                       `--keyring-name "${CERT_PARMS.keyringName}" `+
                       `--trust-cas "${certImportCAs}" `+
                       `--connect-user "${CERT_PARMS.keyringConnectUser}" `+
                       `--connect-label "${CERT_PARMS.keyringConnectLabel}" `+
                       `--security-product "${securityProduct}" `+
                       `"${CERT_PARMS.keyringTrustZosmf}" `+
                       `--zosmf-ca "${CERT_PARMS.zosmfCa}" `+
                       `--zosmf-user "${CERT_PARMS.zosmfUser}`);

        CERT_PARMS.yamlKeyringLabel=CERT_PARMS.keyringConnectLabel;
        break;
      case 3:
        // import certs from data set into zowe keyring
        shell.execSync('sh', '-c', 'zwe '+
                       `certificate keyring-jcl import-ds `+
                       `--dataset-prefix "${prefix}" `+
                       `--jcllib "${jcllib}" `+
                       `--keyring-owner "${CERT_PARMS.keyringOwner}" `+
                       `--keyring-name "${CERT_PARMS.keyringName}" `+
                       `--alias "${CERT_PARMS.keyringLabel}" `+
                       `--trust-cas "${certImportCAs}" `+
                       `--import-ds-name "${CERT_PARMS.keyringImportDsName}" `+
                       `--import-ds-password "${CERT_PARMS.keyringImportPassword}" `+
                       `--security-product "${securityProduct}" `+
                       `"${CERT_PARMS.keyringTrustZosmf}" `+
                       `--zosmf-ca "${CERT_PARMS.zosmfCa}" `+
                       `--zosmf-user "${CERT_PARMS.zosmfUser}`);
        // FIXME: currently ZWEKRING jcl will import the cert and chain, CA will also be added to CERTAUTH, but the CA will not be connected to keyring.
        //        the CA imported could have label like LABEL00000001.

        CERT_PARMS.yamlKeyringLabel=CERT_PARMS.keyringLabel;
        break;
    }

    if (certImportCAs) {
      // append imported CAs to list
      certImportCAs.split(',').forEach((item:string)=> {
        item=item.trim();
        if (item.length>0) {
          if (CERT_PARMS.yamlPemCas) {
            CERT_PARMS.yamlPemCas=`${CERT_PARMS.yamlPemCas},safkeyring:////${CERT_PARMS.keyringOwner}/${CERT_PARMS.keyringName}&${item}`;
          } else {
            CERT_PARMS.yamlPemCas=`safkeyring:////${CERT_PARMS.keyringOwner}/${CERT_PARMS.keyringName}&${item}`;
          }
        }
      });
    }

    // update zowe.yaml
    if (std.getenv('ZWE_CLI_PARAMETER_UPDATE_CONFIG') == "true") {
      common.printLevel1Message(`Update certificate configuration to ${std.getenv('ZWE_CLI_PARAMETER_CONFIG')}`);
      const updateObj = {
        zowe: {
          certificate: {
            keystore: {
              type: "JCERACFKS",
              file: `safkeyring:////${CERT_PARMS.keyringOwner}/${CERT_PARMS.keyringName}`,
              // we must set a dummy value here, other JDK will complain wrong parameter
              password: "password",
              alias: CERT_PARMS.yamlKeyringLabel
            },
            truststore: {
              type: "JCERACFKS",
              file: `safkeyring:////${CERT_PARMS.keyringOwner}/${CERT_PARMS.keyringName}`,
              password: "password"
            },
            pem: {
              key: '',
              certificate: '',
              certificateAuthorities: ''
            }
          }
        }
      };
      jsonlib.updateZoweYamlFromObj(std.getenv('ZWE_CLI_PARAMETER_CONFIG'), updateObj);
      common.printLevel2Message(`Zowe configuration is updated successfully.`);
    } else {
      common.printLevel1Message(`Update certificate configuration to ${std.getenv('ZWE_CLI_PARAMETER_CONFIG')}`);
      common.printMessage(`Please manually update to these values:`);
      common.printMessage(``);
      common.printMessage(`zowe:`);
      common.printMessage(`  certificate:`);
      common.printMessage(`    keystore:`);
      common.printMessage(`      type: JCERACFKS`);
      common.printMessage(`      file: "safkeyring:////${CERT_PARMS.keyringOwner}/${CERT_PARMS.keyringName}"`);
      common.printMessage(`      password: "password"`);
      common.printMessage(`      alias: "${CERT_PARMS.yamlKeyringLabel}"`);
      common.printMessage(`    truststore:`);
      common.printMessage(`      type: JCERACFKS`);
      common.printMessage(`      file: "safkeyring:////${CERT_PARMS.keyringOwner}/${CERT_PARMS.keyringName}"`);
      common.printMessage(`      password: "password"`);
      common.printMessage(`    pem:`);
      common.printMessage(`      key: ""`);
      common.printMessage(`      certificate: ""`);
      common.printMessage(`      certificateAuthorities: ""`);
      common.printMessage(``);
      common.printLevel2Message(`Zowe configuration requires manual updates.`);
    }
  }

  if (CERT_PARMS.zosmfHost && verifyCertificates == "STRICT") {
    // CN/SAN must be valid if z/OSMF is used and in strict mode
    shell.execSync('sh', '-c', 'zwe '+
                   `certificate verify-service `+
                   `--host "${CERT_PARMS.zosmfHost}" `+
                   `--port "${CERT_PARMS.zosmfPort}"`);
  }
}
