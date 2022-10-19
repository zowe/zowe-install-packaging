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
import * as shell from '../../../libs/shell';
import * as config from '../../../libs/config';

export function execute() {

  common.printLevel1Message(`APF authorize load libraries`);

  // Constants
  const EVAL_VARS={};

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
  const security_product=zoweConfig.zowe.setup.security?.product;
  const security_users_zowe=zoweConfig.zowe.setup.security?.users?.zowe;
  const security_groups_admin=zoweConfig.zowe.setup.security?.groups?.admin;
  // read cert type and validate
  const cert_type=zoweConfig.zowe.setup.certificate?.type;
  if (!cert_type) {
    common.printErrorAndExit(`Error ZWEL0157E: Certificate type (zowe.setup.certificate.type) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }
  if (cert_type != "PKCS12" && cert_type != "JCERACFKS") {
    common.printErrorAndExit(`Error ZWEL0164E: Value of certificate type (zowe.setup.certificate.type) defined in Zowe YAML configuration file is invalid. Valid values are PKCS12 or JCERACFKS.`, undefined, 164);
  }
  // read cert dname
  ['caCommonName', 'commonName', 'orgUnit', 'org', 'locality', 'state', 'country'].forEach((item:string)=> {
    EVAL_VARS[`dname_${item}`] = zoweConfig.zowe.setup.certificate.dname ? zoweConfig.zowe.setup.certificate.dname[item] : undefined;
  });
  // read cert validity
  cert_validity=zoweConfig.zowe.setup.certificate.validity;
  if (cert_type == "PKCS12") {
    // read keystore info
    ['directory', 'lock', 'name', 'password', 'caAlias', 'caPassword'].forEach((item:string) => {
      EVAL_VARS[`pkcs12_${item}`] = zoweConfig.zowe.setup.certificate.pkcs12 ? zoweConfig.zowe.setup.certificate.pkcs12[item] : undefined;
    });
    if (!EVAL_VARS.pkcs12_directory) {
      common.printErrorAndExit(`Error ZWEL0157E: Keystore directory (zowe.setup.certificate.pkcs12.directory) is not defined in Zowe YAML configuration file.`, undefined, 157);
    }
    // read keystore import info
    ['keystore', 'password', 'alias'].forEach((item:string)=> {
      EVAL_VARS[`pkcs12_import_${item}`] = zoweConfig.zowe.setup.certificate.pkcs12.import ? zoweConfig.zowe.setup.certificate.pkcs12.import[item] : undefined;
    });
    if (EVAL_VARS.pkcs12_import_keystore) {
      if (!EVAL_VARS.pkcs12_import_password) {
        common.printErrorAndExit(`Error ZWEL0157E: Password for import keystore (zowe.setup.certificate.pkcs12.import.password) is not defined in Zowe YAML configuration file.`, undefined, 157);
      }
      if (!EVAL_VARS.pkcs12_import_alias) {
        common.printErrorAndExit(`Error ZWEL0157E: Certificate alias of import keystore (zowe.setup.certificate.pkcs12.import.alias) is not defined in Zowe YAML configuration file.`, undefined, 157);
      }
    }
  } else if  (cert_type == "JCERACFKS") {
    let EVAL_VARS.keyring_option=1;
    // read keyring info
    ['owner', 'name', 'label', 'caLabel'].forEach((item:string) => {
      EVAL_VARS[`keyring_${item}`] = zoweConfig.zowe.setup.certificate.keyring ? zoweConfig.zowe.setup.certificate.keyring[item] : undefined;
    });
    if (!EVAL_VARS.keyring_name) {
      common.printErrorAndExit(`Error ZWEL0157E: Zowe keyring name (zowe.setup.certificate.keyring.name) is not defined in Zowe YAML configuration file.`, undefined, 157);
    }
    EVAL_VARS.keyring_import_dsName = zoweConfig.zowe.setup.certificate.keyring.import ? zoweConfig.zowe.setup.certificate.keyring.import.dsName : undefined;
    EVAL_VARS.keyring_import_password = zoweConfig.zowe.setup.certificate.keyring.import ? zoweConfig.zowe.setup.certificate.keyring.import.password : undefined;
    if (EVAL_VARS.keyring_import_dsName) {
      EVAL_VARS.keyring_option=3;
      if (!EVAL_VARS.keyring_import_password) {
        common.printErrorAndExit(`Error ZWEL0157E: The password for data set storing importing certificate (zowe.setup.certificate.keyring.import.password) is not defined in Zowe YAML configuration file.`, undefined, 157);
      }
    }
    EVAL_VARS.keyring_connect_user = zoweConfig.zowe.setup.certificate.keyring.connect ? zoweConfig.zowe.setup.certificate.keyring.connect.user | undefined;
    EVAL_VARS.keyring_connect_label = zoweConfig.zowe.setup.certificate.keyring.connect ? zoweConfig.zowe.setup.certificate.keyring.connect.label | undefined;
    if (EVAL_VARS.keyring_connect_label) {
      EVAL_VARS.keyring_option=2
    }
  }
  // read keystore domains
  cert_import_CAs=zoweConfig.zowe.setup.certificate.importCertificateAuthorities ? zoweConfig.zowe.setup.certificate.importCertificateAuthorities.split('\n').join(',') : undefined;
  // read keystore domains
  cert_domains=zoweConfig.zowe.setup.certificate.san ? zoweConfig.zowe.setup.certificate.san.split('\n') : undefined;
  if (!cert_domains) {
    cert_domains=zoweConfig.zowe.externalDomains ? zoweConfig.zowe.externalDomains.split('\n') : undefined;
  }
  // read z/OSMF info
  ['user', 'ca'].forEach((item:string)=> {
    EVAL_VARS[`zosmf_${item}`] =  zoweConfig.zowe.setup.certificate.keyring.zOSMF ? zoweConfig.zowe.setup.certificate.keyring.zOSMF[item] : undefined;
  });
  ['host', 'port'].forEach((item: string)=> {
    EVAL_VARS[`zosmf_${item}`] = zoweConfig.zOSMF ? zoweConfig.zOSMF[item] : undefined;
  });
  let verify_certificates = zoweConfig.zowe.verifyCertificates ? zoweConfig.zowe.verifyCertificates.toUpperCase() : undefined;
  if (verify_certificates == "STRICT" || verify_certificates == "NONSTRICT") {
    keyring_trust_zosmf="--trust-zosmf";
    EVAL_VARS.zosmf_host = std.getenv('zosmf_host');
    EVAL_VARS.zosmf_port = std.getenv('zosmf_port');
  } else {
    // no need to trust z/OSMF service
  }

  // set default values
  if (!security_product) {
    security_product='RACF';
  }
  if (!security_users_zowe) {
    security_users_zowe=std.getenv('ZWE_PRIVATE_DEFAULT_ZOWE_USER');
  }
  if (!security_groups_admin) {
    security_groups_admin=std.getenv('ZWE_PRIVATE_DEFAULT_ADMIN_GROUP');
  }
  if (cert_type == "PKCS12") {
    if (!EVAL_VARS.pkcs12_caAlias) {
      EVAL_VARS.pkcs12_caAlias='local_ca';
    }
    if (!EVAL_VARS.pkcs12_caPassword) {
      EVAL_VARS.pkcs12_caPassword='local_ca_password';
    }
    if (!EVAL_VARS.pkcs12_name) {
      EVAL_VARS.pkcs12_name='localhost';
    }
    if (!EVAL_VARS.pkcs12_password) {
      EVAL_VARS.pkcs12_password='password';
    }
  } else if  (cert_type == "JCERACFKS") {
    if (!EVAL_VARS.keyring_owner) {
      EVAL_VARS.keyring_owner=security_users_zowe;
    }
    if (!EVAL_VARS.keyring_label) {
      EVAL_VARS.keyring_label='localhost';
    }
    if (EVAL_VARS.keyring_option == 1) {
      if (!EVAL_VARS.keyring_caLabel) {
        EVAL_VARS.keyring_caLabel='localca';
      }
    } else {
      // for import case, this variable is not used
      delete EVAL_VARS.keyring_caLabel;
    }
    if (!EVAL_VARS.zosmf_ca && security_product == "RACF" && EVAL_VARS.zosmf_host) {
      EVAL_VARS.zosmf_ca="_auto_";
    }
  }
  EVAL_VARS.pkcs12_name_lc=EVAL_VARS.pkcs12_name.toLowerCase();
  EVAL_VARSpkcs12_caAlias_lc=EVAL_VARS.pkcs12_caAlias.toLowerCase();
  // what PEM format CAs we should tell Zowe to use
  delete EVAL_VARS.yaml_pem_cas;

  if (cert_type == "PKCS12") {
    if (EVAL_VARS.pkcs12_import_keystore) {
      // import from another keystore
      shell.execSync('sh', '-c', 'zwe '+
                     `certificate pkcs12 import `+
                     `--keystore "${EVAL_VARS.pkcs12_directory}/${EVAL_VARS.pkcs12_name}/${EVAL_VARS.pkcs12_name}.keystore.p12" `+
                     `--password "${EVAL_VARS.pkcs12_password}" `+
                     `--alias "${EVAL_VARS.pkcs12_name}" `+
                     `--source-keystore "${EVAL_VARS.pkcs12_import_keystore}" `+
                     `--source-password "${EVAL_VARS.pkcs12_import_password}" `+
                     `--source-alias "${EVAL_VARS.pkcs12_import_alias}"`);
    } else {
      // create CA
      shell.execSync('sh', '-c', 'zwe '+
                     `certificate pkcs12 create ca `+
                     `--keystore-dir "${EVAL_VARS.pkcs12_directory}" `+
                     `--alias "${EVAL_VARS.pkcs12_caAlias}" `+
                     `--password "${EVAL_VARS.pkcs12_caPassword}" `+
                     `--common-name "${EVAL_VARS.dname_caCommonName}" `+
                     `--org-unit "${EVAL_VARS.dname_orgUnit}" `+
                     `--org "${EVAL_VARS.dname_org}" `+
                     `--locality "${EVAL_VARS.dname_locality}" `+
                     `--state "${EVAL_VARS.dname_state}" `+
                     `--country "${EVAL_VARS.dname_country}" `+
                     `--validity "${cert_validity}"`);

      // export CA cert in PEM format
      shell.execSync('sh', '-c', 'zwe '+
                     `certificate pkcs12 export `+
                     `--keystore "${EVAL_VARS.pkcs12_directory}/${EVAL_VARS.pkcs12_caAlias}/${EVAL_VARS.pkcs12_caAlias}.keystore.p12" `+
                     `--password "${EVAL_VARS.pkcs12_caPassword}"`);

      const yaml_pem_case=`${EVAL_VARS.pkcs12_directory}/${EVAL_VARS.pkcs12_caAlias}/${EVAL_VARS.pkcs12_caAlias_lc}.cer`;

      // create default cert
      shell.execSync('sh', '-c', 'zwe '+
                     `certificate pkcs12 create cert `+
                     `--keystore-dir "${EVAL_VARS.pkcs12_directory}" `+
                     `--keystore "${EVAL_VARS.pkcs12_name}" `+
                     `--alias "${EVAL_VARS.pkcs12_name}" `+
                     `--password "${EVAL_VARS.pkcs12_password}" `+
                     `--common-name "${EVAL_VARS.dname_caCommonName}" `+
                     `--org-unit "${EVAL_VARS.dname_orgUnit}" `+
                     `--org "${EVAL_VARS.dname_org}" `+
                     `--locality "${EVAL_VARS.dname_locality}" `+
                     `--state "${EVAL_VARS.dname_state}" `+
                     `--country "${EVAL_VARS.dname_country}" `+
                     `--validity "${cert_validity}" `+
                     `--ca-alias "${EVAL_VARS.pkcs12_caAlias}" `+
                     `--ca-password "${EVAL_VARS.pkcs12_caPassword}" `+
                     `--domains "${cert_domains}"`);
    }

    // import extra CAs if they are defined
    if (cert_import_CAs) {
      // also imported to keystore to maintain full chain
      shell.execSync('sh', '-c', 'zwe '+
                     `certificate pkcs12 import `+
                     `--keystore "${EVAL_VARS.pkcs12_directory}/${EVAL_VARS.pkcs12_name}/${EVAL_VARS.pkcs12_name}.keystore.p12" `+
                     `--password "${EVAL_VARS.pkcs12_password}" `+
                     `--alias "" `+
                     `--source-keystore "" `+
                     `--source-password "" `+
                     `--source-alias "" `+
                     `--trust-cas "${cert_import_CAs}"`);

      shell.execSync('sh', '-c', 'zwe '+
                     `certificate pkcs12 import `+
                     `--keystore "${EVAL_VARS.pkcs12_directory}/${EVAL_VARS.pkcs12_name}/${EVAL_VARS.pkcs12_name}.truststore.p12" `+
                     `--password "${EVAL_VARS.pkcs12_password}" `+
                     `--alias "" `+
                     `--source-keystore "" `+
                     `--source-password "" `+
                     `--source-alias "" `+
                     `--trust-cas "${cert_import_CAs}"`);
    }

    // trust z/OSMF
    if (EVAL_VARS.zosmf_host && EVAL_VARS.zosmf_port) {
      shell.execSync('sh', '-c', 'zwe '+
                     `certificate pkcs12 trust-service `+
                     `--service-name "z/OSMF" `+
                     `--keystore-dir "${EVAL_VARS.pkcs12_directory}" `+
                     `--keystore "${EVAL_VARS.pkcs12_name}" `+
                     `--password "${EVAL_VARS.pkcs12_password}" `+
                     `--host "${EVAL_VARS.zosmf_host}" `+
                     `--port "${EVAL_VARS.zosmf_port}" `+
                     `--alias "zosmf"`);
    }

    // export all certs in PEM format
    shell.execSync('sh', '-c', 'zwe '+
                   `certificate pkcs12 export `+
                   `--keystore "${EVAL_VARS.pkcs12_directory}/${EVAL_VARS.pkcs12_name}/${EVAL_VARS.pkcs12_name}.keystore.p12" `+
                   `--password "${EVAL_VARS.pkcs12_password}" `+
                   `--private-keys "${EVAL_VARS.pkcs12_name}"`);
    shell.execSync('sh', '-c', 'zwe '+
                   `certificate pkcs12 export `+
                   `--keystore "${EVAL_VARS.pkcs12_directory}/${EVAL_VARS.pkcs12_name}/${EVAL_VARS.pkcs12_name}.truststore.p12" `+
                   `--password "${EVAL_VARS.pkcs12_password}" `+
                   `--private-keys ""`);

    // after we export truststore, the imported CAs will be exported as extca*.cer
    if (cert_import_CAs) {
      imported_cas=shell.execOutSync('sh', '-c', `find "${EVAL_VARS.pkcs12_directory}/"${EVAL_VARS.pkcs12_name}" -name 'extca*.cer' -type f`).out.split('\n').join(',');
      if (!yaml_pem_cas) {
        yaml_pem_cas=imported_cas;
      } else {
        yaml_pem_cas=`${yaml_pem_cas},${imported_cas}`
      }
    }

    // lock keystore directory with proper permission
    // - group permission is none
    // NOTE: njq returns `null` or empty for boolean false, so let's check true
    if (EVAL_VARS.pkcs12_lock && (EVAL_VARS.pkcs12_lock.toLowerCase() == "true")) {
      shell.execSync('sh', '-c', 'zwe '+
                     `certificate pkcs12 lock `+
                     `--keystore-dir "${EVAL_VARS.pkcs12_directory}" `+
                     `--user "${security_users_zowe}" `+
                     `--group "${security_groups_admin}" `+
                     `--group-permission none`);
    }

    // update zowe.yaml
    if (std.getenv('ZWE_CLI_PARAMETER_UPDATE_CONFIG') == "true") {
      common.printLevel1Message(`Update certificate configuration to ${ZWE_CLI_PARAMETER_CONFIG}`);
      const updateObj = {
        zowe: {
          certificate: {
            keystore: {
              type: 'PKCS12',
              file: `${EVAL_VARS.pkcs12_directory}/${EVAL_VARS.pkcs12_name}/${EVAL_VARS.pkcs12_name}.keystore.p12`,
              password: EVAL_VARS.pkcs12_password,
              alias: EVAL_VARS.pkcs12_name_lc
            },
            truststore: {
              type: 'PKCS12',
              file: `${EVAL_VARS.pkcs12_directory}/${EVAL_VARS.pkcs12_name}/${EVAL_VARS.pkcs12_name}.truststore.p12`,
              password: EVAL_VARS.pkcs12_password
            },
            pem: {
              key: `${EVAL_VARS.pkcs12_directory}/${EVAL_VARS.pkcs12_name}/${EVAL_VARS.pkcs12_name_lc}.key`,
              certificate: `${EVAL_VARS.pkcs12_directory}/${EVAL_VARS.pkcs12_name}/${EVAL_VARS.pkcs12_name_lc}.cer`,
              certificateAuthorities: yaml_pem_cas
            }
          }
        }
      };
      jsonlib.updateZoweYamlFromObj(std.getenv('ZWE_CLI_PARAMETER_CONFIG'), updateObj);
      common.printLevel2Message(`Zowe configuration is updated successfully.`);
    } else {
      common.printLevel1Message(`Update certificate configuration to ${ZWE_CLI_PARAMETER_CONFIG}`);
      common.printMessage(`Please manually update to these values:`);
      common.printMessage(``);
      common.printMessage(`zowe:`);
      common.printMessage(`  certificate:`);
      common.printMessage(`    keystore:`);
      common.printMessage(`      type: PKCS12`);
      common.printMessage(`      file: \${EVAL_VARS.pkcs12_directory}/${EVAL_VARS.pkcs12_name}/${EVAL_VARS.pkcs12_name}.keystore.p12\"`);
      common.printMessage(`      password: \${EVAL_VARS.pkcs12_password}\"`);
      common.printMessage(`      alias: \${EVAL_VARS.pkcs12_name_lc}\"`);
      common.printMessage(`    truststore:`);
      common.printMessage(`      type: PKCS12`);
      common.printMessage(`      file: \${EVAL_VARS.pkcs12_directory}/${EVAL_VARS.pkcs12_name}/${EVAL_VARS.pkcs12_name}.truststore.p12\"`);
      common.printMessage(`      password: \${EVAL_VARS.pkcs12_password}\"`);
      common.printMessage(`    pem:`);
      common.printMessage(`      key: \${EVAL_VARS.pkcs12_directory}/${EVAL_VARS.pkcs12_name}/${EVAL_VARS.pkcs12_name_lc}.key\"`);
      common.printMessage(`      certificate: \${EVAL_VARS.pkcs12_directory}/${EVAL_VARS.pkcs12_name}/${EVAL_VARS.pkcs12_name_lc}.cer\"`);
      common.printMessage(`      certificateAuthorities: \"${yaml_pem_cas}\"`);
      common.printMessage(``);
      common.printLevel2Message(`Zowe configuration requires manual updates.`);
    }

  } else if (cert_type == "JCERACFKS") {
    // FIXME: how do we check if keyring exists without permission on RDATALIB?
    // should we clean up before creating new
    if (std.getenv('ZWE_CLI_PARAMETER_ALLOW_OVERWRITE') == "true") {
      // warning
      common.printMessage(`Warning ZWEL0300W: Keyring \"safkeyring:///${EVAL_VARS.keyring_owner}/${EVAL_VARS.keyring_name}\" will be overwritten during configuration.`);

      shell.execSync('sh', '-c', 'zwe '+
                     `certificate keyring-jcl clean `+
                     `--dataset-prefix "${prefix}" `+
                     `--jcllib "${jcllib}" `+
                     `--keyring-owner "${EVAL_VARS.keyring_owner}" `+
                     `--keyring-name "${EVAL_VARS.keyring_name}" `+
                     `--alias "${EVAL_VARS.keyring_label}" `+
                     `--ca-alias "${EVAL_VARS.keyring_caLabel}" `+
                     `--security-product "${security_product}"`);
    } else {
      // error
      // common.printErrorAndExit(`Error ZWEL0158E: Keyring \"safkeyring:///${keyring_owner}/${keyring_name}\" already exists.`, undefined, 158
    }

  yaml_keyring_label=
  case ${keyring_option} in
    1)
      // generate new cert in keyring
      shell.execSync('sh', '-c', 'zwe '+
        certificate keyring-jcl generate `+
        `--dataset-prefix "${prefix}" `+
        `--jcllib "${jcllib}" `+
        `--keyring-owner "${EVAL_VARS.keyring_owner}" `+
        `--keyring-name "${EVAL_VARS.keyring_name}" `+
        `--alias "${EVAL_VARS.keyring_label}" `+
        `--ca-alias "${EVAL_VARS.keyring_caLabel}" `+
        `--trust-cas "${cert_import_CAs}" `+
        `--common-name "${EVAL_VARS.dname_commonName}" `+
        `--org-unit "${EVAL_VARS.dname_orgUnit}" `+
        `--org "${EVAL_VARS.dname_org}" `+
        `--locality "${EVAL_VARS.dname_locality}" `+
        `--state "${EVAL_VARS.dname_state}" `+
        `--country "${EVAL_VARS.dname_country}" `+
        `--validity "${cert_validity}" `+
        `--security-product "${security_product}" `+
        `--domains "${cert_domains}" `+
        "${EVAL_VARS.keyring_trust_zosmf}" `+
        `--zosmf-ca "${EVAL_VARS.zosmf_ca}" `+
        `--zosmf-user "${EVAL_VARS.zosmf_user}"
      
      yaml_keyring_label=${EVAL_VARS.keyring_label}"
      // keyring string for self-signed CA
      yaml_pem_cas="safkeyring:////${keyring_owner}/${keyring_name}&${keyring_caLabel}"
      ;;
    2)
      // connect existing certs to zowe keyring
      shell.execSync('sh', '-c', 'zwe '+
        certificate keyring-jcl connect `+
        `--dataset-prefix "${prefix}" `+
        `--jcllib "${jcllib}" `+
        `--keyring-owner "${EVAL_VARS.keyring_owner}" `+
        `--keyring-name "${EVAL_VARS.keyring_name}" `+
        `--trust-cas "${cert_import_CAs}" `+
        `--connect-user "${EVAL_VARS.keyring_connect_user}" `+
        `--connect-label "${EVAL_VARS.keyring_connect_label}" `+
        `--security-product "${security_product}" `+
        "${EVAL_VARS.keyring_trust_zosmf}" `+
        `--zosmf-ca "${EVAL_VARS.zosmf_ca}" `+
        `--zosmf-user "${EVAL_VARS.zosmf_user}"

      yaml_keyring_label=${EVAL_VARS.keyring_connect_label}"
      ;;
    3)
      // import certs from data set into zowe keyring
      shell.execSync('sh', '-c', 'zwe '+
        certificate keyring-jcl import-ds `+
        `--dataset-prefix "${prefix}" `+
        `--jcllib "${jcllib}" `+
        `--keyring-owner "${EVAL_VARS.keyring_owner}" `+
        `--keyring-name "${EVAL_VARS.keyring_name}" `+
        `--alias "${EVAL_VARS.keyring_label}" `+
        `--trust-cas "${cert_import_CAs}" `+
        `--import-ds-name "${EVAL_VARS.keyring_import_dsName}" `+
        `--import-ds-password "${EVAL_VARS.keyring_import_password}" `+
        `--security-product "${security_product}" `+
        "${EVAL_VARS.keyring_trust_zosmf}" `+
        `--zosmf-ca "${EVAL_VARS.zosmf_ca}" `+
        `--zosmf-user "${EVAL_VARS.zosmf_user}"
      // FIXME: currently ZWEKRING jcl will import the cert and chain, CA will also be added to CERTAUTH, but the CA will not be connected to keyring.
      //        the CA imported could have label like LABEL00000001.

      yaml_keyring_label=${EVAL_VARS.keyring_label}"
      ;;
  esac

  if (-n "${cert_import_CAs}") {
    // append imported CAs to list
    while read -r item; do
      item=$(echo "${item}" | trim)
      if (-n "${item}") {
        if (-n "${yaml_pem_cas}") {
          yaml_pem_cas="${yaml_pem_cas},safkeyring:////${keyring_owner}/${keyring_name}&${item}"
        } else {
          yaml_pem_cas="safkeyring:////${keyring_owner}/${keyring_name}&${item}"
        }
      }
    done <<EOF
$(echo "${cert_import_CAs}" | tr "," "\n")
EOF
  }

  // update zowe.yaml
  if ("${ZWE_CLI_PARAMETER_UPDATE_CONFIG}" = "true") {
    common.printLevel1Message(`Update certificate configuration to ${ZWE_CLI_PARAMETER_CONFIG}"
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.keystore.type" "JCERACFKS"
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.keystore.file" "safkeyring:////${keyring_owner}/${keyring_name}"
    // we must set a dummy value here, other JDK will complain wrong parameter
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.keystore.password" "password"
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.keystore.alias" "${yaml_keyring_label}"
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.truststore.type" "JCERACFKS"
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.truststore.file" "safkeyring:////${keyring_owner}/${keyring_name}"
    // we must set a dummy value here, other JDK will complain wrong parameter
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.truststore.password" "password"
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.pem.key" ""
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.pem.certificate" ""
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.pem.certificateAuthorities" "${yaml_pem_cas}"
    common.printLevel2Message(`Zowe configuration is updated successfully."
  } else {
    common.printLevel1Message(`Update certificate configuration to ${ZWE_CLI_PARAMETER_CONFIG}"
    common.printMessage(`Please manually update to these values:"
    common.printMessage(`"
    common.printMessage(`zowe:"
    common.printMessage(`  certificate:"
    common.printMessage(`    keystore:"
    common.printMessage(`      type: JCERACFKS"
    common.printMessage(`      file: \"safkeyring:////${keyring_owner}/${keyring_name}\""
    common.printMessage(`      password: \"password\""
    common.printMessage(`      alias: \"${yaml_keyring_label}\""
    common.printMessage(`    truststore:"
    common.printMessage(`      type: JCERACFKS"
    common.printMessage(`      file: \"safkeyring:////${keyring_owner}/${keyring_name}\""
    common.printMessage(`      password: \"password\""
    common.printMessage(`    pem:"
    common.printMessage(`      key: \"\""
    common.printMessage(`      certificate: \"\""
    common.printMessage(`      certificateAuthorities: \"${yaml_pem_cas}\""
    common.printMessage(`"
    common.printLevel2Message(`Zowe configuration requires manual updates."
  }
}


if (-n "${EVAL_VARS.zosmf_host}" -a "${verify_certificates}" = "STRICT") {
  // CN/SAN must be valid if z/OSMF is used and in strict mode
  shell.execSync('sh', '-c', 'zwe '+
    certificate verify-service `+
    `--host "${EVAL_VARS.zosmf_host}" `+
    `--port "${EVAL_VARS.zosmf_port}"
}
}
