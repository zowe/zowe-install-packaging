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

// **********************************
// This would be moved to zos-dataset
function validDatasetName(dsn: string): boolean {
    common.printTrace(`- validDatasetName for "${dsn}"`);
    if (!dsn || dsn.length < 1 || dsn.length > 44) {
        common.printTrace('  * dataset null, empty or > 44 chars');
        return false;
    }
    const result = !!dsn.match(/^([A-Z\$\#\@]){1}([A-Z0-9\$\#\@\-]){0,7}(\.([A-Z\$\#\@]){1}([A-Z0-9\$\#\@\-]){0,7}){0,11}$/g);
    common.printTrace(`  * regex match: ${result}`);
    return result;
}
// This would be moved to zos-dataset
// **********************************

export function execute(): void {

    common.printLevel1Message("Install Zowe MVS data sets");

    common.requireZoweYaml();
    const zoweConfig = config.getZoweConfig();

    const prefix = zoweConfig.zowe.setup?.dataset?.prefix;
    if (!prefix) {
        common.printErrorAndExit(`Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file.`, undefined, 157); 
    } 
    
    let runtime = zoweConfig.zowe?.runtimeDirectory;
    const runtimeEnv = std.getenv('ZWE_zowe_runtimeDirectory');
    if (!runtime) {
        runtime = runtimeEnv;
    } else {
        // We need clean path for xplatform.loadFileUTF8, otherwise will fail for e.g. /zowe/./files/SZWESAMP//ZWEINSTL
        runtime = fs.convertToAbsolutePath(runtime);
        if (runtime != runtimeEnv) {
            common.printErrorAndExit(`Error ZWEL0105E: The Zowe YAML config file is associated to Zowe runtime "${runtime}", which is not same as where zwe command is located "${runtimeEnv}".`, undefined, 105);
        } 
    }

    const ZWEINSTL=`${runtime}/files/SZWESAMP/ZWEINSTL`;
    const DATASETS = [ 'SZWEAUTH', 'SZWEEXEC', 'SZWELOAD', 'SZWESAMP' ];
    const allowOverwrite = std.getenv("ZWE_CLI_PARAMETER_ALLOW_OVERWRITE") == 'true' ? true : false;
    const dryRun = std.getenv("ZWE_CLI_PARAMETER_DRY_RUN") == 'true' ? true : false;
    let skipJCL = false;

    for (let ds in DATASETS) {
        if (zosdataset.isDatasetExists(`${prefix}.${DATASETS[ds]}`)) {
            if (allowOverwrite == false) {
                common.printMessage(`Warning ZWEL0301W: ${prefix}.${DATASETS[ds]} already exists and will not be overwritten. For upgrades, you must use --allow-overwrite.`);
                skipJCL = true;
            } else {
                common.printMessage(`Warning ZWEL0300W: ${prefix}.${DATASETS[ds]} already exists. Members in this data set will be overwritten.`);
                // **************************************************************
                console.log(`FAKE: tsocmd "DELETE '${prefix}.${DATASETS[ds]}'"`);
                // **************************************************************
            }
        }
    }

    if (skipJCL) {
        common.printLevel1Message("Zowe MVS data sets installation skipped.");
        std.exit(0);
    }
    
    let jclContents = xplatform.loadFileUTF8(ZWEINSTL, xplatform.AUTO_DETECT);        
    if (!jclContents) {
        common.printErrorAndExit(`Error ZWEL0159E Failed to modify ${ZWEINSTL}.`, undefined, 159);
    }

    // Make string from array or convert possible number to string
    let jclHeader = zoweConfig.zowe.environments?.jclHeader;
    if (jclHeader !== undefined && jclHeader !== null && jclHeader !== '') {
        jclHeader = Array.isArray(jclHeader) ? jclHeader.join("\n"): jclHeader.toString();
        jclContents = jclContents.replace(/\/\/ZWEINSTL JOB/gi, `//ZWEINSTL JOB ${jclHeader.replace(/[$]/g, '$$$$')}`);
    }

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
        common.printMessage('Submitting Job ZWEINSTL');
        // **************************************************************
        // submitJob and waitForJob implemented in 3718 (migrate2JCL)
        const result = { 
            rc: 0,
            jobcccode: 123,
            jobcctext: "JCL ESM error"
        };
        // const jobid = zosJes.submitJob(jclContents, true, true);
        // const result = zosJes.waitForJob(jobid);
        // **************************************************************
        
        common.printMessage(`Job completed with RC=${result.rc}`);
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