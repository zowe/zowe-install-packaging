/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as os from 'cm_os';
import * as xplatform from 'xplatform';
import * as common from '../../../libs/common';
import * as stringlib from '../../../libs/string';
import * as fs from '../../../libs/fs';
import * as shell from '../../../libs/shell';
import * as config from '../../../libs/config';
import * as zoslib from '../../../libs/zos';
import * as zosfs from '../../../libs/zos-fs';
import * as zosdataset from '../../../libs/zos-dataset';
import * as zosjes from '../../../libs/zos-jes';
import { strftime } from '../../../libs/strftime';

export function execute(dryRun?: boolean, ignoreSecurityFailures?: boolean) {
  common.printLevel1Message(`Run Zowe security configurations`);

  // Validation
  common.requireZoweYaml();
  const zoweConfig = config.getZoweConfig();

  // read prefix and validate
  if (! zoweConfig.zowe?.setup?.dataset) {
    common.printErrorAndExit(`Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }
  const prefix=zoweConfig.zowe.setup.dataset.prefix;
  if (!prefix) {
    common.printErrorAndExit(`Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }
  // read JCL library and validate
  const jcllib=zoweConfig.zowe.setup.dataset.jcllib;
  if (!jcllib) {
    common.printErrorAndExit(`Error ZWEL0157E: Zowe custom JCL library (zowe.setup.dataset.jcllib) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }
  const securityProduct=zoweConfig.zowe.setup.security?.product || 'RACF';
  const securityGroupsAdmin=zoweConfig.zowe.setup.security?.groups?.admin || std.getenv('ZWE_PRIVATE_DEFAULT_ADMIN_GROUP');
  const securityGroupsStc=zoweConfig.zowe.setup.security?.groups?.stc || std.getenv('ZWE_PRIVATE_DEFAULT_ADMIN_GROUP');
  const securityGroupsSysprog=zoweConfig.zowe.setup.security?.groups?.sysProg || std.getenv('ZWE_PRIVATE_DEFAULT_ADMIN_GROUP');
  const securityUsersZowe=zoweConfig.zowe.setup.security?.users?.zowe || std.getenv('ZWE_PRIVATE_DEFAULT_ZOWE_USER');
  const securityUsersZis=zoweConfig.zowe.setup.security?.users?.zis || std.getenv('ZWE_PRIVATE_DEFAULT_ZIS_USER');
  const securityStcsZowe=zoweConfig.zowe.setup.security?.stcs?.zowe || std.getenv('ZWE_PRIVATE_DEFAULT_ZOWE_STC');
  const securityStcsZis=zoweConfig.zowe.setup.security?.stcs?.zis || std.getenv('ZWE_PRIVATE_DEFAULT_ZIS_STC');
  const securityStcsAux=zoweConfig.zowe.setup.security?.stcs?.aux || std.getenv('ZWE_PRIVATE_DEFAULT_AUX_STC');


  // prepare ZWESECUR JCL
  common.printMessage(`Modify ZWESECUR`);
  const spaceReplacer = new RegExp('\ ', 'g');
  let tmpfile=fs.createTmpFile(`zwe ${std.getenv('ZWE_CLI_COMMANDS_LIST')}`.replace(spaceReplacer, '-'));
  const tmpdsm=zosdataset.createDatasetTmpMember(jcllib, `ZW${strftime("%H%M")}`);
  common.printDebug(`- Copy ${prefix}.${std.getenv('ZWE_PRIVATE_DS_SZWESAMP')}(ZWESECUR) to ${tmpfile}`);
  // cat "//'IBMUSER.ZWEV2.SZWESAMP(ZWESECUR)'" | sed "s/^\\/\\/ \\+SET \\+PRODUCT=.*\\$/\\/\\         SET  PRODUCT=ACF2         * RACF, ACF2, or TSS/"
  const zwesecurResult = shell.execOutSync('sh', '-c', ` cat "//'${prefix}.${std.getenv('ZWE_PRIVATE_DS_SZWESAMP')}(ZWESECUR)'"`);
  if (zwesecurResult.rc == 0) {
    common.printDebug(`  * Succeeded`);
    common.printTrace(`  * Exit code: ${zwesecurResult.rc}`);
    common.printTrace(`  * Output:`);
    if (zwesecurResult.out) {
      common.printTrace(stringlib.paddingLeft(zwesecurResult.out, "    "));
    }


//this doesnt appear to have worked.
    
    xplatform.storeFileUTF8(tmpfile, xplatform.AUTO_DETECT,
                          zwesecurResult.out
                          .replace(/\n\/\/\s+SET\s+PRODUCT=.*\n/, `\n//         SET  PRODUCT=${securityProduct}\n`)
                          .replace(/\n\/\/\s+SET\s+ADMINGRP=.*\n/, `\n//         SET  ADMINGRP=${securityGroupsAdmin}\n`)
                          .replace(/\n\/\/\s+SET\s+STCGRP=.*\n/, `\n//         SET  STCGRP=${securityGroupsStc}\n`)
                          .replace(/\n\/\/\s+SET\s+ZOWEUSER=.*\n/, `\n//         SET  ZOWEUSER=${securityUsersZowe}\n`)
                          .replace(/\n\/\/\s+SET\s+ZISUSER=.*\n/, `\n//         SET  ZISUSER=${securityUsersZis}\n`)
                          .replace(/\n\/\/\s+SET\s+ZOWESTC=.*\n/, `\n//         SET  ZOWESTC=${securityStcsZowe}\n`)
                          .replace(/\n\/\/\s+SET\s+ZISSTC=.*\n/, `\n//         SET  ZISSTC=${securityStcsZis}\n`)
                          .replace(/\n\/\/\s+SET\s+AUXSTC=.*\n/, `\n//         SET  AUXSTC=${securityStcsAux}\n`)
                          .replace(/\n\/\/\s+SET\s+HLQ=.*\n/, `\n//         SET  HLQ=${prefix}\n`)
                          .replace(/\n\/\/\s+SET\s+SYSPROG=.*\n/, `\n//         SET  SYSPROG=${securityGroupsSysprog}\n`));
  } else {
    common.printDebug(`  * Failed`);
    common.printError(`  * Exit code: ${zwesecurResult.rc}`);
    common.printError(`  * Output:`);
    if (zwesecurResult.out) {
      common.printError(stringlib.paddingLeft(zwesecurResult.out, "    "));
    }
  }
  if (!fs.fileExists(tmpfile)) {
    common.printErrorAndExit(`Error ZWEL0159E: Failed to modify ${prefix}.${std.getenv('ZWE_PRIVATE_DS_SZWESAMP')}(ZWESECUR)`, undefined, 159);
  }
  common.printTrace(`- ensure ${tmpfile} encoding before copying into data set`);
  zosfs.ensureFileEncoding(tmpfile, "SPDX-License-Identifier");
  common.printTrace(`- ${tmpfile} created, copy to ${jcllib}(${tmpdsm})`);
  const rc = zosdataset.copyToDataset(tmpfile, `${jcllib}(${tmpdsm})`, undefined, std.getenv('ZWE_CLI_PARAMETER_ALLOW_OVERWRITE')=='true');
  common.printTrace(`- Delete ${tmpfile}`);
  os.remove(tmpfile);
  if (rc != 0) {
    common.printErrorAndExit(`Error ZWEL0160E: Failed to write to ${jcllib}(${tmpdsm}). Please check if target data set is opened by others.`, undefined, 160);
  }
  common.printMessage(`- ${jcllib}(${tmpdsm}) is prepared\n`);

  // submit job
  let jobHasFailures;
  dryRun = std.getenv("ZWE_CLI_PARAMETER_SECURITY_DRY_RUN");
  ignoreSecurityFailures = std.getenv("ZWE_CLI_PARAMETER_IGNORE_SECURITY_FAILURES");
  if (dryRun == true) {
    common.printMessage(`Dry-run mode, security setup is NOT performed on the system.`);
    common.printMessage(`Please submit ${jcllib}(${tmpdsm}) manually.`);
  } else {
    common.printMessage(`Submit ${jcllib}(${tmpdsm})`);

    const jobid = zosjes.submitJob(`//'${jcllib}(${tmpdsm})'`);
    if (!jobid) {
      jobHasFailures=true;
      if (ignoreSecurityFailures == true) {
        common.printError(`Warning ZWEL0161W: Failed to run JCL ${jcllib}(${tmpdsm}).`);
        // skip wait for job status step
      } else {
        common.printErrorAndExit(`Error ZWEL0161E: Failed to run JCL ${jcllib}(${tmpdsm}).`, undefined, 161);
      }
    } else {
      common.printDebug(`- job id ${jobid}`);
      const jobState = zosjes.waitForJob(jobid);
      const { rc:jobrc, jobname, jobcctext, jobcccode } = zosjes.waitForJob(jobid);
      if (jobrc == 1) {
        jobHasFailures=true;
        if (ignoreSecurityFailures == true) {
          common.printError(`Warning ZWEL0162W: Failed to find job ${jobid} result.`);
        } else {
          common.printErrorAndExit(`Error ZWEL0162E: Failed to find job ${jobid} result.`, undefined, 162);
        }
      } 
      if (jobrc == 0) {

        common.printMessage(`- Job ${jobname}(${jobid}) ends with code ${jobcccode} (${jobcctext}).`);

        common.printMessage(``);
        common.printMessage(`WARNING: Due to the limitation of the ZWESECUR job, exit with 0 does not mean`);
        common.printMessage(`         the job is fully successful. Please check the job log to determine`);
        common.printMessage(`         if there are any inline errors.`);
        common.printMessage(``);
      } else {
        jobHasFailures=true;
        if (ignoreSecurityFailures == true) {
          common.printError(`Warning ZWEL0163W: Job ${jobname}(${jobid}) ends with code ${jobcccode} (${jobcctext}).`);
        } else {
          common.printErrorAndExit(`Error ZWEL0163E: Job ${jobname}(${jobid}) ends with code ${jobcccode} (${jobcctext}).`, undefined, 163);
        }
      }      
    }

    // exit message
    if (jobHasFailures === true) {
      common.printLevel2Message(`Failed to apply Zowe security configurations. Please check job log for details.`);
    } else {
      common.printLevel2Message(`Zowe security configurations are applied successfully.`);
    }
  }
}
