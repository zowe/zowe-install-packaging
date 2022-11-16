/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'std';
import * as common from '../../../libs/common';
import * as stringlib from '../../../libs/string';
import * as jsonlib from '../../../libs/json';
import * as shell from '../../../libs/shell';
import * as config from '../../../libs/config';

const ZWE_CLI_PARM_KEYS = Object.keys(std.getenviron()).filter((key: string)=> {
  return key.startsWith('ZWE_CLI_PARAMETER');
});
const ZWE_CLI_ENVS = {};
ZWE_CLI_PARM_KEYS.forEach((key: string)=>{
  ZWE_CLI_ENVS[key] = std.getenv(key);
});

function zweExec(command: string): void {
  const result = shell.execZweSync(command, ZWE_CLI_ENVS);
  if (result.rc != 0) {
    common.printErrorAndExit(`Error ZWEL0305E: Failed to call certificate command, rc=${result.rc}.`, undefined, 305);
  }
}

export function execute() {
  common.printLevel1Message(`Initializing Zowe keystore`);

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
    if (!CERT_PARMS.pkcs12_directory) {
      common.printErrorAndExit(`Error ZWEL0157E: Keystore directory (zowe.setup.certificate.pkcs12.directory) is not defined in Zowe YAML configuration file.`, undefined, 157);
    }
    // read keystore import info
    ['keystore', 'password', 'alias'].forEach((item:string)=> {
      CERT_PARMS[`pkcs12_import_${item}`] = zoweConfig.zowe.setup.certificate.pkcs12.import ? zoweConfig.zowe.setup.certificate.pkcs12.import[item] : undefined;
    });
    if (CERT_PARMS.pkcs12_import_keystore) {
      if (!CERT_PARMS.pkcs12_import_password) {
        common.printErrorAndExit(`Error ZWEL0157E: Password for import keystore (zowe.setup.certificate.pkcs12.import.password) is not defined in Zowe YAML configuration file.`, undefined, 157);
      }
      if (!CERT_PARMS.pkcs12_import_alias) {
        common.printErrorAndExit(`Error ZWEL0157E: Certificate alias of import keystore (zowe.setup.certificate.pkcs12.import.alias) is not defined in Zowe YAML configuration file.`, undefined, 157);
      }
    }
  } else if  (certType == "JCERACFKS") {
    CERT_PARMS.keyring_option=1;
    // read keyring info
    ['owner', 'name', 'label', 'caLabel'].forEach((item:string) => {
      CERT_PARMS[`keyring_${item}`] = zoweConfig.zowe.setup.certificate.keyring ? zoweConfig.zowe.setup.certificate.keyring[item] : undefined;
    });
    if (!CERT_PARMS.keyring_name) {
      common.printErrorAndExit(`Error ZWEL0157E: Zowe keyring name (zowe.setup.certificate.keyring.name) is not defined in Zowe YAML configuration file.`, undefined, 157);
    }
    CERT_PARMS.keyring_import_dsName = zoweConfig.zowe.setup.certificate.keyring.import ? zoweConfig.zowe.setup.certificate.keyring.import.dsName : undefined;
    CERT_PARMS.keyring_import_password = zoweConfig.zowe.setup.certificate.keyring.import ? zoweConfig.zowe.setup.certificate.keyring.import.password : undefined;
    if (CERT_PARMS.keyring_import_dsName) {
      CERT_PARMS.keyring_option=3;
      if (!CERT_PARMS.keyring_import_password) {
        common.printErrorAndExit(`Error ZWEL0157E: The password for data set storing importing certificate (zowe.setup.certificate.keyring.import.password) is not defined in Zowe YAML configuration file.`, undefined, 157);
      }
    }
    CERT_PARMS.keyring_connect_user = zoweConfig.zowe.setup.certificate.keyring.connect ? zoweConfig.zowe.setup.certificate.keyring.connect.user : undefined;
    CERT_PARMS.keyring_connect_label = zoweConfig.zowe.setup.certificate.keyring.connect ? zoweConfig.zowe.setup.certificate.keyring.connect.label : undefined;
    if (CERT_PARMS.keyring_connect_label) {
      CERT_PARMS.keyring_option=2;
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
    CERT_PARMS[`zosmf_${item}`] =  zoweConfig.zowe.setup.certificate.keyring?.zOSMF ? zoweConfig.zowe.setup.certificate.keyring.zOSMF[item] : undefined;
  });
  ['host', 'port'].forEach((item: string)=> {
    CERT_PARMS[`zosmf_${item}`] = zoweConfig.zOSMF ? zoweConfig.zOSMF[item] : undefined;
  });
  let verifyCertificates = zoweConfig.zowe.verifyCertificates ? zoweConfig.zowe.verifyCertificates.toUpperCase() : undefined;
  if (verifyCertificates == "STRICT" || verifyCertificates == "NONSTRICT") {
    CERT_PARMS.keyring_trust_zosmf="--trust-zosmf";
    CERT_PARMS.zosmf_host = std.getenv('zosmf_host');
    CERT_PARMS.zosmf_port = std.getenv('zosmf_port');
  } else {
    delete CERT_PARMS.zosmf_host;
    delete CERT_PARMS.zosmf_port;
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
    if (!CERT_PARMS.pkcs12_caAlias) {
      CERT_PARMS.pkcs12_caAlias='localCa';
    }
    if (!CERT_PARMS.pkcs12_caPassword) {
      CERT_PARMS.pkcs12_caPassword='localCaPassword';
    }
    if (!CERT_PARMS.pkcs12_name) {
      CERT_PARMS.pkcs12_name='localhost';
    }
    if (!CERT_PARMS.pkcs12_password) {
      CERT_PARMS.pkcs12_password='password';
    }
  } else if  (certType == "JCERACFKS") {
    if (!CERT_PARMS.keyring_owner) {
      CERT_PARMS.keyring_owner=securityUsersZowe;
    }
    if (!CERT_PARMS.keyring_label) {
      CERT_PARMS.keyring_label='localhost';
    }
    if (CERT_PARMS.keyring_option == 1) {
      if (!CERT_PARMS.keyring_caLabel) {
        CERT_PARMS.keyring_caLabel='localca';
      }
    } else {
      // for import case, this variable is not used
      delete CERT_PARMS.keyring_caLabel;
    }
    if (!CERT_PARMS.zosmf_ca && securityProduct == "RACF" && CERT_PARMS.zosmf_host) {
      CERT_PARMS.zosmf_ca="_auto_";
    }
  }
  CERT_PARMS.pkcs12_name_lc=CERT_PARMS.pkcs12_name.toLowerCase();
  CERT_PARMS.pkcs12_caAlias_lc=CERT_PARMS.pkcs12_caAlias.toLowerCase();
  // what PEM format CAs we should tell Zowe to use
  delete CERT_PARMS.yaml_pem_cas;

  if (certType == "PKCS12") {
    if (CERT_PARMS.pkcs12_import_keystore) {
      // import from another keystore
      zweExec(stringlib.stripUndefined(
                     `certificate pkcs12 import `+
                     `--keystore "${CERT_PARMS.pkcs12_directory}/${CERT_PARMS.pkcs12_name}/${CERT_PARMS.pkcs12_name}.keystore.p12" `+
                     `--password "${CERT_PARMS.pkcs12_password}" `+
                     `--alias "${CERT_PARMS.pkcs12_name}" `+
                     `--source-keystore "${CERT_PARMS.pkcs12_import_keystore}" `+
                     `--source-password "${CERT_PARMS.pkcs12_import_password}" `+
                     `--source-alias "${CERT_PARMS.pkcs12_import_alias}"`));
    } else {
      // create CA
      zweExec(stringlib.stripUndefined(
                     `certificate pkcs12 create ca `+
                     `--keystore-dir "${CERT_PARMS.pkcs12_directory}" `+
                     `--alias "${CERT_PARMS.pkcs12_caAlias}" `+
                     `--password "${CERT_PARMS.pkcs12_caPassword}" `+
                     `--common-name "${CERT_PARMS.dname_caCommonName}" `+
                     `--org-unit "${CERT_PARMS.dname_orgUnit}" `+
                     `--org "${CERT_PARMS.dname_org}" `+
                     `--locality "${CERT_PARMS.dname_locality}" `+
                     `--state "${CERT_PARMS.dname_state}" `+
                     `--country "${CERT_PARMS.dname_country}" `+
                     `--validity "${certValidity}"`));

      // export CA cert in PEM format
      zweExec(stringlib.stripUndefined(
                     `certificate pkcs12 export `+
                     `--keystore "${CERT_PARMS.pkcs12_directory}/${CERT_PARMS.pkcs12_caAlias}/${CERT_PARMS.pkcs12_caAlias}.keystore.p12" `+
                     `--password "${CERT_PARMS.pkcs12_caPassword}"`));

      CERT_PARMS.yaml_pem_cas=`${CERT_PARMS.pkcs12_directory}/${CERT_PARMS.pkcs12_caAlias}/${CERT_PARMS.pkcs12_caAlias_lc}.cer`;

      // create default cert
      zweExec(stringlib.stripUndefined(
                     `certificate pkcs12 create cert `+
                     `--keystore-dir "${CERT_PARMS.pkcs12_directory}" `+
                     `--keystore "${CERT_PARMS.pkcs12_name}" `+
                     `--alias "${CERT_PARMS.pkcs12_name}" `+
                     `--password "${CERT_PARMS.pkcs12_password}" `+
                     `--common-name "${CERT_PARMS.dname_caCommonName}" `+
                     `--org-unit "${CERT_PARMS.dname_orgUnit}" `+
                     `--org "${CERT_PARMS.dname_org}" `+
                     `--locality "${CERT_PARMS.dname_locality}" `+
                     `--state "${CERT_PARMS.dname_state}" `+
                     `--country "${CERT_PARMS.dname_country}" `+
                     `--validity "${certValidity}" `+
                     `--ca-alias "${CERT_PARMS.pkcs12_caAlias}" `+
                     `--ca-password "${CERT_PARMS.pkcs12_caPassword}" `+
                     `--domains "${certDomains}"`));
    }

    // import extra CAs if they are defined
    if (certImportCAs) {
      // also imported to keystore to maintain full chain
      zweExec(stringlib.stripUndefined(
                     `certificate pkcs12 import `+
                     `--keystore "${CERT_PARMS.pkcs12_directory}/${CERT_PARMS.pkcs12_name}/${CERT_PARMS.pkcs12_name}.keystore.p12" `+
                     `--password "${CERT_PARMS.pkcs12_password}" `+
                     `--alias "" `+
                     `--source-keystore "" `+
                     `--source-password "" `+
                     `--source-alias "" `+
                     `--trust-cas "${certImportCAs}"`));

      zweExec(stringlib.stripUndefined(
                     `certificate pkcs12 import `+
                     `--keystore "${CERT_PARMS.pkcs12_directory}/${CERT_PARMS.pkcs12_name}/${CERT_PARMS.pkcs12_name}.truststore.p12" `+
                     `--password "${CERT_PARMS.pkcs12_password}" `+
                     `--alias "" `+
                     `--source-keystore "" `+
                     `--source-password "" `+
                     `--source-alias "" `+
                     `--trust-cas "${certImportCAs}"`));
    }

    // trust z/OSMF
    if (CERT_PARMS.zosmf_host && CERT_PARMS.zosmf_port
        && (verifyCertificates == "STRICT" || verifyCertificates == "NONSTRICT")) {
      zweExec(stringlib.stripUndefined(
                     `certificate pkcs12 trust-service `+
                     `--service-name "z/OSMF" `+
                     `--keystore-dir "${CERT_PARMS.pkcs12_directory}" `+
                     `--keystore "${CERT_PARMS.pkcs12_name}" `+
                     `--password "${CERT_PARMS.pkcs12_password}" `+
                     `--host "${CERT_PARMS.zosmf_host}" `+
                     `--port "${CERT_PARMS.zosmf_port}" `+
                     `--alias "zosmf"`));
    }

    // export all certs in PEM format
    zweExec(stringlib.stripUndefined(
                   `certificate pkcs12 export `+
                   `--keystore "${CERT_PARMS.pkcs12_directory}/${CERT_PARMS.pkcs12_name}/${CERT_PARMS.pkcs12_name}.keystore.p12" `+
                   `--password "${CERT_PARMS.pkcs12_password}" `+
                   `--private-keys "${CERT_PARMS.pkcs12_name}"`));
    zweExec(stringlib.stripUndefined(
                   `certificate pkcs12 export `+
                   `--keystore "${CERT_PARMS.pkcs12_directory}/${CERT_PARMS.pkcs12_name}/${CERT_PARMS.pkcs12_name}.truststore.p12" `+
                   `--password "${CERT_PARMS.pkcs12_password}" `+
                   `--private-keys ""`));

    // after we export truststore, the imported CAs will be exported as extca*.cer
    if (certImportCAs) {
      const getImportedCAs=shell.execOutSync('sh', '-c', `find "${CERT_PARMS.pkcs12_directory}/"${CERT_PARMS.pkcs12_name}" -name 'extca*.cer' -type f 2>&1`);
      if (getImportedCAs.rc == 0) {
        const importedCAs = getImportedCAs.out.split('\n').join(',');
        if (!CERT_PARMS.yaml_pem_cas) {
          CERT_PARMS.yaml_pem_cas=importedCAs;
        } else {
          CERT_PARMS.yaml_pem_cas+=`,${importedCAs}`;
        }
      }
    }

    // lock keystore directory with proper permission
    // - group permission is none
    // NOTE: njq returns `null` or empty for boolean false, so let's check true
    if (CERT_PARMS.pkcs12_lock && (CERT_PARMS.pkcs12_lock.toLowerCase() == "true")) {
      zweExec(stringlib.stripUndefined(
                     `certificate pkcs12 lock `+
                     `--keystore-dir "${CERT_PARMS.pkcs12_directory}" `+
                     `--user "${securityUsersZowe}" `+
                     `--group "${securityGroupsAdmin}" `+
                     `--group-permission none`));
    }

    // update zowe.yaml
    if (std.getenv('ZWE_CLI_PARAMETER_UPDATE_CONFIG') == "true") {
      common.printLevel1Message(`Update certificate configuration to ${std.getenv('ZWE_CLI_PARAMETER_CONFIG')}`);
      const updateObj = {
        zowe: {
          certificate: {
            keystore: {
              type: 'PKCS12',
              file: `${CERT_PARMS.pkcs12_directory}/${CERT_PARMS.pkcs12_name}/${CERT_PARMS.pkcs12_name}.keystore.p12`,
              password: CERT_PARMS.pkcs12_password,
              alias: CERT_PARMS.pkcs12_name_lc
            },
            truststore: {
              type: 'PKCS12',
              file: `${CERT_PARMS.pkcs12_directory}/${CERT_PARMS.pkcs12_name}/${CERT_PARMS.pkcs12_name}.truststore.p12`,
              password: CERT_PARMS.pkcs12_password
            },
            pem: {
              key: `${CERT_PARMS.pkcs12_directory}/${CERT_PARMS.pkcs12_name}/${CERT_PARMS.pkcs12_name_lc}.key`,
              certificate: `${CERT_PARMS.pkcs12_directory}/${CERT_PARMS.pkcs12_name}/${CERT_PARMS.pkcs12_name_lc}.cer`,
              certificateAuthorities: CERT_PARMS.yaml_pem_cas
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
      common.printMessage(`      file: "${CERT_PARMS.pkcs12_directory}/${CERT_PARMS.pkcs12_name}/${CERT_PARMS.pkcs12_name}.keystore.p12"`);
      common.printMessage(`      password: "${CERT_PARMS.pkcs12_password}"`);
      common.printMessage(`      alias: "${CERT_PARMS.pkcs12_name_lc}"`);
      common.printMessage(`    truststore:`);
      common.printMessage(`      type: PKCS12`);
      common.printMessage(`      file: "${CERT_PARMS.pkcs12_directory}/${CERT_PARMS.pkcs12_name}/${CERT_PARMS.pkcs12_name}.truststore.p12"`);
      common.printMessage(`      password: "${CERT_PARMS.pkcs12_password}"`);
      common.printMessage(`    pem:`);
      common.printMessage(`      key: "${CERT_PARMS.pkcs12_directory}/${CERT_PARMS.pkcs12_name}/${CERT_PARMS.pkcs12_name_lc}.key"`);
      common.printMessage(`      certificate: "${CERT_PARMS.pkcs12_diryectory}/${CERT_PARMS.pkcs12_name}/${CERT_PARMS.pkcs12_name_lc}.cer"`);
      common.printMessage(`      certificateAuthorities: "${CERT_PARMS.yaml_pem_cas}"`);
      common.printMessage(``);
      common.printLevel2Message(`Zowe configuration requires manual updates.`);
    }

  } else if (certType == "JCERACFKS") {
    // FIXME: how do we check if keyring exists without permission on RDATALIB?
    // should we clean up before creating new
    if (std.getenv('ZWE_CLI_PARAMETER_ALLOW_OVERWRITE') == "true") {
      // warning
      common.printMessage(`Warning ZWEL0300W: Keyring "safkeyring:///${CERT_PARMS.keyring_owner}/${CERT_PARMS.keyring_name}" will be overwritten during configuration.`);

      zweExec(stringlib.stripUndefined(
                     `certificate keyring-jcl clean `+
                     `--dataset-prefix "${prefix}" `+
                     `--jcllib "${jcllib}" `+
                     `--keyring-owner "${CERT_PARMS.keyring_owner}" `+
                     `--keyring-name "${CERT_PARMS.keyring_name}" `+
                     `--alias "${CERT_PARMS.keyring_label}" `+
                     `--ca-alias "${CERT_PARMS.keyring_caLabel}" `+
                     `--security-product "${securityProduct}"`));
    } else {
      // error
      // common.printErrorAndExit(`Error ZWEL0158E: Keyring "safkeyring:///${CERT_PARMS.keyring_owner}/${CERT_PARMS.keyring_name}" already exists.`, undefined, 158
    }

    switch (CERT_PARMS.keyring_option) {
      case 1:
        // generate new cert in keyring
        zweExec(stringlib.stripUndefined(
                       `certificate keyring-jcl generate `+
                       `--dataset-prefix "${prefix}" `+
                       `--jcllib "${jcllib}" `+
                       `--keyring-owner "${CERT_PARMS.keyring_owner}" `+
                       `--keyring-name "${CERT_PARMS.keyring_name}" `+
                       `--alias "${CERT_PARMS.keyring_label}" `+
                       `--ca-alias "${CERT_PARMS.keyring_caLabel}" `+
                       `--trust-cas "${certImportCAs}" `+
                       `--common-name "${CERT_PARMS.dname_commonName}" `+
                       `--org-unit "${CERT_PARMS.dname_orgUnit}" `+
                       `--org "${CERT_PARMS.dname_org}" `+
                       `--locality "${CERT_PARMS.dname_locality}" `+
                       `--state "${CERT_PARMS.dname_state}" `+
                       `--country "${CERT_PARMS.dname_country}" `+
                       `--validity "${certValidity}" `+
                       `--security-product "${securityProduct}" `+
                       `--domains "${certDomains}" `+
                       `"${CERT_PARMS.keyring_trust_zosmf}" `+
                       `--zosmf-ca "${CERT_PARMS.zosmf_ca}" `+
                       `--zosmf-user "${CERT_PARMS.zosmf_user}`));
      
        CERT_PARMS.yaml_keyring_label=CERT_PARMS.keyring_label;
        // keyring string for self-signed CA
        CERT_PARMS.yaml_pem_cas=`safkeyring:////${CERT_PARMS.keyring_owner}/${CERT_PARMS.keyring_name}&${CERT_PARMS.keyring_caLabel}`;
        break;
      case 2:
        // connect existing certs to zowe keyring
        zweExec(stringlib.stripUndefined(
                       `certificate keyring-jcl connect `+
                       `--dataset-prefix "${prefix}" `+
                       `--jcllib "${jcllib}" `+
                       `--keyring-owner "${CERT_PARMS.keyring_owner}" `+
                       `--keyring-name "${CERT_PARMS.keyring_name}" `+
                       `--trust-cas "${certImportCAs}" `+
                       `--connect-user "${CERT_PARMS.keyring_connect_user}" `+
                       `--connect-label "${CERT_PARMS.keyring_connect_label}" `+
                       `--security-product "${securityProduct}" `+
                       `"${CERT_PARMS.keyring_trust_zosmf}" `+
                       `--zosmf-ca "${CERT_PARMS.zosmf_ca}" `+
                       `--zosmf-user "${CERT_PARMS.zosmf_user}`));

        CERT_PARMS.yaml_keyring_label=CERT_PARMS.keyring_connect_label;
        break;
      case 3:
        // import certs from data set into zowe keyring
        zweExec(stringlib.stripUndefined(
                       `certificate keyring-jcl import-ds `+
                       `--dataset-prefix "${prefix}" `+
                       `--jcllib "${jcllib}" `+
                       `--keyring-owner "${CERT_PARMS.keyring_owner}" `+
                       `--keyring-name "${CERT_PARMS.keyring_name}" `+
                       `--alias "${CERT_PARMS.keyring_label}" `+
                       `--trust-cas "${certImportCAs}" `+
                       `--import-ds-name "${CERT_PARMS.keyring_import_dsName}" `+
                       `--import-ds-password "${CERT_PARMS.keyring_import_password}" `+
                       `--security-product "${securityProduct}" `+
                       `"${CERT_PARMS.keyring_trust_zosmf}" `+
                       `--zosmf-ca "${CERT_PARMS.zosmf_ca}" `+
                       `--zosmf-user "${CERT_PARMS.zosmf_user}`));
        // FIXME: currently ZWEKRING jcl will import the cert and chain, CA will also be added to CERTAUTH, but the CA will not be connected to keyring.
        //        the CA imported could have label like LABEL00000001.

        CERT_PARMS.yaml_keyring_label=CERT_PARMS.keyring_label;
        break;
    }

    if (certImportCAs) {
      // append imported CAs to list
      certImportCAs.split(',').forEach((item:string)=> {
        item=item.trim();
        if (item.length>0) {
          if (CERT_PARMS.yaml_pem_cas) {
            CERT_PARMS.yaml_pem_cas=`${CERT_PARMS.yaml_pem_cas},safkeyring:////${CERT_PARMS.keyring_owner}/${CERT_PARMS.keyring_name}&${item}`;
          } else {
            CERT_PARMS.yaml_pem_cas=`safkeyring:////${CERT_PARMS.keyring_owner}/${CERT_PARMS.keyring_name}&${item}`;
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
              file: `safkeyring:////${CERT_PARMS.keyring_owner}/${CERT_PARMS.keyring_name}`,
              // we must set a dummy value here, other JDK will complain wrong parameter
              password: "password",
              alias: CERT_PARMS.yaml_keyring_label
            },
            truststore: {
              type: "JCERACFKS",
              file: `safkeyring:////${CERT_PARMS.keyring_owner}/${CERT_PARMS.keyring_name}`,
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
      common.printMessage(`      file: "safkeyring:////${CERT_PARMS.keyring_owner}/${CERT_PARMS.keyring_name}"`);
      common.printMessage(`      password: "password"`);
      common.printMessage(`      alias: "${CERT_PARMS.yaml_keyring_label}"`);
      common.printMessage(`    truststore:`);
      common.printMessage(`      type: JCERACFKS`);
      common.printMessage(`      file: "safkeyring:////${CERT_PARMS.keyring_owner}/${CERT_PARMS.keyring_name}"`);
      common.printMessage(`      password: "password"`);
      common.printMessage(`    pem:`);
      common.printMessage(`      key: ""`);
      common.printMessage(`      certificate: ""`);
      common.printMessage(`      certificateAuthorities: "${CERT_PARMS.yaml_pem_cas}"`);
      common.printMessage(``);
      common.printLevel2Message(`Zowe configuration requires manual updates.`);
    }
  }

  if (CERT_PARMS.zosmf_host && verifyCertificates == "STRICT") {
    // CN/SAN must be valid if z/OSMF is used and in strict mode
    zweExec(stringlib.stripUndefined(
                   `certificate verify-service `+
                   `--host "${CERT_PARMS.zosmf_host}" `+
                   `--port "${CERT_PARMS.zosmf_port}"`));
  }
}
