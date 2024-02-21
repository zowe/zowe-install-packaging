
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
  const result = shell.execErrSync('sh', '-c', `cat "//'${datasetName}'" 1>/dev/null 2>&1`);
  return !(result.err && result.err.includes('EDC5049I'));
  // EDC5049I = file not found
}

export function isDatasetExists(datasetName: string): boolean {
  const result = shell.execSync('sh', '-c', `cat "//'${datasetName}'" 1>/dev/null 2>&1`);
  return result.rc === 0;
}

// Check if data set exists using TSO command (listds)
// @return        0: exist
//                1: data set is not in catalog
//                2: data set member doesn't exist
export function tsoIsDatasetExists(datasetName: string): number {
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

export function copyToDataset(filePath: string, dsName: string, cpOptions: string, allowOverwrite: boolean): number {
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

export function getDatasetVolume(dataset: string): { rc: number, volume?: string } {
  common.printTrace(`- Find volume of data set ${dataset}`);
  const result = zoslib.tsoCommand(`listds '${dataset}'`);
  if (result.rc == 0) {
    let volumesIndex = result.out.indexOf('--VOLUMES--');
    let volume: string;
    if (volumesIndex != -1) {
      let startIndex = volumesIndex + '--VOLUMES--'.length;
      let endIndex = result.out.indexOf('--',startIndex);
      volume = result.out.substring(startIndex, endIndex).trim();
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
