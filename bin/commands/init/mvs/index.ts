/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
  
  SPDX-License-Identifier: EPL-2.0
  
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as zoslib from '../../../libs/zos';
import * as zosdataset from '../../../libs/zos-dataset';
import * as common from '../../../libs/common';
import * as stringlib from '../../../libs/string';
import * as shell from '../../../libs/shell';
import * as config from '../../../libs/config';

export function execute(allowOverwrite?: boolean) {
  common.printLevel1Message(`Initialize Zowe custom data sets`);
  common.requireZoweYaml();
  const zoweConfig = config.getZoweConfig();
  
  const datasets = [
    { configKey: 'parmlib',
      description: 'Zowe parameter library',
      definition: 'dsntype(library) dsorg(po) recfm(f b) lrecl(80) unit(sysallda) space(15,15) tracks'
    },
    { configKey: 'jcllib',
      description: 'Zowe JCL library',
      definition: 'dsntype(library) dsorg(po) recfm(f b) lrecl(80) unit(sysallda) space(15,15) tracks'
    },
    { configKey: 'authLoadlib',
      description: 'Zowe authorized load library',
      definition: 'dsntype(library) dsorg(po) recfm(u) lrecl(0) blksize(32760) unit(sysallda) space(30,15) tracks'
    },
    { configKey: 'authPluginLib',
      description: 'Zowe authorized plugin library',
      definition: 'dsntype(library) dsorg(po) recfm(u) lrecl(0) blksize(32760) unit(sysallda) space(30,15) tracks'
    }
  ];

  const prefix=zoweConfig.zowe.setup?.dataset?.prefix;
  if (!prefix) {
    common.printErrorAndExit(`Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }

  common.printMessage(`Create data sets if they do not exist`);
  let skippedDatasets:boolean = false;
  datasets.forEach((datasetDef) => {    
    // read def and validate
    let skip:boolean = false;
    const ds=zoweConfig.zowe.setup?.dataset ? zoweConfig.zowe.setup.dataset[datasetDef.configKey] : undefined;
    if (!ds) {
      // authLoadlib can be empty
      if (datasetDef.configKey == 'authLoadlib') {
        skip=true;
      } else {
        common.printErrorAndExit(`Error ZWEL0157E: ${datasetDef.configKey} (zowe.setup.dataset.${datasetDef.configKey}) is not defined in Zowe YAML configuration file.`, undefined, 157);
      }
    }
    if (allowOverwrite === undefined){
      allowOverwrite = std.getenv("ZWE_CLI_PARAMETER_ALLOW_OVERWRITE")
    }
    if (!skip) {
      const datasetExists=zosdataset.isDatasetExists(ds);
      if (datasetExists) {
        if (allowOverwrite) {
          common.printMessage(`Warning ZWEL0300W: ${ds} already exists. Members in this data set will be overwritten.`);
        } else {
          skippedDatasets = true;
          common.printMessage(`Warning ZWEL0301W: ${ds} already exists and will not be overwritten. For upgrades, you must use --allow-overwrite.`);
        }
      } else {
        common.printMessage(`Creating ${ds}`);
        let rc = zosdataset.createDataSet(ds, datasetDef.definition);
        if (rc!=0) {
          common.printErrorAndExit(`Error ZWEL0111E: Command aborts with error.`, undefined, 111);
        }
      }
    }
  });

  if (skippedDatasets && !allowOverwrite) {
    common.printMessage(`Skipped writing to a dataset. To write, you must use --allow-overwrite.`);
  } else {
    // copy sample lib members
    const parmlib=zoweConfig.zowe.setup?.dataset?.parmlib;
    ['ZWESIP00'].forEach((ds)=> {
      const source = `${prefix}.${std.getenv("ZWE_PRIVATE_DS_SZWESAMP")}(${ds})`;
      common.printMessage(`Copy ${source} to ${parmlib}(${ds})`);
      let rc = zosdataset.datasetCopyToDataset(prefix, source, `${parmlib}(${ds})`, allowOverwrite);
      if (rc!=0) {
        common.printErrorAndExit(`Error ZWEL0111E: Command aborts with error.`, undefined, 111);
      }
    });

    // copy auth lib members
    // FIXME: data_set_copy_to_data_set cannot be used to copy program?
    const authLoadlib=zoweConfig.zowe.setup?.dataset?.authLoadlib;
    if (authLoadlib) {
      ['ZWESIS01', 'ZWESAUX'].forEach((ds)=> {
        common.printMessage(`Copy components/zss/LOADLIB/${ds} to ${authLoadlib}(${ds})`);
        let rc = zosdataset.copyToDataset(`${zoweConfig.zowe.runtimeDirectory}/components/zss/LOADLIB/${ds}`, `${authLoadlib}(${ds})`, "-X", allowOverwrite);
        if (rc!=0) {
          common.printErrorAndExit(`Error ZWEL0111E: Command aborts with error.`, undefined, 111);
        }
      });
      ['ZWELNCH'].forEach((ds)=> {
        common.printMessage(`Copy components/launcher/bin/zowe_launcher to ${authLoadlib}(${ds})`);
        let rc = zosdataset.copyToDataset(`${zoweConfig.zowe.runtimeDirectory}/components/launcher/bin/zowe_launcher`, `${authLoadlib}(${ds})`, "-X", allowOverwrite);
        if (rc!=0) {
          common.printErrorAndExit(`Error ZWEL0111E: Command aborts with error.`, undefined, 111);
        }
      });
    }
  }

  common.printLevel2Message(`Zowe custom data sets are initialized successfully.`);
}
