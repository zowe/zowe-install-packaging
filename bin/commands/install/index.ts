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
import * as common from '../../libs/common';
import * as config from '../../libs/config';
import * as fs from '../../libs/fs';
import * as zosdataset from '../../libs/zos-dataset';
import * as zosJes from '../../libs/zos-jes';

export function execute(): void {

  common.printLevel1Message("Install Zowe MVS data sets");

  const runtimeEnv = std.getenv('ZWE_zowe_runtimeDirectory');

  const zoweConfig = config.getZoweConfig();
  let runtime = zoweConfig.zowe?.runtimeDirectory;
  const prefix = zoweConfig.zowe.setup?.dataset?.prefix;
  const jclHeaderCfg = zoweConfig.zowe.setup?.jcl?.header;
  let jclHeaderJoined: string;

  if (!runtime) {
    runtime = runtimeEnv;
  } else {
    // We need clean path for xplatform.loadFileUTF8, otherwise will fail for e.g. /zowe/./files/SZWESAMP//ZWEINSTL
    runtime = fs.convertToAbsolutePath(runtime);
    if (runtime != runtimeEnv) {
      common.printErrorAndExit(`Error ZWEL0105E: The Zowe YAML config file is associated to Zowe runtime "${runtime}", which is not same as where zwe command is located "${runtimeEnv}".`, undefined, 105);
    }
  }

  if (!prefix) {
    common.printErrorAndExit(`Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }

  if (Array.isArray(jclHeaderCfg)) {
    jclHeaderJoined = jclHeaderCfg.join("\n");
  } else {
    jclHeaderJoined = jclHeaderCfg.toString();
  }

  const ZWEINSTL=`${runtime}/files/SZWESAMP/ZWEINSTL`;
  const DATASETS = [ 'SZWEAUTH', 'SZWEEXEC', 'SZWELOAD', 'SZWESAMP' ];
  const allowOverwrite = std.getenv("ZWE_CLI_PARAMETER_ALLOW_OVERWRITE") == 'true';
  const dryRun = std.getenv("ZWE_CLI_PARAMETER_DRY_RUN") == 'true';
  const existingDatasets: string[] = [];
  let skipJCL = false;

  for (let ds in DATASETS) {
    if (zosdataset.isDatasetExists(`${prefix}.${DATASETS[ds]}`)) {
      if (allowOverwrite === false) {
        common.printMessage(`Warning ZWEL0301W: ${prefix}.${DATASETS[ds]} already exists and will not be overwritten. For upgrades, you must use --allow-overwrite.`);
        skipJCL = true;
      } else {
        common.printMessage(`Warning ZWEL0300W: ${prefix}.${DATASETS[ds]} already exists. Members in this data set will be overwritten.`);
        existingDatasets.push(`${prefix}.${DATASETS[ds]}`);
      }
    }
  }

  if (skipJCL && !dryRun) {
    common.printLevel1Message("Zowe MVS data sets installation skipped.");
    std.exit(0);
  }

  // If file does not exist, xplatform.loadFileUTF8 ends javascript and ZWEL0159E is not printed
  let jclContents = fs.fileExists(ZWEINSTL, true) ? xplatform.loadFileUTF8(ZWEINSTL, xplatform.AUTO_DETECT) : null;
  if (!jclContents) {
    common.printErrorAndExit(`Error ZWEL0159E Failed to modify ${ZWEINSTL}.`, undefined, 159);
  }

  jclContents = jclContents.replace(/\{zowe\.setup\.jcl\.header\}/gi, jclHeaderJoined.replace(/[$]/g, '$$$$'));
  jclContents = jclContents.replace(/\{zowe\.setup\.dataset\.prefix\}/gi, prefix.replace(/[$]/g, '$$$$'));
  jclContents = jclContents.replace(/\{zowe\.runtimeDirectory\}/gi, runtime.replace(/[$]/g, '$$$$'));

  common.printMessage(`Template JCL: ${ZWEINSTL}`);
  common.printMessage('--- JCL content ---');
  common.printMessage(jclContents);
  common.printMessage('--- End of JCL ---');

  if (dryRun) {
    common.printMessage('JCL not submitted, command run with "--dry-run" flag.');
    common.printMessage('To perform command, re-run command without "--dry-run" flag, or submit the JCL directly.');
  } else {
    if (existingDatasets.length > 0) {
      common.printMessage('Deleting existing datasets.');
      for (const ds of existingDatasets) {
        common.printDebug(`Deleting ${ds}.`);
        const res = zosdataset.tsoDeleteDataset(ds);
        if (res != 0) {
          common.printErrorAndExit(`Error ZWEL0112E: Could not delete existing dataset: '${ds}'.`, undefined, 112);
        }
      }
    }

    common.printMessage('Submitting Job ZWEINSTL');
    const jobId = zosJes.submitJob(jclContents, true, true);
    const result = zosJes.waitForJob(jobId);
    if (result.rc == zosJes.WAIT_FOR_JOB_NO_SDSF) {
      common.printMessage(`No SDSF detected, review the job log of ZWEINSTL(${jobId}) manually.`);
    } else {
      common.printMessage(`Job ZWEINSTL(${jobId}) completed with RC=${result.rc}`);
      if (result.rc == 0) {
        common.printLevel1Message("Zowe MVS data sets are installed successfully.");
        common.printMessage("Zowe installation completed. In order to use Zowe, you need to run \"zwe init\" command to initialize Zowe instance.");
        common.printMessage("- Type \"zwe init --help\" to get more information.\n\n");
        common.printMessage("You can also run individual init sub-commands: generate, mvs, certificate, security, vsam, apfauth, and stc.");
        common.printMessage("- Type \"zwe init <sub-command> --help\" (for example, \"zwe init stc --help\") to get more information.\n\n");
        common.printMessage("Zowe JCL generated successfully");
      } else {
        common.printMessage(`Zowe JCL submitted with errors, check job log. Job completion code=${result.jobcccode}, Job completion text=${result.jobcctext}`);
      }
    }
  }

}
