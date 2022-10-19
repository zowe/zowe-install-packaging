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

import * as fs from '../../../../libs/fs';
import * as common from '../../../../libs/common';
import * as stringlib from '../../../../libs/string';
import * as shell from '../../../../libs/shell';
import * as sys from '../../../../libs/sys';
import * as config from '../../../../libs/config';
import * as component from '../../../../libs/component';
import * as varlib from '../../../../libs/var';
import * as java from '../../../../libs/java';
import * as node from '../../../../libs/node';
import * as zosmf from '../../../../libs/zosmf';

export function execute() {

  common.printLevel1Message(`Install Zowe main started task`);
  
  // constants
  const proclibs: string[] = ["ZWESLSTC", "ZWESISTC", "ZWESASTC"];

  let jcl_existence: boolean;
  let stc_existence: boolean;
  
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
  let security_stcs_aux=ZOWE_CONFIG.zowe.setup.security.stcs.aux;
  if (!security_stcs_aux) {
    security_stcs_aux=std.getenv('ZWE_PRIVATE_DEFAULT_AUX_STC');
  }
  const target_proclibs: string[] = [security_stcs_zowe, security_stcs_zis, security_stcs_aux];

  // check existence
  proclibs.forEach((mb: string) => {
    // source in SZWESAMP
    const samp_existence=zosdatasets.isDatasetExists(`${prefix}.${std.getenv('ZWE_PRIVATE_DS_SZWESAMP')}(${mb})`);
    if (samp_existence != true) {
      common.printErrorAndExit(`Error ZWEL0143E: ${prefix}.${std.getenv('ZWE_PRIVATE_DS_SZWESAMP')}(${mb}) already exists. This data set member will be overwritten during configuration.`, undefined, 143);
    }
  });
  target_proclibs.forEach((mb: string) => {
    // JCL for preview purpose
    jcl_existence=zosdatasets.isDatasetExists(`${jcllib}(${mb})`);
    if (jcl_existence == true) {
      if (std.getenv('ZWE_CLI_PARAMETER_ALLOW_OVERWRITE') == "true") {
        // warning
        common.printMessage(`Warning ZWEL0300W: ${jcllib}(${mb}) already exists. This data set member will be overwritten during configuration.`);
      } else {
        // common.printErrorAndExit(`Error ZWEL0158E: ${jcllib}(${mb}) already exists.`, undefined, 158);
        // warning
        common.printMessage(`Warning ZWEL0301W: ${jcllib}(${mb}) already exists and will not be overwritten. For upgrades, you must use --allow-overwrite.`);
      }
    }

    // STCs in target proclib
    stc_existence=zosdatasets.isDatasetExists(`${proclib}(${mb})`);
    if (stc_existence == true) {
      if (std.getenv('ZWE_CLI_PARAMETER_ALLOW_OVERWRITE') == "true") {
        // warning
        common.printMessage(`Warning ZWEL0300W: ${proclib}(${mb}) already exists. This data set member will be overwritten during configuration.`);
      } else {
        // common.printErrorAndExit(`Error ZWEL0158E: ${proclib}(${mb}) already exists.`, undefined, 158);
        // warning
        common.printMessage(`Warning ZWEL0301W: ${proclib}(${mb}) already exists and will not be overwritten. For upgrades, you must use --allow-overwrite.`);
      }
    }
  });

  if (jcl_existence == true && std.getenv('ZWE_CLI_PARAMETER_ALLOW_OVERWRITE') != "true") {
    common.printMessage(`Skipped writing to ${jcllib}(${mb}). To write, you must use --allow-overwrite.`);
  } else {
    // prepare STCs
    // ZWESLSTC
    common.printMessage(`Modify ZWESLSTC and save as ${jcllib}(${security_stcs_zowe})`);
    let tmpfile = fs.createTmpFile(`zwe ${std.getenv('ZWE_CLI_COMMANDS_LIST')}`.replace(new RegExp('\s', 'g'), '-'));
    common.printDebug(`- Copy ${prefix}.${std.getenv('ZWE_PRIVATE_DS_SZWESAMP')}(ZWESLSTC) to ${tmpfile}`);
    // TODO this info gets lost due to the zowe-merged yaml being here
    /*
    if (!std.getenv("ZWE_CLI_PARAMETER_CONFIG").startsWith('/')) {
      common.printMessage(`CONFIG path defined in ZWESLSTC is converted into absolute path and may contain SYSNAME.`);
      common.printMessage(`Please manually verify if this path works for your environment, especially when you are working in Sysplex environment.`);
    }
    */
  let result = shell.execOutSync('sh', '-c', `cat "//'${prefix}.${std.getenv('ZWE_PRIVATE_DS_SZWESAMP')}(ZWESLSTC)'" | `+
          `sed "s/^\/\/STEPLIB .*\$/\/\/STEPLIB  DD   DSNAME=${authLoadlib},DISP=SHR/ | `+
          `sed "s#^CONFIG=.*\$#CONFIG=$(convert_to_absolute_path ${std.getenv('ZWE_CLI_PARAMETER_CONFIG})#" `+
          `> "${tmpfile}" && chmod 700 "${tmpfile}");
  
  if (result.rc == 0) {
    common.printDebug(`  * Succeeded`);
    common.printTrace(`  * Exit code: ${result.rc}`);
    common.printTrace(`  * Output:`);
    if (result.out) {
      common.printTrace(stringlib.paddingLeft(result.out, "    "));
    }
  } else {
    common.printDebug(`  * Failed`);
    common.printError(`  * Exit code: ${result.rc}`);
    common.printError(`  * Output:`);
    if (result.out) {
      common.printError(stringlib.paddingLeft(result.out, "    "));
    }
  }
  if (!fs.fileExists(tmpfile)) {
    common.printErrorAndExit(`Error ZWEL0159E: Failed to modify ${prefix}.${std.getenv('ZWE_PRIVATE_DS_SZWESAMP')}(ZWESLSTC)`, undefined, 159);
  }
  common.printTrace(`- ensure ${tmpfile} encoding before copying into data set`);
  ensure_file_encoding "${tmpfile}" "SPDX-License-Identifier"
  common.printTrace(`- ${tmpfile} created, copy to ${jcllib}(${security_stcs_zowe})`);
  copy_to_data_set "${tmpfile}" "${jcllib}(${security_stcs_zowe})" "" std.getenv('ZWE_CLI_PARAMETER_ALLOW_OVERWRITE')
  common.printTrace(`- Delete ${tmpfile}`);
  os.remove(tmpfile);
  if (result.rc != 0) {
    common.printErrorAndExit(`Error ZWEL0160E: Failed to write to ${jcllib}(${security_stcs_zowe}). Please check if target data set is opened by others.`, undefined, 160
  }
  common.printDebug(`- ${jcllib}(${security_stcs_zowe}) is prepared`);

  // ZWESISTC
  common.printMessage(`Modify ZWESISTC and save as ${jcllib}(${security_stcs_zis})`);
  tmpfile = fs.createTmpFile(`zwe ${std.getenv('ZWE_CLI_COMMANDS_LIST')}`.replace(new RegExp('\s', 'g'), '-'));
  common.printDebug(`- Copy ${prefix}.${std.getenv('ZWE_PRIVATE_DS_SZWESAMP')}(ZWESISTC) to ${tmpfile}`);
  result = shell.execOutSync('sh', '-c', `cat "//'${prefix}.${std.getenv('ZWE_PRIVATE_DS_SZWESAMP')}(ZWESISTC)'" | `+
          sed '/^..STEPLIB/c\
\//STEPLIB  DD   DSNAME='${authLoadlib}',DISP=SHR\
\//         DD   DSNAME='${authPluginLib}',DISP=SHR' | `+
          sed "s/^\/\/PARMLIB .*\$/\/\/PARMLIB  DD   DSNAME=${parmlib},DISP=SHR/" `+
          > "${tmpfile}" &&   chmod 700 "${tmpfile}");

  if (result.rc == 0) {
    common.printDebug(`  * Succeeded`);
    common.printTrace(`  * Exit code: ${result.rc}`);
    common.printTrace(`  * Output:`);
    if (result.out) {
      common.printTrace(stringlib.paddingLeft(result.out, "    "));
    }
  } else {
    common.printDebug(`  * Failed`);
    common.printError(`  * Exit code: ${result.rc}`);
    common.printError(`  * Output:`);
    if (result.out) {
      common.printError(stringlib.paddingLeft(result.out, "    "));
    }
    std.exit(1);
  }
  if (!fs.fileExists(tmpfile) {
    common.printErrorAndExit(`Error ZWEL0159E: Failed to modify ${prefix}.${std.getenv('ZWE_PRIVATE_DS_SZWESAMP')}(ZWESISTC)`, undefined, 159
  }
  common.printTrace(`- ensure ${tmpfile} encoding before copying into data set`);
  ensure_file_encoding "${tmpfile}" "SPDX-License-Identifier"
  common.printTrace(`- ${tmpfile} created, copy to ${jcllib}(${security_stcs_zis})`);
  copy_to_data_set "${tmpfile}" "${jcllib}(${security_stcs_zis})" "" std.getenv('ZWE_CLI_PARAMETER_ALLOW_OVERWRITE')
  common.printTrace(`- Delete ${tmpfile}`);
  os.remove(tmpfile);
  if (result.rc != 0) {
    common.printErrorAndExit(`Error ZWEL0160E: Failed to write to ${jcllib}(${security_stcs_zis}). Please check if target data set is opened by others.`, undefined, 160
  }
  common.printDebug(`- ${jcllib}(${security_stcs_zis}) is prepared`);

  // ZWESASTC
  common.printMessage(`Modify ZWESASTC and save as ${jcllib}(${security_stcs_aux})`);
  tmpfile = fs.createTmpFile(`zwe ${std.getenv('ZWE_CLI_COMMANDS_LIST')}`.replace(new RegExp('\s', 'g'), '-'));
  common.printDebug(`- Copy ${prefix}.${std.getenv('ZWE_PRIVATE_DS_SZWESAMP}(ZWESASTC) to ${tmpfile}`);
  result = shell.execOutSync('sh', '-c', `cat "//'${prefix}.${std.getenv('ZWE_PRIVATE_DS_SZWESAMP')}(ZWESASTC)'" | `+
          sed '/^..STEPLIB/c\
\//STEPLIB  DD   DSNAME='${authLoadlib}',DISP=SHR\
\//         DD   DSNAME='${authPluginLib}',DISP=SHR' `+
          > "${tmpfile}")
  chmod 700 "${tmpfile}"
  if (result.rc == 0) {
    common.printDebug(`  * Succeeded`);
    common.printTrace(`  * Exit code: ${result.rc}`);
    common.printTrace(`  * Output:`);
    if (result.out) {
      common.printTrace(stringlib.paddingLeft(result.out, "    "));
    }
  } else {
    common.printDebug(`  * Failed`);
    common.printError(`  * Exit code: ${result.rc}`);
    common.printError(`  * Output:`);
    if (result.out) {
      common.printError(stringlib.paddingLeft(result.out, "    "));
    }
    std.exit(1);
  }
  if (!fs.fileExists(tmpfile)) {
    common.printErrorAndExit(`Error ZWEL0159E: Failed to modify ${prefix}.${std.getenv('ZWE_PRIVATE_DS_SZWESAMP')}(ZWESASTC)`, undefined, 159);
  }
  common.printTrace(`- ensure ${tmpfile} encoding before copying into data set`);
  ensure_file_encoding "${tmpfile}" "SPDX-License-Identifier"
  common.printTrace(`- ${tmpfile} created, copy to ${jcllib}(${security_stcs_aux})`);
  copy_to_data_set "${tmpfile}" "${jcllib}(${security_stcs_aux})" "" std.getenv('ZWE_CLI_PARAMETER_ALLOW_OVERWRITE')
  common.printTrace(`- Delete ${tmpfile}`);
  os.remove(tmpfile);
  if (result.rc != 0) {
    common.printErrorAndExit(`Error ZWEL0160E: Failed to write to ${jcllib}(${security_stcs_aux}). Please check if target data set is opened by others.`, undefined, 160);
  }
  common.printDebug(`- ${jcllib}(${security_stcs_aux}) is prepared`);

  print_message
}

if (stc_existence == true && std.getenv('ZWE_CLI_PARAMETER_ALLOW_OVERWRITE') != "true") {
  common.printMessage(`Skipped writing to ${proclib}(${mb}). To write, you must use --allow-overwrite.`);
} else {
  // copy to proclib
  for mb in ${target_proclibs}; do
    common.printMessage(`Copy ${jcllib}(${mb}) to ${proclib}(${mb})`);
    data_set_copy_to_data_set "${prefix}" "${jcllib}(${mb})" "${proclib}(${mb})" "-X" std.getenv('ZWE_CLI_PARAMETER_ALLOW_OVERWRITE')
    if (result.rc != 0) {
      common.printErrorAndExit(`Error ZWEL0111E: Command aborts with error.`, undefined, 111);
    }
  done
}

// exit message
print_level2_message "Zowe main started tasks are installed successfully.`);
}
