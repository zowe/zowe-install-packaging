/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as os from 'cm_os'
import * as common from '../../libs/common';
import * as fs from '../../libs/fs';
import * as zosdataset from '../../libs/zos-dataset';

function copyFromDirectory(pathFrom: string, datasetTo: string, copyOptions: string, overWrite: boolean) {
  const stats = os.stat(pathFrom);
  if (stats[1])
    common.printErrorAndExit("Error ZWEL0104E: Invalid command 'os.stat'", undefined, 104);
  // Copy all files from directory
  if (stats[1] == 0 && ((stats[0].mode & os.S_IFMT) == os.S_IFDIR)){
    const modules = fs.getFilesInDirectory(pathFrom) || [];
    for (let i = 0; i < modules.length; i++) {
      const module = modules[i];
      common.printMessage(`Copy ${pathFrom}/${module} to ${datasetTo}/(${module})`);
      const rc = zosdataset.copyToDataset(`${pathFrom}/${module}`, `${datasetTo}(${module})`, copyOptions, overWrite);
      if (rc != 0) {
        common.printErrorAndExit("Error ZWEL0111E: Command aborts with error.", undefined, 111);
      }
    }
    return;
  }
  // Copy specified file from directory
  if (stats[1] == 0 && ((stats[0].mode & os.S_IFMT) == os.S_IFREG)) {
    common.printMessage(`Copy ${pathFrom} to ${datasetTo}`);
    const rc = zosdataset.copyToDataset(pathFrom, datasetTo, copyOptions, overWrite);
    if (rc != 0) {
      common.printErrorAndExit("Error ZWEL0111E: Command aborts with error.", undefined, 111);
    }
  }
}

export function execute(prefix: string) {
    common.printLevel1Message("Install Zowe MVS data sets");

    const allowOverwrite = std.getenv("ZWE_CLI_PARAMETER_ALLOW_OVERWRITE") == 'true' ? true : false;
    const sampLib = std.getenv("ZWE_PRIVATE_DS_SZWESAMP");
    const authLib = std.getenv("ZWE_PRIVATE_DS_SZWEAUTH");
    const loadLib = std.getenv("ZWE_PRIVATE_DS_SZWELOAD");
    const execLib = std.getenv("ZWE_PRIVATE_DS_SZWEEXEC");

    let dsSkipped = 0;
    let customDSList = {
      sampLib: {
        ds: `${sampLib}`,
        name: "Zowe sample library",
        spec: "dsntype(library) dsorg(po) recfm(f b) lrecl(80) unit(sysallda) space(15,15) tracks"
      },
      authLib: {
        ds: `${authLib}`,
        name: "Zowe authorized load library",
        spec: "dsntype(library) dsorg(po) recfm(u) lrecl(0) blksize(32760) unit(sysallda) space(30,15) tracks"
      },
      loadLib: {
        ds: `${loadLib}`,
        name: "Zowe load library",
        spec: "dsntype(library) dsorg(po) recfm(u) lrecl(0) blksize(32760) unit(sysallda) space(30,15) tracks"
      },
      execLib: {
        ds: `${execLib}`,
        name: "Zowe executable utilities library",
        spec: "dsntype(library) dsorg(po) recfm(f b) lrecl(80) unit(sysallda) space(15,15) tracks"
      }
    }
  
    common.printMessage( "Create MVS data sets if they do not exist");
    for (const lib in customDSList){
      const dsExists = zosdataset.isDatasetExists(`${prefix}.${customDSList[lib].ds}`);
      if (dsExists){
        if (allowOverwrite) {
          common.printMessage(`Warning ZWEL0300W: ${prefix}.${customDSList[lib].ds} already exists. Members in this data set will be overwritten.`);
        } else {
          common.printMessage(`Warning ZWEL0301W: ${prefix}.${customDSList[lib].ds} already exists and will not be overwritten. For upgrades, you must use --allow-overwrite.`);
          dsSkipped++;
        }
      } else {
        common.printMessage(`Creating ${customDSList[lib].name} - ${prefix}.${customDSList[lib].ds}"`);
        const rc = zosdataset.createDataSet(`${prefix}.${customDSList[lib].ds}`, customDSList[lib].spec);
        if (rc){
          common.printErrorAndExit("Error ZWEL0111E: Command aborts with error.", undefined, 111);
        }
      }
    };
    
    common.printMessage('');
    
    if (dsSkipped == Object.keys(customDSList).length) {
      common.printLevel1Message("Zowe MVS data sets installation skipped. For upgrades, you must use --allow-overwrite.");
    } else {

      const runtime = std.getenv('ZWE_zowe_runtimeDirectory');
    
      copyFromDirectory(`${runtime}/files/${sampLib}`, `${prefix}.${sampLib}`, "", allowOverwrite);

      copyFromDirectory(`${runtime}/files/${execLib}`, `${prefix}.${execLib}`, "", allowOverwrite);
      
      copyFromDirectory(`${runtime}/components/launcher/samplib/ZWESLSTC`, `${prefix}.${sampLib}(ZWESLSTC)`, "", allowOverwrite);

      copyFromDirectory(`${runtime}/components/launcher/bin/zowe_launcher`, `${prefix}.${authLib}(ZWELNCH)`, "-X", allowOverwrite);
      
      copyFromDirectory(`${runtime}/files/${loadLib}`, `${prefix}.${loadLib}`, "-X", allowOverwrite);
      
      const ZSS_SAMPLIB = [
        ['ZWESAUX','ZWESASTC'],
        ['ZWESIP00'], 
        ['ZWESIS01', 'ZWESISTC'],
        ['ZWESISCH']
      ];
      ZSS_SAMPLIB.forEach(member => {
        const zss_from = member[0];
        const zss_to = member[1] || member[0];
          copyFromDirectory(`${runtime}/components/zss/SAMPLIB/${zss_from}`, `${prefix}.${sampLib}(${zss_to})`, "", allowOverwrite);    
      })
      copyFromDirectory(`${runtime}/components/zss/LOADLIB`, `${prefix}.${authLib}`, "-X", allowOverwrite);

    }

    common.printLevel1Message("Zowe MVS data sets are installed successfully.");

    common.printMessage("Zowe installation completed. In order to use Zowe, you need to run \"zwe init\" command to initialize Zowe instance.");
    common.printMessage("- Type \"zwe init --help\" to get more information.\n\n");
    common.printMessage("You can also run individual init sub-commands: mvs, certificate, security, vsam, apfauth, and stc.");
    common.printMessage("- Type \"zwe init <sub-command> --help\" (for example, \"zwe init stc --help\") to get more information.\n\n");
}
