
/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';

import * as common from './common';
import * as stringlib from './string';
import * as shell from './shell';
import * as zoslib from './zos';

export function isDatasetExists(datasetName: string): boolean {
  if (!datasetName) { return false; }
  const result = shell.execSync('sh', '-c', `cat "//'${datasetName}'" 1>/dev/null 2>&1`);
  return result.rc === 0;
}

// Check if data set exists using TSO command (listds)
// @return        0: exist
//                1: data set is not in catalog
//                2: data set member doesn't exist
export function tsoIsDatasetExists(datasetName: string): number {
  if (!datasetName) { return 9; }
  const result = zoslib.tsoCommand(`listds '${datasetName}' label`);
  if (result.rc != 0) {
    if (result.out.includes('NOT IN CATALOG')) {
      return 1;
    }

    if (result.out.includes('MEMBER NAME NOT FOUND')) {
      return 2;
    }
    // some other error we don't know yet
    return 9;
  }

  return 0;
}

export function createDataSet(dsName: string, dsOptions: string): number {
  const result=zoslib.tsoCommand(`ALLOCATE NEW DA('${dsName}') ${dsOptions}`);
  return result.rc;
}

export function copyToDataset(filePath: string, dsName: string, cpOptions: string='', allowOverwrite?: boolean): number {
  if (allowOverwrite != true) {
    if (isDatasetExists(dsName)) {
      common.printErrorAndExit(`Error ZWEL0133E: Data set ${dsName} already exists`, undefined, 133);
    }
  }

  const cpCommand=`cp ${cpOptions} -v "${filePath}" "//'${dsName}'"`;
  common.printDebug('- '+cpCommand);
  const result=shell.execOutSync('sh', '-c', `${cpCommand} 2>&1`);
  if (result.rc == 0) {
    common.printDebug("  * Succeeded");
    common.printTrace(`  * Exit code: ${result.rc}`);
    common.printTrace("  * Output:");
    common.printTrace(stringlib.paddingLeft(result.out, "    "));
  } else {
    common.printDebug("  * Failed");
    common.printTrace(`  * Exit code: ${result.rc}`);
    common.printTrace("  * Output:");
    common.printError(stringlib.paddingLeft(result.out, "    "));
  }
  return result.rc;
}

export function datasetCopyToDataset(prefix: string, datasetFrom: string, datasetTo: string, allowOverwrite: boolean): number {
  if (allowOverwrite != true) {
    if (isDatasetExists(datasetTo)) {
      common.printErrorAndExit(`Error ZWEL0133E: Data set ${datasetTo} already exists`, undefined, 133);
    }
  }

  const cmd=`exec '${prefix}.${std.getenv('ZWE_PRIVATE_DS_SZWEEXEC')}(ZWEMCOPY)' '${datasetFrom} ${datasetTo}'`;
  const result = zoslib.tsoCommand(cmd);
  return result.rc;
}

// List users of a data set
//
// @param dsn     data set name to check
// @return        0: no users
//                1: there are some users
// @output        output of operator command "d grs"
export function listDatasetUser(datasetName: string): number {
  const cmd=`D GRS,RES=(*,${datasetName})`;
  const result=zoslib.operatorCommand(cmd);
  return result.out.includes('NO REQUESTORS FOR RESOURCE') ? 0 : 1;
  // example outputs:
  //
  // server    2021040  22:29:30.60             ISF031I CONSOLE MYCONS ACTIVATED
  // server    2021040  22:29:30.60            -D GRS,RES=(*,IBMUSER.PARMLIB)
  // server    2021040  22:29:30.60             ISG343I 22.29.30 GRS STATUS 336
  //                                            S=SYSTEM  SYSDSN   IBMUSER.PARMLIB
  //                                            SYSNAME        JOBNAME         ASID     TCBADDR   EXC/SHR    STATUS
  //                                            server    ZWESISTC           0045       006FED90   SHARE      OWN
  // ISF754I Command 'SET CONSOLE MYCONS' generated from associated variable ISFCONS.
  // ISF776I Processing started for action 1 of 1.
  // ISF769I System command issued, command text: D GRS,RES=(*,IBMUSER.PARMLIB).
  // ISF766I Request completed, status: COMMAND ISSUED.
  //
  // example output:
  //
  // server    2021040  22:31:07.32             ISF031I CONSOLE MYCONS ACTIVATED
  // server    2021040  22:31:07.32            -D GRS,RES=(*,IBMUSER.LOADLIB)
  // server    2021040  22:31:07.32             ISG343I 22.31.07 GRS STATUS 363
  //                                            NO REQUESTORS FOR RESOURCE  *        IBMUSER.LOADLIB
  // ISF754I Command 'SET CONSOLE MYCONS' generated from associated variable ISFCONS.
  // ISF776I Processing started for action 1 of 1.
  // ISF769I System command issued, command text: D GRS,RES=(*,IBMUSER.LOADLIB).
  // ISF766I Request completed, status: COMMAND ISSUED.
}

