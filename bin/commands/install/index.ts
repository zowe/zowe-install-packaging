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
import * as zosJes from '../../libs/zos-jes';
import * as zosDataset from '../../libs/zos-dataset';

export function execute(allowOverwrite?: boolean, datasetPrefix?: string) {
  common.printLevel0Message("Install Zowe MVS data sets");

  
  // constants
  // keep in sync with workflows/templates/smpe-install/ZWE3ALOC.vtl
  const custDsList = [ std.getenv('ZWE_PRIVATE_DS_SZWESAMP'), 
                       std.getenv('ZWE_PRIVATE_DS_SZWEAUTH'), 
                       std.getenv('ZWE_PRIVATE_DS_SZWELOAD'), 
                       std.getenv('ZWE_PRIVATE_DS_SZWEEXEC') ];

  let prefix: string;

  // validation
  if (datasetPrefix) {
    prefix = datasetPrefix;
  } else {
    common.requireZoweYaml();
    const zoweConfig = config.getZoweConfig();
    
    // read prefix and validate
    prefix = zoweConfig.zowe.setup.dataset.prefix;
    if (!prefix) {
      common.printErrorAndExit(`Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file.`, undefined, 157);
    }
  }


  // create data sets if they do not exist
  common.printMessage(`Create MVS data sets if they do not exist`);
  let dsExistence: boolean = false;
  custDsList.forEach((ds)=> {
    // check existence
    dsExistence = zosDataset.isDatasetExists(prefix+'.'+ds);
    if (dsExistence) {
      if (allowOverwrite) {
        // warning
        common.printMessage(`Warning ZWEL0300W: ${prefix}.${ds} already exists. Members in this data set will be overwritten.`);
      } else {
        // warning
        common.printMessage(`Warning ZWEL0301W: ${prefix}.${ds} already exists and will not be overwritten. For upgrades, you must use --allow-overwrite.`);
      }
    }
  });
  common.printMessage(``);

  if (dsExistence && !allowOverwrite) {
    common.printLevel1Message(`Zowe MVS data sets installation skipped.`);
  } else {
    let jclContents = xplatform.loadFileUTF8(std.getenv('ZWE_zowe_runtimeDirectory')+'/files/SZWESAMP/ZWEINSTL', xplatform.AUTO_DETECT);
    jclContents = jclContents.replace(/\{zowe\.runtimeDirectory\}/gi, std.getenv('ZWE_zowe_runtimeDirectory'))
      .replace(/\{zowe\.setup\.dataset\.prefix\}/gi, prefix)
        
    zosJes.printAndHandleJcl(jclContents, `ZWEINSTL`, prefix, prefix, false, false, true);
    
    // exit message
    common.printLevel1Message(`Zowe MVS data sets are installed successfully.`);
  }


  common.printMessage(`Zowe installation completed. In order to use Zowe, you need to run \"zwe init\" command to initialize Zowe instance.`);
  common.printMessage(`- Type \"zwe init --help\" to get more information.`);
  common.printMessage(``);
  common.printMessage(`You can also run individual init sub-commands: mvs, certificate, security, vsam, apfauth, and stc.`);
  common.printMessage(`- Type \"zwe init <sub-command> --help\" (for example, \"zwe init stc --help\") to get more information.`);
  common.printMessage(``);
}
