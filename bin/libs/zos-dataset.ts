
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

//TODO a bit of a hack. "cat" cant output a vsam, so it will always give errors.
//     however, the errors it gives are different depending on if the vsam exists or not.
export function isVsamDatasetExists(datasetName: string): boolean {
  common.printTrace(`  * isVsamDatasetExists: '${stringlib.escapeDollar(datasetName)}'`);
  const result = shell.execErrSync('sh', '-c', `cat "//'${stringlib.escapeDollar(datasetName)}'" 1>/dev/null`);
  return !(result.err && result.err.includes('EDC5049I'));
  // EDC5049I = file not found
}

export function isDatasetExists(datasetName: string): boolean {
  common.printTrace(`  * isDatasetExists: '${stringlib.escapeDollar(datasetName)}'`);
  const result = shell.execSync('sh', '-c', `cat "//'${stringlib.escapeDollar(datasetName)}'" 2>&1`);
  return result.rc === 0;
}

// Check if data set exists using TSO command (listds)
// @return        0: exist
//                1: data set is not in catalog
//                2: data set member doesn't exist
export function tsoIsDatasetExists(datasetName: string): number {
  common.printTrace(`  * tsoIsDatasetExists: '${stringlib.escapeDollar(datasetName)}'`);
  const result = zoslib.tsoCommand(`listds '${stringlib.escapeDollar(datasetName)}' label`);
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
  common.printTrace(`  * createDataSet: '${stringlib.escapeDollar(dsName)}' ${dsOptions}`);
  const result=zoslib.tsoCommand(`ALLOCATE NEW DA('${stringlib.escapeDollar(dsName)}') ${dsOptions}`);
  return result.rc;
}

export function copyToDataset(filePath: string, dsName: string, cpOptions: string, allowOverwrite: boolean): number {
  if (allowOverwrite != true) {
    if (isDatasetExists(dsName)) {
      common.printErrorAndExit(`Error ZWEL0133E: Data set ${dsName} already exists`, undefined, 133);
    }
  }

  const cpCommand=`cp ${cpOptions} -v "${filePath}" "//'${stringlib.escapeDollar(dsName)}'"`;
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

export function getDatasetVolume(dataset: string): { rc: number, volume?: string } {
  common.printTrace(`- Find volume of data set ${stringlib.escapeDollar(dataset)}`);
  const result = zoslib.tsoCommand(`listds '${stringlib.escapeDollar(dataset)}'`);
  if (result.rc == 0) {
    let volumesIndex = result.out.indexOf('--VOLUMES--');
    let volume: string;
    if (volumesIndex != -1) {
      let startIndex = volumesIndex + '--VOLUMES--'.length;
      volume = result.out.substring(startIndex).trim();
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
  // The first flag 'F1' is DS1FMTID at offset 44(X'2C')
  //
  // Notes:
  //   The first section is --FORMAT 1 DSCB-- xor --FORMAT 8 DSCB--
  //   The section --FORMAT 3 DSCB-- is optional
  //

  common.printTrace(`- Check if ${dataset} is SMS managed`);
  const labelResult = zoslib.tsoCommand(`listds '${stringlib.escapeDollar(dataset)}' label`);
  const datasetLabel=labelResult.out;
  if (labelResult.rc == 0) {
    let formatIndex = datasetLabel.indexOf("--FORMAT 1 DSCB--\n");
    let dscb_fmt1: string;
    if (formatIndex == -1) {
      formatIndex = datasetLabel.indexOf("--FORMAT 8 DSCB--\n");
    }
    if (formatIndex != -1) {
      let startIndex = formatIndex + "--FORMAT 8 DSCB--\n".length;
      let endIndex = datasetLabel.indexOf('--',startIndex);
      if (endIndex != -1) {
        dscb_fmt1 = datasetLabel.substring(startIndex, endIndex);
      } else {
        dscb_fmt1 = datasetLabel.substring(startIndex);
      }
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