// Delete data set
//
// @param dsn     data set (or with member) name to delete
// @return        0: exist
//                1: data set doesn't exist
//                2: data set member doesn't exist
//                3: data set is in use
// @output        tso listds label output
export function deleteDataset(dataset: string): number {
  const cmd=`delete '${dataset}'`;
  const result=zoslib.tsoCommand(cmd);
  if (result.rc != 0) {
    if (result.out.includes('NOT IN CATALOG')) {
      return 1;
    } else if (result.out.includes('NOT FOUND')) {
      return 2;
    } else if (result.out.includes('IN USE BY')) {
      return 3;
    }
    // some other error we don't know yet
    return 9;
  }
  return 0;
}

export function isDatasetSmsManaged(dataset: string): { rc: number, smsManaged?: boolean } {
  // REF: https://www.ibm.com/docs/en/zos/2.3.0?topic=dscbs-how-found
  //      bit DS1SMSDS at offset 78(X'4E')
  //
  // Example of listds response:
  //
  // listds 'IBMUSER.LOADLIB' label
  // IBMUSER.LOADLIB
  // --RECFM-LRECL-BLKSIZE-DSORG
  //   U     **    6144    PO                                                                                          
  // --VOLUMES--
  //   VPMVSH
  // --FORMAT 1 DSCB--
  // F1 E5D7D4E5E2C8 0001 780034 000000 09 00 00 C9C2D4D6E2E5E2F24040404040
  // 78003708000000 0200 C0 00 1800 0000 00 0000 82 80000002 000000 0000 0000
  // 0100037D000A037E0004 01010018000C0018000D 0102006F000D006F000E 0000000217
  // --FORMAT 3 DSCB--
  // 03030303 0103009200090092000A 01040092000B0092000C 01050092000D0092000E
  // 0106035B0006035B0007 F3 0107035B0008035B0009 0108035B000A035B000B
  // 00000000000000000000 00000000000000000000 00000000000000000000
  // 00000000000000000000 00000000000000000000 00000000000000000000
  // 00000000000000000000 0000000000
  //
  // SMS flag is in `FORMAT 1 DSCB` section second line, after 780037

  common.printTrace(`- Check if ${dataset} is SMS managed`);
  const labelResult = zoslib.tsoCommand(`listds '${dataset}' label`);
  const datasetLabel=labelResult.out;
  if (labelResult.rc == 0) {
    let formatIndex = datasetLabel.indexOf('--FORMAT 1 DSCB--');
    let dscb_fmt1: string;
    if (formatIndex == -1) {
      formatIndex = datasetLabel.indexOf('--FORMAT 8 DSCB--');
    }
    if (formatIndex != -1) {
      let startIndex = formatIndex + '--FORMAT 8 DSCB--'.length;
      let endIndex = datasetLabel.indexOf('--',startIndex);
      dscb_fmt1 = datasetLabel.substring(startIndex, endIndex);
    }
    if (!dscb_fmt1) {
      common.printError("  * Failed to find format 1 data set control block information.");
      return { rc: 2 };
    } else {
      const lines = dscb_fmt1.split('\n');
      const line = lines.length > 1 ? lines[1] : '';
      const ds1smsfg = line.substring(6,8);
      common.printTrace(`  * DS1SMSFG: ${ds1smsfg}`);
      if (!ds1smsfg) {
        common.printError("  * Failed to find system managed storage indicators from format 1 data set control block.");
        return { rc: 3 };
      } else {
        const ds1smsds=parseInt(ds1smsfg, 16) & 0x80;
        common.printTrace(`  * DS1SMSDS: ${ds1smsds}`);
        if (ds1smsds == 128) {
          // sms managed
          return { rc: 0, smsManaged: true };
        } else {
          return { rc: 0, smsManaged: false };
        }
      }
    }
  } else {
    return { rc: 1 };
  }
}

