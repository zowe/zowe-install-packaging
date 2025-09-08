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

import * as common from '../../../libs/common';
import * as config from '../../../libs/config';
import * as fs from '../../../libs/fs';
import * as initGenerate from '../generate/index';
import * as shell from '../../../libs/shell';
import * as stringlib from '../../../libs/string';
import * as zosDs from '../../../libs/zos-dataset';
import * as zosJes from '../../../libs/zos-jes';
import * as zoslib from '../../../libs/zos';

export function execute() {
  common.printLevel1Message(`APF authorize load libraries`);

  // Validation
  common.requireZoweYaml();
  const ZOWE_CONFIG = config.getZoweConfig();

  // read prefix and validate
  const prefix = ZOWE_CONFIG.zowe?.setup?.dataset?.prefix;
  if (!prefix) {
    common.printErrorAndExit(`ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }

  // check if user passed --generate
  const forceGen = !!std.getenv('ZWE_CLI_PARAMETER_GENERATE');
  if (forceGen) {
    initGenerate.execute();
  }

  // read JCL library and validate
  const jcllib = zoslib.verifyGeneratedJcl(ZOWE_CONFIG);
  if (!jcllib) {
    return common.printErrorAndExit(`ZWEL0319E: zowe.setup.dataset.jcllib does not exist, cannot run. Run 'zwe init', 'zwe init generate', or submit JCL ${prefix}.SZWESAMP(ZWEGENER) before running this command.`, undefined, 319);
  }

  let needUpdate = false;
  let authLoadlib = ZOWE_CONFIG.zowe?.setup?.dataset?.authLoadlib;
  if (!authLoadlib) {
    common.printMessage(`ZWEL0158I: zowe.setup.dataset.authLoadlib is not defined in Zowe YAML configuration file. Using the default value ${ZOWE_CONFIG.zowe.setup.dataset.prefix}.SZWEAUTH.`);
    needUpdate = true;
    authLoadlib = `${ZOWE_CONFIG.zowe.setup.dataset.prefix}.SZWEAUTH`;
  }

  // Authloadlib must exist, either user defined or default "zowe.setup.dataset.prefix.SZWEAUTH"
  if (!zosDs.isDatasetExists(authLoadlib)) {
    common.printErrorAndExit(`ZWEL0324E: The dataset specified in 'zowe.setup.dataset.authLoadlib' does not exist.`, undefined, 324);
  }
  let authPluginLib = ZOWE_CONFIG.zowe?.setup?.dataset?.authPluginLib;
  if (!authPluginLib) {
    //TODO: is there a better message?
    common.printMessage('ZWEL0159I: zowe.setup.dataset.authPluginLib is not defined in Zowe YAML configuration file. Skipping.');
    needUpdate = true;
  } else {
    if (authLoadlib == authPluginLib) {
      // Skip APF command for the same dataset
      authPluginLib = undefined;
      needUpdate = true;
    }
  }
  // AuthPluginLib must exist only if defined by user
  if (authPluginLib && !zosDs.isDatasetExists(authPluginLib)) {
    common.printErrorAndExit(`ZWEL0324E: The dataset specified in 'zowe.setup.dataset.authPluginLib' does not exist.`, undefined, 324);
  }

  const authSMS = zosDs.isDatasetSmsManaged(authLoadlib).smsManaged;
  let authLocation = `LOADLOC=SMS`;
  if (!authSMS) {
    needUpdate = true;
    authLocation = `LOADLOC="VOLUME=${zosDs.getDatasetVolume(authLoadlib).volume}"`;
  }

  const plugSMS = authPluginLib ? zosDs.isDatasetSmsManaged(authPluginLib).smsManaged : undefined;
  let plugLocation = `PLUGLOC=SMS`;
  if (plugSMS == false) {
    needUpdate = true;
    plugLocation = `PLUGLOC="VOLUME=${zosDs.getDatasetVolume(authPluginLib).volume}"`
  }

  if (!needUpdate) {
    zosJes.printAndHandleJcl(`//'${jcllib}(ZWEIAPF2)'`, `ZWEIAPF2`, jcllib, prefix);
  }
  else {
    const COMMAND_LIST = std.getenv('ZWE_CLI_COMMANDS_LIST');
    const tmpfile = fs.createTmpFile(`zwe ${COMMAND_LIST}`.replace(new RegExp('\ ', 'g'), '-'));
    common.printDebug(`- Copy ${jcllib}(ZWEIAPF2) to ${tmpfile}`);
    let jclContent = shell.execOutSync('sh', '-c', `cat "//'${stringlib.escapeDollar(jcllib)}(ZWEIAPF2)'" 2>&1`);
    if (jclContent.out && jclContent.rc == 0) {
      common.printDebug(`  * Succeeded`);
      common.printTrace(`  * Output:`);
      common.printTrace(stringlib.paddingLeft(jclContent.out, "    "));
      // Remove the shell after 'cd bin/utils &&'
      const BIN_UTILS = 'cd bin/utils &&';
      jclContent.out = jclContent.out.substring(0, jclContent.out.indexOf(BIN_UTILS) + BIN_UTILS.length + 1);
      jclContent.out = jclContent.out.concat(`LOADLIB='${authLoadlib}' &&\n`);
      jclContent.out = jclContent.out.concat(`${authLocation} &&\n`);
      jclContent.out = jclContent.out.concat(`./opercmd.rex "SETPROG APF,ADD,DSN=$LOADLIB,$LOADLOC"${authPluginLib ? ' &&' : ''}\n`);
      if (authPluginLib) {
        jclContent.out = jclContent.out.concat(`PLUGLIB='${authPluginLib}' &&\n`);
        jclContent.out = jclContent.out.concat(`${plugLocation} &&\n`);
        jclContent.out = jclContent.out.concat(`./opercmd.rex "SETPROG APF,ADD,DSN=$PLUGLIB,$PLUGLOC"\n`);
      }
      jclContent.out = jclContent.out.concat(`//*\n`);
      xplatform.storeFileUTF8(tmpfile, xplatform.AUTO_DETECT, jclContent.out);
      common.printTrace(`  * Stored:`);
      common.printTrace(stringlib.paddingLeft(jclContent.out, "    "));
      shell.execSync('chmod', '700', tmpfile);
      if (!fs.fileExists(tmpfile)) {
        common.printErrorAndExit(`ZWEL0325E: Failed to prepare ZWEIAPF2`, undefined, 325);
      }
      zosJes.printAndHandleJcl(tmpfile, `ZWEIAPF2`, jcllib, prefix, true);
    }
  }
  common.printLevel2Message(`Zowe load libraries are APF authorized successfully.`);
}