/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/


import * as std from 'std';
import * as os from 'os';
import * as zos from 'zos';
import * as xplatform from 'xplatform';

import * as fs from '../../../libs/fs';
import * as common from '../../../libs/common';
import * as stringlib from '../../../libs/string';
import * as shell from '../../../libs/shell';
import * as config from '../../../libs/config';
import * as zosfs from '../../../libs/zos-fs';
import * as zosdataset from '../../../libs/zos-dataset';

export function execute(allowOverwrite: boolean = false) {

  common.printLevel1Message(`Install Zowe main started task`);
  
  // constants
  const PROCLIBS: string[] = ["ZWESLSTC", "ZWESISTC", "ZWESASTC"];
  const SAMP_LIB = std.getenv('ZWE_PRIVATE_DS_SZWESAMP');
  const COMMAND_LIST = std.getenv('ZWE_CLI_COMMANDS_LIST');
  
  let jclExistence: boolean;
  let stcExistence: boolean;
  
  // validation
  common.requireZoweYaml();
  const ZOWE_CONFIG=config.getZoweConfig();
  
  // read prefix and validate
  const prefix=ZOWE_CONFIG.zowe?.setup?.dataset?.prefix;
  if (!prefix) {
    common.printErrorAndExit(`Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }
  // read PROCLIB and validate
  const proclib=ZOWE_CONFIG.zowe.setup.dataset.proclib;
  if (!proclib) {
    common.printErrorAndExit(`Error ZWEL0157E: PROCLIB (zowe.setup.dataset.proclib) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }
  // read JCL library and validate
  const jcllib=ZOWE_CONFIG.zowe.setup.dataset.jcllib;
  if (!jcllib) {
    common.printErrorAndExit(`Error ZWEL0157E: Zowe custom JCL library (zowe.setup.dataset.jcllib) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }
  // read PARMLIB and validate
  const parmlib=ZOWE_CONFIG.zowe.setup.dataset.parmlib;
  if (!parmlib) {
    common.printErrorAndExit(`Error ZWEL0157E: Zowe custom parameter library (zowe.setup.dataset.parmlib) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }
  // read LOADLIB and validate
  let authLoadlib=ZOWE_CONFIG.zowe.setup.dataset.authLoadlib;
  if (!authLoadlib) {
    // authLoadlib can be empty
    authLoadlib=`${prefix}.${std.getenv('ZWE_PRIVATE_DS_SZWEAUTH}')}`;
  }
  const authPluginLib=ZOWE_CONFIG.zowe.setup.dataset.authPluginLib;
  if (!authPluginLib) {
    common.printErrorAndExit(`Error ZWEL0157E: Zowe custom load library (zowe.setup.dataset.authPluginLib) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }
  let security_stcs_zowe=ZOWE_CONFIG.zowe.setup.security.stcs.zowe;
  if (!security_stcs_zowe) {
    security_stcs_zowe=std.getenv('ZWE_PRIVATE_DEFAULT_ZOWE_STC');
  }
  let security_stcs_zis=ZOWE_CONFIG.zowe.setup.security.stcs.zis;
  if (!security_stcs_zis) {
    security_stcs_zis=std.getenv('ZWE_PRIVATE_DEFAULT_ZIS_STC');
  }
  let security_stcsAux=ZOWE_CONFIG.zowe.setup.security.stcs.aux;
  if (!security_stcsAux) {
    security_stcsAux=std.getenv('ZWE_PRIVATE_DEFAULT_AUX_STC');
  }
  const target_proclibs: string[] = [security_stcs_zowe, security_stcs_zis, security_stcsAux];

  // check existence
  PROCLIBS.forEach((mb: string) => {
    // source in SZWESAMP
    const sampExistence=zosdataset.isDatasetExists(`${prefix}.${SAMP_LIB}(${mb})`);
    if (sampExistence != true) {
      common.printErrorAndExit(`Error ZWEL0143E: ${prefix}.${SAMP_LIB}(${mb}) already exists. This data set member will be overwritten during configuration.`, undefined, 143);
    }
  });
  target_proclibs.forEach((mb: string) => {
    // JCL for preview purpose
    jclExistence=zosdataset.isDatasetExists(`${jcllib}(${mb})`);
    if (jclExistence == true) {
      if (allowOverwrite) {
        // warning
        common.printMessage(`Warning ZWEL0300W: ${jcllib}(${mb}) already exists. This data set member will be overwritten during configuration.`);
      } else {
        // common.printErrorAndExit(`Error ZWEL0158E: ${jcllib}(${mb}) already exists.`, undefined, 158);
        // warning
        common.printMessage(`Warning ZWEL0301W: ${jcllib}(${mb}) already exists and will not be overwritten. For upgrades, you must use --allow-overwrite.`);
      }
    }

    // STCs in target proclib
    stcExistence=zosdataset.isDatasetExists(`${proclib}(${mb})`);
    if (stcExistence == true) {
      if (allowOverwrite) {
        // warning
        common.printMessage(`Warning ZWEL0300W: ${proclib}(${mb}) already exists. This data set member will be overwritten during configuration.`);
      } else {
        // common.printErrorAndExit(`Error ZWEL0158E: ${proclib}(${mb}) already exists.`, undefined, 158);
        // warning
        common.printMessage(`Warning ZWEL0301W: ${proclib}(${mb}) already exists and will not be overwritten. For upgrades, you must use --allow-overwrite.`);
      }
    }
  });

  if (jclExistence == true && allowOverwrite) {
    common.printMessage(`Skipped writing to ${jcllib}. To write, you must use --allow-overwrite.`);
  } else {
    // prepare STCs
    // ZWESLSTC
    common.printMessage(`Modify ZWESLSTC and save as ${jcllib}(${security_stcs_zowe})`);
    let tmpfile = fs.createTmpFile(`zwe ${COMMAND_LIST}`.replace(new RegExp('\ ', 'g'), '-'));
    common.printDebug(`- Copy ${prefix}.${SAMP_LIB}(ZWESLSTC) to ${tmpfile}`);
    // TODO this info gets lost
    /*
    if (!std.getenv("ZWE_CLI_PARAMETER_CONFIG").startsWith('/')) {
      common.printMessage(`CONFIG path defined in ZWESLSTC is converted into absolute path and may contain SYSNAME.`);
      common.printMessage(`Please manually verify if this path works for your environment, especially when you are working in Sysplex environment.`);
    }
    */
    const slstcContent = shell.execOutSync('sh', '-c', `cat "//'${prefix}.${SAMP_LIB}(ZWESLSTC)'" 2>&1`);
    if (slstcContent.out && slstcContent.rc==0) {
      common.printDebug(`  * Succeeded`);
      common.printTrace(`  * Output:`);
      common.printTrace(stringlib.paddingLeft(slstcContent.out, "    "));

      const tmpFileContent = slstcContent.out.replace('//STEPLIB  DD   DSNAME=&SYSUID..LOADLIB,DISP=SHR', '//STEPLIB  DD   DSNAME=${authLoadlib},DISP=SHR')
        .replace('CONFIG=#zowe_yaml', `CONFIG=${std.getenv('ZWE_PRIVATE_ORIGINAL_CONFIG')}`);

      xplatform.storeFileUTF8(tmpfile, xplatform.AUTO_DETECT, tmpFileContent);
      common.printTrace(`  * Stored:`);
      common.printTrace(stringlib.paddingLeft(tmpFileContent, "    "));
      
      shell.execSync('chmod', '700', tmpfile);
    } else {
      common.printDebug(`  * Failed`);
      common.printError(`  * Exit code: ${slstcContent.rc}`);
      common.printError(`  * Output:`);
      if (slstcContent.out) {
        common.printError(stringlib.paddingLeft(slstcContent.out, "    "));
      }
    }

    if (!fs.fileExists(tmpfile)) {
      common.printErrorAndExit(`Error ZWEL0159E: Failed to modify ${prefix}.${SAMP_LIB}(ZWESLSTC)`, undefined, 159);
    }
    common.printTrace(`- ensure ${tmpfile} encoding before copying into data set`);
    zosfs.ensureFileEncoding(tmpfile, "SPDX-License-Identifier");
    common.printTrace(`- ${tmpfile} created, copy to ${jcllib}(${security_stcs_zowe})`);
    let result = zosdataset.copyToDataset(tmpfile, `${jcllib}(${security_stcs_zowe})`, "", allowOverwrite);
    common.printTrace(`- Delete ${tmpfile}`);
    os.remove(tmpfile);
    if (result != 0) {
      common.printErrorAndExit(`Error ZWEL0160E: Failed to write to ${jcllib}(${security_stcs_zowe}). Please check if target data set is opened by others.`, undefined, 160);
    }
    common.printDebug(`- ${jcllib}(${security_stcs_zowe}) is prepared`);

    // ZWESISTC
    common.printMessage(`Modify ZWESISTC and save as ${jcllib}(${security_stcs_zis})`);
    tmpfile = fs.createTmpFile(`zwe ${COMMAND_LIST}`.replace(new RegExp('\ ', 'g'), '-'));
    common.printDebug(`- Copy ${prefix}.${SAMP_LIB}(ZWESISTC) to ${tmpfile}`);
    const sistcContent = shell.execOutSync('sh', '-c', `cat "//'${prefix}.${SAMP_LIB}(ZWESISTC)'" 2>&1`);
    if (sistcContent.out && sistcContent.rc == 0) {
      common.printDebug(`  * Succeeded`);
      common.printTrace(`  * Output:`);
      common.printTrace(stringlib.paddingLeft(sistcContent.out, "    "));

      const tmpFileContent = sistcContent.out.replace('ZWES.SISSAMP', parmlib)
        .split('\n').map(line => line.startsWith('//STEPLIB') ? `//STEPLIB  DD   DSNAME='${authLoadlib}',DISP=SHR\n`
                                                              + `//         DD   DSNAME='${authPluginLib}',DISP=SHR'`
                                                              : line).join('\n');
      xplatform.storeFileUTF8(tmpfile, xplatform.AUTO_DETECT, tmpFileContent);
      common.printTrace(`  * Stored:`);
      common.printTrace(stringlib.paddingLeft(tmpFileContent, "    "));

      shell.execSync('chmod', '700', tmpfile);
    } else {
      common.printDebug(`  * Failed`);
      common.printError(`  * Exit code: ${sistcContent.rc}`);
      common.printError(`  * Output:`);
      if (sistcContent.out) {
        common.printError(stringlib.paddingLeft(sistcContent.out, "    "));
      }
      std.exit(1);
    }
    if (!fs.fileExists(tmpfile)) {
      common.printErrorAndExit(`Error ZWEL0159E: Failed to modify ${prefix}.${SAMP_LIB}(ZWESISTC)`, undefined, 159);
    }
    common.printTrace(`- ensure ${tmpfile} encoding before copying into data set`);
    zosfs.ensureFileEncoding(tmpfile, "SPDX-License-Identifier");
    common.printTrace(`- ${tmpfile} created, copy to ${jcllib}(${security_stcs_zis})`);
    result = zosdataset.copyToDataset(tmpfile, `${jcllib}(${security_stcs_zis})`, "", allowOverwrite);
    common.printTrace(`- Delete ${tmpfile}`);
    os.remove(tmpfile);
    if (result != 0) {
      common.printErrorAndExit(`Error ZWEL0160E: Failed to write to ${jcllib}(${security_stcs_zis}). Please check if target data set is opened by others.`, undefined, 160);
    }
    common.printDebug(`- ${jcllib}(${security_stcs_zis}) is prepared`);

    // ZWESASTC
    common.printMessage(`Modify ZWESASTC and save as ${jcllib}(${security_stcsAux})`);
    tmpfile = fs.createTmpFile(`zwe ${COMMAND_LIST}`.replace(new RegExp('\ ', 'g'), '-'));
    common.printDebug(`- Copy ${prefix}.${SAMP_LIB}(ZWESASTC) to ${tmpfile}`);
    const sastcContent = shell.execOutSync('sh', '-c', `cat "//'${prefix}.${SAMP_LIB}(ZWESASTC)'" 2>&1`);
    if (sastcContent.out && sastcContent.rc == 0) {
      common.printDebug(`  * Succeeded`);
      common.printTrace(`  * Output:`);
      common.printTrace(stringlib.paddingLeft(sastcContent.out, "    "));
      
      const tmpFileContent = sastcContent.out.split('\n')
        .map(line => line.startsWith('//STEPLIB') ? `//STEPLIB  DD   DSNAME='${authLoadlib}',DISP=SHR\n`
                                                  + `//         DD   DSNAME='${authPluginLib}',DISP=SHR'`
                                                  : line).join('\n');
      xplatform.storeFileUTF8(tmpfile, xplatform.AUTO_DETECT, tmpFileContent);
      shell.execSync('chmod', '700', tmpfile);
    } else {
      common.printDebug(`  * Failed`);
      common.printError(`  * Exit code: ${sastcContent.rc}`);
      common.printError(`  * Output:`);
      if (sastcContent.out) {
        common.printError(stringlib.paddingLeft(sastcContent.out, "    "));
      }
      std.exit(1);
    }
    if (!fs.fileExists(tmpfile)) {
      common.printErrorAndExit(`Error ZWEL0159E: Failed to modify ${prefix}.${SAMP_LIB}(ZWESASTC)`, undefined, 159);
    }
    common.printTrace(`- ensure ${tmpfile} encoding before copying into data set`);
    zosfs.ensureFileEncoding(tmpfile, "SPDX-License-Identifier");
    common.printTrace(`- ${tmpfile} created, copy to ${jcllib}(${security_stcsAux})`);
    result = zosdataset.copyToDataset(tmpfile, `${jcllib}(${security_stcsAux})`, "", allowOverwrite);
    common.printTrace(`- Delete ${tmpfile}`);
    os.remove(tmpfile);
    if (result != 0) {
      common.printErrorAndExit(`Error ZWEL0160E: Failed to write to ${jcllib}(${security_stcsAux}). Please check if target data set is opened by others.`, undefined, 160);
    }
    common.printDebug(`- ${jcllib}(${security_stcsAux}) is prepared`);
    common.printMessage('');
  }

  if (stcExistence == true && allowOverwrite) {
    common.printMessage(`Skipped writing to ${proclib}. To write, you must use --allow-overwrite.`);
  } else {
    // copy to proclib
    target_proclibs.forEach((mb:string)=> {
      common.printMessage(`Copy ${jcllib}(${mb}) to ${proclib}(${mb})`);
      //TODO there was an '-X' here. why?
      const result = zosdataset.datasetCopyToDataset(prefix, `${jcllib}(${mb})`, `${proclib}(${mb})`, std.getenv('ZWE_CLI_PARAMETER_ALLOW_OVERWRITE')=='true');
      if (result != 0) {
        common.printErrorAndExit(`Error ZWEL0111E: Command aborts with error.`, undefined, 111);
      }
    });
  }

  // exit message
  common.printLevel2Message(`Zowe main started tasks are installed successfully.`);
}
