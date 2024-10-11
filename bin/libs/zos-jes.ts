/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as os from 'cm_os';
import * as std from 'cm_std';
import * as zoslib from './zos';
import * as common from './common';
import * as stringlib from './string';
import * as shell from './shell';

export function submitJob(jclFileOrContent: string, printJobDebug:boolean=true, jclIsContent?:boolean): string|undefined {
  if (printJobDebug) {
    common.printDebug(`- submit job ${jclFileOrContent}`);

    common.printTrace(`- content of ${jclFileOrContent}`);
    if (!jclIsContent) {
      const catResult = shell.execOutSync('sh', '-c', `cat "${stringlib.escapeDollar(jclFileOrContent)}" 2>&1`);
      if (catResult.rc != 0) {
        common.printTrace(`  * Failed`);
        common.printTrace(`  * Exit code: ${catResult.rc}`);
        common.printTrace(`  * Output:`);
        common.printTrace(stringlib.paddingLeft(catResult.out, "    "));
        return undefined;
      }
      else {
        common.printTrace(stringlib.paddingLeft(catResult.out, "    "));
      }
    } else {
      common.printTrace(jclFileOrContent);
    }
  }

  // cat seems to work more reliably. sometimes, submit by itself just says it cannot find a real dataset.
  const result = shell.execOutSync('sh', '-c', jclIsContent ? `echo "${jclFileOrContent}" | submit 2>&1`
                                                            : `cat "${stringlib.escapeDollar(jclFileOrContent)}" | submit 2>&1`);
  // expected: JOB JOB????? submitted from path '...'
  const code=result.rc;
  if (code==0) {
    let jobidlines = result.out.split('\n').filter(line=>line.indexOf('submitted')!=-1);
    let jobid = jobidlines.length > 0 ? jobidlines[0].split(' ')[1] : undefined;
    if (!jobid) {
      jobidlines = result.out.split('\n').filter(line=>line.indexOf('$HASP')!=-1);
      jobid = jobidlines.length > 0 ? jobidlines[0].split(' ')[1] : undefined;
    }
    if (!jobid) {
      common.printDebug(`  * Failed to find job ID`);
      common.printError(`  * Exit code: ${code}`);
      common.printError(`  * Output:`);
      if (result.out) {
        common.printError(stringlib.paddingLeft(result.out, "    "));
      }
      return undefined;
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

    return undefined;
  }
}

export function waitForJob(jobid: string): {jobcctext?: string, jobcccode?: string, jobid?: string, jobname?: string, rc: number} {
  let jobstatus;
  let jobname;
  let jobcctext;
  let jobcccode;    
  let is_jes3;

  common.printDebug(`- Wait for job ${jobid} completed, starting at ${new Date().toString()}.`);
  // wait for job to finish
  const timesSec = [1, 5, 10, 20, 30, 60, 100, 300, 500];
  for (let i = 0; i < timesSec.length; i++) {
    jobcctext = undefined;
    jobcccode = undefined;
    jobname = undefined;
    is_jes3 = false;
    const secs = timesSec[i];
    common.printTrace(`  * Wait for ${secs} seconds`);
    os.sleep(secs*1000); 
    
    let result=zoslib.operatorCommand(`\\$D ${jobid},CC`);
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
        const hasplines = result.out.split('\n').filter(line => line.indexOf('$HASP890') != -1);
        if (hasplines && hasplines.length > 0) {
          const jobline = hasplines[0];
          const nameIndex = jobline.indexOf('JOB(');
          const ccIndex = jobline.indexOf('CC=(');
          jobname = jobline.substring(nameIndex+4, jobline.indexOf(')', nameIndex));
          const cc = jobline.substring(ccIndex+4, jobline.indexOf(')', ccIndex)).split(',');
          jobcctext = cc[0];
          if (cc.length > 1) {
            const equalSplit = cc[1].split('=');
            if (equalSplit.length > 1) {
              jobcccode = equalSplit[1];
            }
          }
          common.printTrace(`  * Job (${jobname}) status is ${jobcctext},RC=${jobcccode}`);
          if ((jobcctext && jobcctext.length > 0) || (jobcccode && jobcccode.length > 0)) {
            // job have CC state
            break;
          }
        }
      } catch (e) {
        break;
      }
    }
  }
  common.printTrace(`  * Job status check done at ${new Date().toString()}.`);

  if (jobcctext || jobcccode) {
    common.printDebug(`  * Job (${jobname}) exits with code ${jobcccode} (${jobcctext}).`);
    if (jobcccode == "0") {
      return {jobcctext, jobcccode, jobname, rc: 0};
    } else {
      // ${jobcccode} could be greater than 255
      return {jobcctext, jobcccode, jobname, rc: 2};
    }
  } else if (is_jes3) {
    common.printTrace(`  * Cannot determine job complete code. Please check job log manually.`);
    return {jobcctext, jobcccode, jobname, rc: 0};
  } else {
    common.printError(`  * Job (${jobname? jobname : jobid}) doesn't finish within max waiting period.`);
    return {jobcctext, jobcccode, jobname, rc: 1};
  }
}