export function getDatasetVolume(dataset: string): { rc: number, volume?: string } {
  common.printTrace(`- Find volume of data set ${dataset}`);
  const result = zoslib.tsoCommand(`listds '${dataset}'`);
  if (result.rc == 0) {
    const lines = result.out.split('\n');
    let volume;
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].trim() == '--VOLUMES--') {
        volume = lines[i+1] ? lines[i+1].trim() : undefined;
        break;
      }
    }
    if (!volume) {
      common.printError("  * Failed to find volume information of the data set.");
      return { rc: 2 }
    } else {
      return { rc: 0, volume: volume }
    }
  } else {
    return { rc: 1 }
  }
}

export function apfAuthorizeDataset(dataset: string): number {
  const result = isDatasetSmsManaged(dataset);
  if (result.rc) {
    common.printError("Error ZWEL0134E: Failed to find SMS status of data set ${dataset}.");
    return 134;
  }

  let apfVolumeParam:string;
  if (result.smsManaged) {
    common.printDebug(`- ${dataset} is SMS managed`);
    apfVolumeParam="SMS"
  } else {
    common.printDebug(`- ${dataset} is not SMS managed`);
    const volumeResult = getDatasetVolume(dataset);
    const dsVolume=volumeResult.volume;
    if (volumeResult.rc == 0) {
      common.printDebug(`- Volume of ${dataset} is ${dsVolume}`);
      apfVolumeParam=`VOLUME=${dsVolume}`;
    } else {
      common.printError(`Error ZWEL0135E: Failed to find volume of data set ${dataset}.`);
      return 135;
    }
  }

  const apfCmd=`SETPROG APF,ADD,DSNAME=${dataset},${apfVolumeParam}`;
  if (std.getenv('ZWE_CLI_PARAMETER_SECURITY_DRY_RUN') == "true") {
    common.printMessage("- Dry-run mode, security setup is NOT performed on the system.");
    common.printMessage("  Please apply this operator command manually:");
    common.printMessage('');
    common.printMessage(`  ${apfCmd}`);
    common.printMessage('');
  } else {
    const authResult = zoslib.operatorCommand(apfCmd);
    const apfAuthSuccess=authResult.out && authResult.out.includes('ADDED TO APF LIST');
    if (result.rc == 0 && apfAuthSuccess) {
      return 0;
    } else {
      common.printError(`Error ZWEL0136E: Failed to APF authorize data set ${dataset}.`);
      return 136;
    }
  }
  return 0;
}

export function createDatasetTmpMember(dataset: string, prefix: string='ZW'): string | null {
  common.printTrace(`  > create_data_set_tmp_member in ${dataset}`);
  for (var i = 0; i < 100; i++) {
    let rnd=Math.floor(Math.random()*10000);

    let member=`${prefix}${rnd}`.substring(0,8);
    common.printTrace(`    - test ${member}`);
    let memberExist=isDatasetExists(`${dataset}(${member})`);
    common.printTrace(`    - exist? ${memberExist}`);
    if (!memberExist) {
      common.printTrace("    - good");
      return member;
    }
  }
  return null;
}
