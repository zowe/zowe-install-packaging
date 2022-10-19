/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'std';
import * as zoslib from './zos';
import * as common from './common';
import * as stringlib from './string';
import * as shell from './shell';
import * as config from './config';

export function submitJob(jclFile: string): string|undefined {
  common.printDebug(`- submit job ${jclFile}`);

  common.printTrace(`- content of ${jclFile}`);
  if (!fs.fileExists(jclFile)) {
    common.printTrace(`  * Failed`);
    common.printError(`  * File ${jclFile} does not exist`);
    return;
  } else {
    const contents = xplatform.loadFileUTF8(jclFile);
    common.printTrace(stringlib.paddingLeft(result, "    "));
  }

  const result=shell.execOutSync('sh', '-c', `submit "${jclFile}" 2>&1`);
  // expected: JOB JOB????? submitted from path '...'
  const code=result.rc;
  if (code==0) {
//    const jobid = result.out.split('\n').filter(line=>line.indexOf('submitted')!=-1);
//    jobid=$(echo "${result}" | grep submitted | awk '{print $2}')
    if (!jobid) {
      common.printDebug(`  * Failed to find job ID`);
      common.printError(`  * Exit code: ${code}`);
      common.printError(`  * Output:`);
      if (result.out) {
        common.printError(stringlib.paddingLeft(result.out, "    "));
      }
      return;
    } else {
      common.printDebug(`  * Succeeded with job ID ${jobid}`);
      common.printTrace(`  * Exit code: ${code}`);
      common.printTrace(`  * Output:`);
      if (result.out) {
        common.printTrace(stringlib.paddingLeft(result.out, "    "));
      }
      return jobid;
    }
  } else {
    common.printDebug(`  * Failed`);
    common.printError(`  * Exit code: ${code}`);
    common.printError(`  * Output:`);
    if (result.out) {
      common.printError(stringlib.paddingLeft(result.out, "    "));
    }

    return;
  }
}

export function waitForJob(jobid: string): {out?: string, rc: number} {
  let is_jes3;
  let jobstatus;
  let jobname;
  let jobcctext;
  let jobcccode;

  common.printDebug(`- Wait for job ${jobid} completed, starting at $(date).`);
  // wait for job to finish
  const timesSec = [1, 5, 10, 30, 100, 300, 500];
  for (let i = 0; i < timesSec.length; i++) {
    const secs = timesSec[i];
    common.printTrace(`  * Wait for ${secs} seconds`);
    os.sleep(secs*1000);
    
    let result=zoslib.operatorCommand(`\$D ${jobid},CC`);
    // if it's JES3, we receive this:
    // ...             ISF031I CONSOLE IBMUSER ACTIVATED
    // ...            -$D JOB00132,CC
    // ...  IBMUSER7   IEE305I $D       COMMAND INVALID
    is_jes3=result.out ? result.out.match(new RegExp('\$D \+COMMAND INVALID')) : false;
    if (is_jes3) {
      common.printDebug(`  * JES3 identified`);
      const show_jobid=jobid.substring(3);
      result=zoslib.operatorCommand(`*I J=${show_jobid}`);
      // $I J= gives ...
      // ...            -*I J=00132
      // ...  JES3       IAT8674 JOB BPXAS    (JOB00132) P=15 CL=A        OUTSERV(PENDING WTR)
      // ...  JES3       IAT8699 INQUIRY ON JOB STATUS COMPLETE,       1 JOB  DISPLAYED
      try {
        jobname=result.out.split('\n').filter(line=>line.indexOf('IAT8674') != -1)[0].replace(new RegExp('^.*IAT8674 *JOB *', 'g'), '').split(' ')[0];
      } catch (e) {

      }
      break;
    } else {
      // $DJ gives ...
      // ... $HASP890 JOB(JOB1)      CC=(COMPLETED,RC=0)  <-- accept this value
      // ... $HASP890 JOB(GIMUNZIP)  CC=()  <-- reject this value
      try {
        const joblines = result.out.split('\n').filter(line=>line.indexOf('$HASP890') != -1);
        jobstatus = shell.execOutSync('sh', '-c', 'sed "s#^.*\\$HASP890 *JOB(\\(.*\\)) *CC=(\\(.*\\)).*$#\\1,\\2#"').out;
        const portions = jobstatus.split(',');
        jobname=portions.length > 0 ? portions[0] : undefined;
        jobcctext=portions.length > 1 ? portions[1] : undefined;
        jobcccode=portions.length > 2 ? portions[2].split('=')[1] : undefined;
        common.printTrace(`  * Job (${jobname}) status is ${jobcctext},RC=${jobcccode}`);
        if (jobcctext || jobcccode) {
          // job have CC state
          break;
        }
      } catch (e) {
        break;
      }
    }
  }
  common.printTrace(`  * Job status check done at ${Date.now()}.`);

  const retVal=`${jobid},${jobname},${jobcctext},${jobcccode}`;
  if (jobcctext || jobcccode) {
    common.printDebug(`  * Job (${jobname}) exits with code ${jobcccode} (${jobcctext}).`);
    if (jobcccode == "0") {
      return {out: retVal, rc: 0};
    } else {
      // ${jobcccode} could be greater than 255
      return {out: retVal, rc: 2};
    }
  } else if (is_jes3) {
    common.printTrace(`  * Cannot determine job complete code. Please check job log manually.`);
    return {out: retVal, rc: 0};
  } else {
    common.printError(`  * Job (${jobname? jobname : jobid}) doesn't finish within max waiting period.`);
    return {out: retVal, rc: 1};
  }
}