export function printAndHandleJcl(jclLocationOrContent: string, jobName: string, jcllib: string, prefix: string, removeJclOnFinish?: boolean, continueOnFailure?: boolean, jclIsContent?: boolean){
  const jclContents = jclIsContent ? jclLocationOrContent : shell.execOutSync('sh', '-c', `cat "${stringlib.escapeDollar(jclLocationOrContent)}" 2>&1`).out;

  let jobHasFailures = false;
  if (jclIsContent) {
    removeJclOnFinish = false;
  }

  common.printMessage(`Template JCL: ${prefix}.SZWESAMP(${jobName}) , Executable JCL: ${jcllib}(${jobName})`);
  common.printMessage(`--- JCL Content ---`);
  common.printMessage(jclContents);
  common.printMessage(`--- End of JCL ---`);

  common.printTrace('  * zos-jes.printAndHanleJcl');
  common.printTrace('    * JCL Lines Length');
  const jclContentsSplit = jclContents.split("\n");
  for (let jclLine in jclContentsSplit) {
      const tracePad = 6;
      common.printTrace(`${jclContentsSplit[jclLine].length.toString().padStart(tracePad, ' ')}: ${jclContentsSplit[jclLine]}`);
      if (jclContentsSplit[jclLine].length > 71) {
          common.printTrace(`${' '.repeat(tracePad + 2)}${'^'.repeat(jclContentsSplit[jclLine].length)}`);
      }
  }
  common.printTrace('    * JCL Lines Length');

  let removeRc: number;

  let jobId: string|undefined;
  if (!std.getenv('ZWE_CLI_PARAMETER_DRY_RUN') && !std.getenv('ZWE_CLI_PARAMETER_SECURITY_DRY_RUN')) {
    common.printMessage(`Submitting Job ${jobName}`);
    jobId=submitJob(jclLocationOrContent, false, jclIsContent);
    if (!jobId) {
      jobHasFailures=true;
      if (continueOnFailure) {
        common.printError(`Warning ZWEL0161W: Failed to run JCL ${jcllib}(${jobName})`);
        jobId=undefined;
      } else {
        if (removeJclOnFinish) {
          removeRc = os.remove(jclLocationOrContent);
        }
          common.printErrorAndExit(`Error ZWEL0161E: Failed to run JCL ${jcllib}(${jobName}).`, undefined, 161);
      }
    }
    common.printDebug(`- job id ${jobId}`);

    let {jobcctext, jobcccode, jobname, rc} = waitForJob(jobId);
    if (rc) {
      jobHasFailures=true;
      if (continueOnFailure) {
        common.printError(`Warning ZWEL0162W: Failed to find job ${jobId} result.`);
      } else {
        if (removeJclOnFinish) {
          removeRc = os.remove(jclLocationOrContent);
        }
        common.printErrorAndExit(`Error ZWEL0162E: Failed to find job ${jobId} result.`, undefined, 162);
      }
    
      jobHasFailures=true
      if (continueOnFailure) {
        common.printError(`Warning ZWEL0163W: Job ${jobname}(${jobId}) ends with code ${jobcccode} (${jobcctext}).`);
      } else {
        if (removeJclOnFinish) {
          removeRc = os.remove(jclLocationOrContent);
        }
        common.printErrorAndExit(`Error ZWEL0163E: Job ${jobname}(${jobId}) ends with code ${jobcccode} (${jobcctext}).`, undefined, 163);
      }
    }
    if (removeJclOnFinish) {
      removeRc = os.remove(jclLocationOrContent);
    }
    if (jobHasFailures) {
      common.printLevel2Message(`Job ended with some failures. Please check job log for details.`);
    }
    return 0
  } else {
    common.printMessage(`JCL not submitted, command run with "--dry-run" flag.`);
    common.printMessage(`To perform command, re-run command without "--dry-run" flag, or submit the JCL directly`);
    common.printLevel2Message(`Command run successfully.`);
    if (removeJclOnFinish) {
      removeRc = os.remove(jclLocationOrContent);
    }
    return 0
  }
}
