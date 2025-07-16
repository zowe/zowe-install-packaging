/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as xplatform from "xplatform";
import * as fs from './fs';
import * as os from 'cm_os';
import * as std from 'cm_std';
import * as zoslib from './zos';
import * as common from './common';
import * as stringlib from './string';
import * as shell from './shell';

export function submitJob(jclFileOrContent: string, printJobDebug: boolean = true, jclIsContent?: boolean): string | undefined {
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

  let cleanupFile = false;
  let jclFile: string = jclFileOrContent;

  if (jclIsContent) {
    // always submit through a file, as printf/echo can introduce errors to content
    jclFile = fs.createTmpFile()!;
    const storeRC = xplatform.storeFileUTF8(jclFile, xplatform.AUTO_DETECT, jclFileOrContent);
    if (storeRC) {
      common.printErrorAndExit(`Error ZWEL0159E Failed to modify temporary file ${jclFile}.`, undefined, 159);
    }
    cleanupFile = true;
  }

  // cat seems to work more reliably. sometimes, submit by itself just says it cannot find a real dataset.
  const result = shell.execOutSync('sh', '-c', `cat "${stringlib.escapeDollar(jclFile)}" | submit 2>&1`);
  // expected: JOB JOB????? submitted from path '...'
  const code = result.rc;

  if (cleanupFile) {
    os.remove(jclFile);
  }

  if (code == 0) {
    let jobidlines = result.out.split('\n').filter(line => line.indexOf('submitted') != -1);
    let jobid = jobidlines.length > 0 ? jobidlines[0].split(' ')[1] : undefined;
    if (!jobid) {
      jobidlines = result.out.split('\n').filter(line => line.indexOf('$HASP') != -1);
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

/**
 * Returns job name, completion code, and status. If we cannot retrieve the completion code, it is set to -1. 
 * Callers should check both cc and status, as cc can be -1 when the job is in OUTPUT state (job cancelled).
 * 
 * @param jobId 
 * @returns 
 */
function getJobStatus(jobId: string): { status: string, cc: string, name: string } {
  const getStatusCmd = std.getenv('ZWE_zowe_runtimeDirectory') + `/bin/utils/zowex job vs ${jobId}`;
  common.printDebug(`-- Running ${getStatusCmd}`);
  const result = shell.execOutSync('sh', '-c', `${getStatusCmd} 2>&1 && echo '.'`);
  let status = 'UNKNOWN';
  let compCode = '';
  let jobName = '';
  result.out?.split('\n').forEach((line) => {
    if (line.includes(jobId)) {
      /*     
      cout << job.jobid << " " << left << setw(10) << job.retcode << " " << job.jobname << " " << job.status << endl;

      Sample outputs (only one such line returned with `zowex job vs`)
      JOB05609 CANCELED   LONGJOB  OUTPUT
      JOB05602 CC 0000    SOMEJB OUTPUT
      TSU05611            USER1  ACTIVE
      JOB05486            IEFBR14$ INPUT
      */
      const columns = line.split(/\s+/).reverse();
      status = columns[0];
      jobName = columns[1];
      if (columns[2] !== jobId) {
        compCode = columns[2];
      }
    }
  })
  return { status: status, cc: compCode, name: jobName };

}

export function waitForJob(jobid: string): { jobcccode?: string, jobid?: string, jobname?: string, rc: number } {
  let jobstatus = '';
  let jobname = '';
  let jobcccode = '';

  common.printDebug(`- Wait for job ${jobid} completed, starting at ${new Date().toString()}.`);
  // wait for job to finish
  const timesSec = [1, 5, 10, 20, 30, 60, 100, 300, 500];
  for (let i = 0; i < timesSec.length; i++) {
    const secs = timesSec[i];
    common.printTrace(`  * Wait for ${secs} seconds`);
    os.sleep(secs * 1000);
    try {
      const jobStatus = getJobStatus(jobid);
      jobname = jobStatus.name;
      jobstatus = jobStatus.status;
      jobcccode = jobStatus.cc;
      common.printTrace(`  * Job (${jobname}) status is ${jobstatus},RC=${jobcccode}`);
      if (jobname.length === 0) {
        throw new Error(`Couldn't find job for job id ${jobid}`);
      }
      if (jobcccode.length > 0) {
        // job have CC state
        break;
      }

    } catch (e) {
      common.printTrace(`. * Error trying to get job status: ${e}`);
      break;
    }
  }
  common.printTrace(`  * Job status check done at ${new Date().toString()}.`);
  if (jobcccode) {
    common.printDebug(`  * Job (${jobname}) exits with code ${jobcccode}.`);
    if (Number(jobcccode) === 0) {
      return { jobcccode, jobname, rc: 0 };
    } else {
      // ${jobcccode} could be greater than 255 or text like "CANCELLED"
      return { jobcccode, jobname, rc: 2 };
    }
  } else {
    common.printError(`  * Job (${jobname.length > 0 ? jobname : jobid}) doesn't finish within max waiting period.`);
    return { jobcccode, jobname, rc: 1 };
  }
}

export function printAndHandleJcl(jclLocationOrContent: string, jobName: string, jcllib: string, prefix: string, removeJclOnFinish?: boolean, continueOnFailure?: boolean, jclIsContent?: boolean) {
  const jclContents = jclIsContent ? jclLocationOrContent : shell.execOutSync('sh', '-c', `cat "${stringlib.escapeDollar(jclLocationOrContent)}" 2>&1`).out;

  let jobHasFailures = false;
  if (jclIsContent) {
    removeJclOnFinish = false;
  }

  common.printMessage(`Template JCL: ${prefix}.SZWESAMP(${jobName}) , Executable JCL: ${jcllib}(${jobName})`);
  common.printMessage(`--- JCL Content ---`);
  common.printMessage(jclContents);
  common.printMessage(`--- End of JCL ---`);

  let removeRc: number;

  let jobId: string | undefined;
  if (!std.getenv('ZWE_CLI_PARAMETER_DRY_RUN') && !std.getenv('ZWE_CLI_PARAMETER_SECURITY_DRY_RUN')) {
    common.printMessage(`Submitting Job ${jobName}`);
    jobId = submitJob(jclLocationOrContent, false, jclIsContent);
    if (!jobId) {
      jobHasFailures = true;
      if (continueOnFailure) {
        common.printError(`Warning ZWEL0160W: Failed to run JCL ${jcllib}(${jobName})`);
        jobId = undefined;
      } else {
        if (removeJclOnFinish) {
          removeRc = os.remove(jclLocationOrContent);
        }
        common.printErrorAndExit(`Error ZWEL0161E: Failed to run JCL ${jcllib}(${jobName}).`, undefined, 161);
      }
    }
    common.printDebug(`- job id ${jobId}`);

    let { jobcccode, jobname, rc } = waitForJob(jobId);
    if (rc) {
      jobHasFailures = true;
      if (continueOnFailure) {
        common.printError(`Warning ZWEL0158W: Failed to find job ${jobId} result.`);
      } else {
        if (removeJclOnFinish) {
          removeRc = os.remove(jclLocationOrContent);
        }
        common.printErrorAndExit(`Error ZWEL0162E: Failed to find job ${jobId} result.`, undefined, 162);
      }

      jobHasFailures = true
      if (continueOnFailure) {
        common.printError(`Warning ZWEL0164W: Job ${jobname}(${jobId}) ends with code ${jobcccode}.`);
      } else {
        if (removeJclOnFinish) {
          removeRc = os.remove(jclLocationOrContent);
        }
        common.printErrorAndExit(`Error ZWEL0163E: Job ${jobname}(${jobId}) ends with code ${jobcccode}.`, undefined, 163);
      }
    }
    if (removeJclOnFinish) {
      removeRc = os.remove(jclLocationOrContent);
    }
    if (jobHasFailures) {
      common.printLevel2Message(`Job ended with some failures. Please check job log for details.`);
    } else {
      common.printMessage(`Job ${jobname}(${jobId}) completed with RC=${rc}`)
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
