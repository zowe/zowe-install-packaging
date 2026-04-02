/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html

  SPDX-License-Identifier: EPL-2.0

  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as xplatform from 'xplatform';

import * as zoslib from '../../../libs/zos';
import * as zosJes from '../../../libs/zos-jes';
import * as zosdataset from '../../../libs/zos-dataset';
import * as common from '../../../libs/common';
import * as config from '../../../libs/config';
import * as initGenerate from '../generate/index';
import * as template from '../../../libs/template';

export function execute(allowOverwrite?: boolean) {
  common.printLevel1Message(`Initialize Zowe custom data sets`);
  common.requireZoweYaml();
  const ZOWE_CONFIG = config.getZoweConfig();

  const prefix = ZOWE_CONFIG.zowe.setup?.dataset?.prefix;
  if (!prefix) {
    common.printErrorAndExit(`Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }

  // For V4: if components.zss.enabled = false => no need to create parmlib
  const parmlib = ZOWE_CONFIG.zowe.setup?.dataset?.parmlib ? ZOWE_CONFIG.zowe.setup.dataset.parmlib : undefined;
  if (!parmlib) {
      common.printErrorAndExit(`Error ZWEL0157E: zowe.setup.dataset.parmlib is not defined in Zowe YAML configuration file.`, undefined, 157);
  }

  // check if user passed --generate
  const forceGen = !!std.getenv('ZWE_CLI_PARAMETER_GENERATE')
  if (forceGen) {
    initGenerate.execute();
  }

  const jcllib = zoslib.verifyGeneratedJcl(ZOWE_CONFIG);
  if (!jcllib) {
    common.printErrorAndExit(`Error ZWEL0319E: zowe.setup.dataset.jcllib does not exist, cannot run. Run 'zwe init', 'zwe init generate', or submit JCL ${prefix}.SZWESAMP(ZWEGENER) before running this command.`, undefined, 319);
  }

  common.printMessage(`Create data sets if they do not exist`);

  const runtime = std.getenv('ZWE_zowe_runtimeDirectory');
  const pathTemplates = `${runtime}/files/templates`;
  const pathTemplatesMvs = `${pathTemplates}/init/mvs`
  const license = xplatform.loadFileUTF8(`${pathTemplates}/license.tjcl`, xplatform.AUTO_DETECT);
  const sourceZWESIP = `${prefix}.SZWESAMP(ZWESIP00)`;
  const targetZWESIP = `${parmlib}(${ZOWE_CONFIG.zowe.setup.dataset.parmlibMembers.zis})`; // parmlibMembers.zis - in defaults && regex len = 8, can't be empty or null

  let skipJcl = false;
  let mvsJcl = template.resolveString(`//ZWEMVS   JOB \${this.zowe.setup.jcl.header}\n`, ZOWE_CONFIG);
  mvsJcl += license;
  let mvsJclParmlib = ''

  if (!zosdataset.isDatasetExists(ZOWE_CONFIG.zowe.setup.dataset.parmlib)) {
    mvsJclParmlib += template.resolveFile(`${pathTemplatesMvs}/parmlib.allocate.tjcl`, ZOWE_CONFIG);
    mvsJclParmlib += template.resolveFile(`${pathTemplatesMvs}/parmlib.copy.tjcl`, ZOWE_CONFIG);
  } else {
    if (sourceZWESIP != targetZWESIP) {
      if (zosdataset.isDatasetExists(targetZWESIP)) {
        if (allowOverwrite) {
          mvsJclParmlib += template.resolveFile(`${pathTemplatesMvs}/parmlib.delete.tjcl`, ZOWE_CONFIG);
          mvsJclParmlib += template.resolveFile(`${pathTemplatesMvs}/parmlib.copy.tjcl`, ZOWE_CONFIG);
          common.printMessage(`Warning ZWEL0300W: ${targetZWESIP} already exists. Members in this data set will be overwritten.`);
        } else {
          common.printMessage(`Warning ZWEL0301W: ${targetZWESIP} already exists and will not be overwritten. For upgrades, you must use --allow-overwrite.`);
          skipJcl = true;
        }
      }
    }
  }

  const szweauth = ZOWE_CONFIG.zowe.setup.dataset.prefix + '.SZWEAUTH';
  const authLoadlib = ZOWE_CONFIG.zowe.setup.dataset.authLoadlib;
  let mvsJclAuthLoadlib = '';

  if (authLoadlib) {
    if (authLoadlib != szweauth) {
      if (!zosdataset.isDatasetExists(authLoadlib)) {
        mvsJclAuthLoadlib += template.resolveFile(`${pathTemplatesMvs}/authloadlib.allocate.tjcl`, ZOWE_CONFIG);
        mvsJclAuthLoadlib += template.resolveFile(`${pathTemplatesMvs}/authloadlib.copy.tjcl`, ZOWE_CONFIG);
      } else {
        if (allowOverwrite) {
          mvsJclAuthLoadlib += template.resolveFile(`${pathTemplatesMvs}/authloadlib.delete.tjcl`, ZOWE_CONFIG);
          mvsJclAuthLoadlib += template.resolveFile(`${pathTemplatesMvs}/authloadlib.copy.tjcl`, ZOWE_CONFIG);
          common.printMessage(`Warning ZWEL0300W: ${authLoadlib} already exists. Members in this data set will be overwritten.`);
        } else {
          common.printMessage(`Warning ZWEL0301W: ${authLoadlib} already exists and will not be overwritten. For upgrades, you must use --allow-overwrite.`);
          skipJcl = true;
        }
      }
    }
  }

  let mvsJclAuthPluginLib = '';

  const authPluginLib = ZOWE_CONFIG.zowe.setup.dataset.authPluginLib;
  if (authPluginLib) {
    if (authPluginLib != szweauth && authPluginLib != authLoadlib) {
      if (!zosdataset.isDatasetExists(authPluginLib)) {
        mvsJclAuthPluginLib += template.resolveFile(`${pathTemplatesMvs}/authpluginlib.allocate.tjcl`, ZOWE_CONFIG);
      }
    }
  }

  if ((mvsJclParmlib.length == 0 && mvsJclAuthLoadlib.length == 0 && mvsJclAuthPluginLib.length == 0) || skipJcl == true) {
    if (skipJcl == true) {
      common.printMessage(`Skipped writing to a dataset. To write, you must use --allow-overwrite.`);
    }
    common.printLevel2Message(`Zowe custom data sets are initialized successfully.`);
    std.exit(0);
  }

  mvsJcl += mvsJclParmlib;
  mvsJcl += mvsJclAuthLoadlib;
  mvsJcl += mvsJclAuthPluginLib;

  zosdataset.updateMember(`${jcllib}(ZWEMVS)`, mvsJcl);

  console.log(`${mvsJcl}${mvsJclParmlib}${mvsJclAuthLoadlib}${mvsJclAuthPluginLib}`);

  common.printLevel2Message(`Zowe custom data sets are initialized successfully.`);
}
