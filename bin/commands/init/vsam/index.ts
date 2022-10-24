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
import * as xplatform from 'xplatform';
import * as common from '../../../libs/common';
import * as stringlib from '../../../libs/string';
import * as shell from '../../../libs/shell';
import * as fs from '../../../libs/fs';
import * as config from '../../../libs/config';
import * as zoslib from '../../../libs/zos';
import * as zosjes from '../../../libs/zos-jes';
import * as zosfs from '../../../libs/zos-fs';
import * as zosdataset from '../../../libs/zos-dataset';

export function execute() {
common.printLevel1Message(`Create VSAM storage for Zowe Caching Service`);

  // Validation
  common.requireZoweYaml();
  const zoweConfig = config.getZoweConfig();

  const allowOverwrite: boolean = std.getenv("ZWE_CLI_PARAMETER_ALLOW_OVERWRITE") == 'true' ? true : false;

  let caching_storage=zoweConfig.components['caching-service'].storage?.mode;
  if (caching_storage) {
    caching_storage.toUpperCase();
  }
  if (caching_storage != "VSAM") {
    common.printError(`Warning ZWEL0301W: Zowe Caching Service is not configured to use VSAM. Command skipped.`);
    return;
  }

  // read prefix and validate
  const prefix=zoweConfig.zowe.setup?.dataset?.prefix;
  if (!prefix) {
    common.printErrorAndExit(`Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }
  // read JCL library and validate
  const jcllib=zoweConfig.zowe.setup?.dataset?.jcllib;
  if (!jcllib) {
    common.printErrorAndExit(`Error ZWEL0157E: Zowe custom JCL library (zowe.setup.dataset.jcllib) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }
  let vsam_mode=zoweConfig.zowe.setup?.vsam?.mode;
  if (!vsam_mode) {
    vsam_mode='NONRLS';
  }
  let vsam_volume;
  if (vsam_mode == "NONRLS") {
    vsam_volume=zoweConfig.zowe.setup?.vsam?.volume;
    if (!vsam_volume) {
      common.printErrorAndExit(`Error ZWEL0157E: Zowe Caching Service VSAM data set Non-RLS volume (zowe.setup.vsam.volume) is not defined in Zowe YAML configuration file.`, undefined, 157);
    }
  }
  let vsam_storageClass;
  if (vsam_mode == "RLS") {
    vsam_storageClass=zoweConfig.zowe.setup?.vsam?.storageClass;
    if (!vsam_storageClass) {
      common.printErrorAndExit(`Error ZWEL0157E: Zowe Caching Service VSAM data set RLS storage class (zowe.setup.vsam.storageClass) is not defined in Zowe YAML configuration file.`, undefined, 157);
    }
  }
  const vsam_name=zoweConfig.components['caching-service'].storage?.vsam?.name;
  if (!vsam_name) {
    common.printErrorAndExit(`Error ZWEL0157E: Zowe Caching Service VSAM data set name (components.caching-service.storage.vsam.name) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }

  const jcl_existence=zosdataset.isDatasetExists(`${jcllib}(ZWECSVSM)`);
  if (jcl_existence == true) {
    if (allowOverwrite) {
      common.printMessage(`Warning ZWEL0300W: ${jcllib}(ZWECSVSM) already exists. This data set member will be overwritten during configuration.`);
    } else {
      common.printMessage(`Warning ZWEL0301W: ${jcllib}(ZWECSVSM) already exists and will not be overwritten. For upgrades, you must use --allow-overwrite.`);
    }
  }

  // VSAM cache cannot be overwritten, must delete manually
  // FIXME: cat cannot be used to test VSAM data set
  const vsam_existence=zosdataset.isDatasetExists(vsam_name);
  if (vsam_existence == true) {
    common.printErrorAndExit(`Error ZWEL0158E: ${vsam_name} already exists.`, undefined, 158);
  }
  if (allowOverwrite) {
    // delete blindly and ignore errors
    let result=zoslib.tsoCommand('delete', `'${vsam_name}'`);
  }


  if (jcl_existence == true && allowOverwrite != true) {
    common.printMessage(`Skipped writing to ${jcllib}(ZWECSVSM). To write, you must use --allow-overwrite.`);
  } else {
    // prepare STCs
    // ZWESLSTC
    common.printMessage(`Modify ZWECSVSM`);
    const replacer = new RegExp('\s', 'g');
    const tmpfile=fs.createTmpFile(`zwe ${std.getenv('ZWE_CLI_COMMANDS_LIST')}`.replace(replacer, '-'));
    common.printDebug(`- Copy ${prefix}.${std.getenv('ZWE_PRIVATE_DS_SZWESAMP')}(ZWECSVSM) to ${tmpfile}`);

    const theDataset = shell.execOutSync('sh', '-c', `cat "//'${prefix}.${std.getenv('ZWE_PRIVATE_DS_SZWESAMP')}(ZWECSVSM)'"`);
    if (theDataset.out) {
      const tmpFileContents = theDataset.replace(new RegExp('^//\s*SET MODE=.*$'), `//         SET  MODE=${vsam_mode}`)
                .replace(new RegExp('\#dsname', 'g'), vsam_name)
                .replace(new RegExp('\#volume', 'g'), vsam_volume)
                .replace(new RegExp('\#storclas', 'g'), vsam_storageClass);
      xplatform.storeFileUTF8(tmpfile, tmpfileContents, xplatform.AUTO_DETECT);
      shell.execSync('chmod', '700', tmpfile);
    }
    
    if (result.rc==0) {
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
      common.printErrorAndExit(`Error ZWEL0159E: Failed to modify ${prefix}.${std.getenv('ZWE_PRIVATE_DS_SZWESAMP')}(ZWECSVSM)`, undefined, 159);
    }
    common.printTrace(`- ${tmpfile} created with content`);
    common.printTrace(xplatform.loadFileUTF8(tmpfile, xplatform.AUTO_DETECT));
    common.printTrace(`- ensure ${tmpfile} encoding before copying into data set`);
    zosfs.ensureFileEncoding(tmpfile, "SPDX-License-Identifier");
    common.printTrace(`- copy to ${jcllib}(ZWECSVSM)`);
    let rc = zosdataset.copyToDataset(tmpfile, `${jcllib}(ZWECSVSM)`, undefined, allowOverwrite);
    common.printTrace(`- Delete ${tmpfile}`);
    os.remove(tmpfile);
    if (rc!=0) {
      common.printErrorAndExit(`Error ZWEL0160E: Failed to write to ${jcllib}(ZWECSVSM). Please check if target data set is opened by others.`, undefined, 160);
    }
    common.printMessage(`- ${jcllib}(ZWECSVSM) is prepared`);
  }

  // submit job
  common.printMessage(`Submit ${jcllib}(ZWECSVSM)`);
  const jobid=zosjes.submitJob(`//'${jcllib}(ZWECSVSM)'`)
  if (!jobid) {
    common.printErrorAndExit(`Error ZWEL0161E: Failed to run JCL ${jcllib}(ZWECSVSM).`, undefined, 161);
  }
  common.printDebug(`- job id ${jobid}`);
  const jobstate=zosjes.waitForJob(jobid);
  if (jobstate.rc==1 || !jobstate.out) {
    common.printErrorAndExit(`Error ZWEL0162E: Failed to find job ${jobid} result.`, undefined, 162);
  }
  const sections = jobstate.out.split(',');
  if (sections.length >= 3) {
    const jobname=sections[1];
    const jobcctext=sections[2];
    const jobcccode=sections[3];
    if (jobstate.rc==0) {
      common.printMessage(`- Job ${jobname}(${jobid}) ends with code ${jobcccode} (${jobcctext}).`);
    } else {
      common.printErrorAndExit(`Error ZWEL0163E: Job ${jobname}(${jobid}) ends with code ${jobcccode} (${jobcctext}).`, undefined, 163);
    }
  } else {
    common.printErrorAndExit(`Error ZWEL0999E: Waiting for job failed, jobname parsing failed.`);
  }
  // exit message
  common.printLevel2Message(`Zowe Caching Service VSAM storage is created successfully.`);
}
