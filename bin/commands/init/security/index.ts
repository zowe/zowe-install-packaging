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
import * as json from '../../../libs/json';
import * as zoslib from '../../../libs/zos';
import * as zosJes from '../../../libs/zos-jes';
import * as initGenerate from '../generate/index';
import * as template from '../../../libs/template';
import * as zosDataset from '../../../libs/zos-dataset';

function splitByHlqAndRest(datasetName: string): { hlq: string, rest: string } {
  const idx = datasetName.indexOf('.');

  if (idx === -1) {
    return { hlq: datasetName, rest: '' };
  }

  return {
    hlq: datasetName.slice(0, idx),
    rest: datasetName.slice(idx + 1)
  };
}

export function execute(dryRun?: boolean, ignoreSecurityFailures?: boolean) {
  common.printLevel1Message(`Run Zowe security configurations`);

  // Validation
  common.requireZoweYaml();
  const ZOWE_CONFIG = config.getZoweConfig();

  // read prefix and validate (zowe.setup.dataset in defaults)
  const prefix=ZOWE_CONFIG.zowe.setup.dataset.prefix;
  if (!prefix) {
    common.printErrorAndExit(`Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }

  // check if user passed --generate
  const forceGen = !!std.getenv('ZWE_CLI_PARAMETER_GENERATE')
  if (forceGen) {
    initGenerate.execute();
  }

  // read JCL library and validate
  const jcllib = zoslib.verifyGeneratedJcl(ZOWE_CONFIG);
  if (!jcllib) {
    return common.printErrorAndExit(`Error ZWEL0319E: zowe.setup.dataset.jcllib does not exist, cannot run. Run 'zwe init', 'zwe init generate', or submit JCL ${prefix}.SZWESAMP(ZWEGENER) before running this command.`, undefined, 319);
  }

  let securityProduct: string;
  let esmWarning = false;
  const securityProductReal = zos.getEsm();
  // zowe.setup.security.product in defaults
  const securityProductConfig = ZOWE_CONFIG.zowe.setup.security.product;
  if (securityProductReal && securityProductReal != 'NONE') {
      securityProduct = securityProductReal;
      if (securityProductReal != securityProductConfig) {
        esmWarning = true;
      }
  } else {
      securityProduct = securityProductConfig;
  }

  const securityPrefix = securityProduct.substring(0,3);

  if (zos.getZosVersion() < 0x1020500) {
    zosJes.printAndHandleJcl(`//'${jcllib}(ZWEI${securityPrefix}Z)'`, `ZWEI${securityPrefix}Z`, jcllib, prefix, false, ignoreSecurityFailures);
  }
  // For ACF2:
  //  - orignal JCL handles only standalone HLQ (like ZOWE)
  //  - for prefix with more segments (like ZOWE.V3R5M0), we need to run an additional update
  if (securityProduct == 'ACF2' && prefix.indexOf('.') != -1) {
    const runtime = std.getenv('ZWE_zowe_runtimeDirectory');
    const pathTemplatesSecurity = `${runtime}/files/templates/init/security/acf2.dataset.protection.tjcl`;
    // We need extra data, join it with ZOWE_CONFIG to make it available for template resolution
    const ACF2_ZOWE_CONFIG = {
      ...ZOWE_CONFIG,
      acf2Data: {
        hlq: splitByHlqAndRest(prefix).hlq,
        rest: splitByHlqAndRest(prefix).rest
      }
    };
    // It is possible to define empty/null value for zowe.setup.security.groups.stc
    if (ACF2_ZOWE_CONFIG.zowe.setup.security.groups.stc == null || ACF2_ZOWE_CONFIG.zowe.setup.security.groups.stc == '') {
      ACF2_ZOWE_CONFIG.zowe.setup.security.groups.stc = std.getenv('ZWE_PRIVATE_DEFAULT_ADMIN_GROUP');
    }
    const acf2DatasetProtection = template.resolveFile(`${pathTemplatesSecurity}`, ACF2_ZOWE_CONFIG);
    const zweiacf = zosDataset.readMember(`//'${jcllib}(ZWEIACF)'`);
    if (!zweiacf) {
      common.printErrorAndExit(`Error ZWEL0327E: Failed to read ${jcllib}(ZWEIACF) - no content`, undefined, 327);
    } else {
      const updatedZweiacf = zweiacf.replace(/\* <acf2\.dataset\.protection>\n[\s\S]*?\n\* <acf2\.dataset\.protection>/, acf2DatasetProtection);
      zosDataset.updateMember(`//'${jcllib}(ZWEIACF)'`, updatedZweiacf);
    }
  }
  zosJes.printAndHandleJcl(`//'${jcllib}(ZWEI${securityPrefix})'`, `ZWEI${securityPrefix}`, jcllib, prefix, false, ignoreSecurityFailures);
  common.printMessage(``);
  common.printMessage(`WARNING: Due to the limitation of the ZWEI${securityPrefix} job, exit with 0 does not mean`);
  common.printMessage(`         the job is fully successful. Please check the job log to determine`);
  common.printMessage(`         if there are any messages indicating a problem.`);
  if (esmWarning) {
    common.printMessage(``);
    const updateConfig = !!std.getenv('ZWE_CLI_PARAMETER_UPDATE_CONFIG');
    const configOrig = std.getenv('ZWE_PRIVATE_CONFIG_ORIG');
    common.printLevel1Message(`Update security configuration to ${configOrig}`);
    if (!updateConfig) {
      common.printMessage(`Please manually update to these values:`);
      common.printMessage('zowe:');
      common.printMessage('  setup:');
      common.printMessage('    security');
      common.printMessage(`      product: ${securityProductReal}`);
    } else {
      json.updateZoweYaml(configOrig, '.zowe.setup.security.product', securityProductReal);
      common.printLevel2Message(`Zowe configuration is updated successfully.`);
    }
}
  common.printMessage(``);
}
