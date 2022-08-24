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
import * as zos from 'zos';

import * as common from './common';
import * as stringlib from './string';
import * as shell from './shell';

export isDatasetExists(datasetName: string): boolean {
  const result = shell.execSync('sh', '-c', `cat "//'${datasetName}'" 1>/dev/null 2>&1)`);
  return result.rc === 0;
}

// Check if data set exists using TSO command (listds)
// @return        0: exist
//                1: data set is not in catalog
//                2: data set member doesn't exist
export function tsoIsDatasetExists(datasetName: string): number {
  const result = zoslib.tsoCommand(`listds '${datasetName}' label`);
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
    if (isDatasetExists(`//'${dsName}'`)) {
      common.printErrorAndExit(`Error ZWEL0133E: Data set ${dsName} already exists`, undefined, 133);
    }
  }

  const cpCommand=`- cp ${cpOptions} -v ${filePath} //'${dsName}'"`;
  common.printDebug(cpCommand);
  const result=shell.execOutSync('sh', '-c', `cp ${cpOptions} -v "${filePath}" "//'${dsName}'" 2>&1`);
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
    if (isDatasetExists(`//'${datasetTo}'`)) {
      common.printErrorAndExit(`Error ZWEL0133E: Data set ${datasetTo} already exists`, undefined, 133);
    }
  }

  const cmd=`exec '${prefix}.${std.getenv('ZWE_PRIVATE_DS_SZWEEXEC')}(ZWEMCOPY)' '${datasetFrom} ${datasetTo}'`;
  const result = zoslib.tsoCommand(cmd);
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

// List users of a data set
//
// @param dsn     data set name to check
// @return        0: no users
//                1: there are some users
// @output        output of operator command "d grs"
export function listDatasetUser(datasetName: string): string {
  const cmd=`D GRS,RES=(*,${datasetName})`;
  const result=zoslib.operatorCommand(cmd);
  common.printTrace(`  * Exit code: ${result.rc}`);
  common.printTrace("  * Output:");
  common.printTrace(stringlib.paddingLeft(result.out, "    "));

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

  if (result.out.includes('NO REQUESTORS FOR RESOURCE')) {
    return 0
  }

  return 1
}

// Delete data set
//
// @param dsn     data set (or with member) name to delete
// @return        0: exist
//                1: data set doesn't exist
//                2: data set member doesn't exist
//                3: data set is in use
// @output        tso listds label output
export function deleteDataset(dataset: string) {
  const cmd=`delete '${dataset}'`;
  const result=zoslib.tsoCommand(cmd);
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

    if (result.out.includes('NOT IN CATALOG')) {
      return 1;
    }
    if (result.out.includes('NOT FOUND')) {
      return 2;
    }
    if (result.out.includes('IN USE BY')) {
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
  if (result.rc == 0) {
    dscb_fmt1=$(echo "${datasetLabel}" | sed -e '1,/--FORMAT [18] DSCB--/ d' | sed -e '1,/--/!d' | sed -e '/--.*/ d')
    if (!dscb_fmt1) {
      common.printError("  * Failed to find format 1 data set control block information.");
      return 2;
    } else {
      ds1smsfg=$(echo "${dscb_fmt1}" | head -n 2 | tail -n 1 | sed -e 's#^.\{6\}\(.\{2\}\).*#\1#')
      common.printTrace(`  * DS1SMSFG: ${ds1smsfg}");
      if (!ds1smsfg) {
        common.printError("  * Failed to find system managed storage indicators from format 1 data set control block.");
        return { rc: 3 };
      } else {
        ds1smsds=$((0x${ds1smsfg} & 0x80))
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
  common.printTrace("- Find volume of data set ${dataset}"
  ds_info=$(tso_command listds "'${dataset}'")
  code=$?
  if (result.rc == 0) {
    volume=$(echo "${ds_info}" | sed -e '1,/--VOLUMES--/ d' | sed -e '1,/--/!d' | sed -e '/--.*/ d' | tr -d '[:space:]')
    if (!volume) {
      common.printError("  * Failed to find volume information of the data set."
      return 2
    } else {
      echo "${volume}"
      return 0
    }
  } else {
    return 1
  }
}

apf_authorize_data_set() {
  dataset="${1}"

  ds_sms_managed=$(is_data_set_sms_managed "${dataset}")
  code=$?
  if (result.rc) {
    common.printError("Error ZWEL0134E: Failed to find SMS status of data set ${dataset}."
    return 134
  }

  apf_vol_param=
  if ("${ds_sms_managed}" = "true") {
    common.printDebug("- ${dataset} is SMS managed"
    apf_vol_param="SMS"
  } else {
    common.printDebug("- ${dataset} is not SMS managed"
    ds_volume=$(get_data_set_volume "${dataset}")
    code=$?
    if (result.rc == 0) {
      common.printDebug("- Volume of ${dataset} is ${ds_volume}"
      apf_vol_param="VOLUME=${ds_volume}"
    } else {
      common.printError("Error ZWEL0135E: Failed to find volume of data set ${dataset}."
      return 135
    }
  }

  apf_cmd="SETPROG APF,ADD,DSNAME=${dataset},${apf_vol_param}"
  if ("${ZWE_CLI_PARAMETER_SECURITY_DRY_RUN}" = "true") {
    common.printMessage("- Dry-run mode, security setup is NOT performed on the system."
    common.printMessage("  Please apply this operator command manually:"
    common.printMessage('');
    common.printMessage("  ${apf_cmd}"
    common.printMessage('');
  } else {
    apf_auth=$(operator_command "${apf_cmd}")
    code=$?
    apf_auth_succeed=$(echo "${apf_auth}" | grep "ADDED TO APF LIST")
    if (result.rc == 0 && apf_auth_succeed) {
      return 0
    } else {
      common.printError("Error ZWEL0136E: Failed to APF authorize data set ${dataset}."
      return 136
    }
  }
}

create_data_set_tmp_member() {
  dataset=${1}
  prefix=${2:-ZW}

  common.printTrace("  > create_data_set_tmp_member in ${dataset}"
  last_rnd=
  idx_retry=0
  max_retry=100
  while true ; do
    if (${idx_retry} -gt ${max_retry}) {
      common.printError("    - Error ZWEL0114E: Reached max retries on allocating random number."
      exit 114
      break
    }

    rnd=$(echo "${RANDOM}")
    if ("${rnd}" = "${last_rnd) {
      // reset random
      RANDOM=$(date '+1%H%M%S')
    }

    member=$(echo "${prefix}${rnd}" | cut -c1-8)
    common.printTrace("    - test ${member}"
    member_exist=$(is_data_set_exists "${dataset}(${member})")
    common.printTrace("    - exist? ${member_exist}"
    if ("${member_exist}" != "true") {
      common.printTrace("    - good"
      echo "${member}"
      break
    }

    last_rnd="${rnd}"
    idx_retry=`expr $idx_retry + 1`
  done
}
