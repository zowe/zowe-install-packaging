/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as os from 'cm_os';

import * as common from './common';
import * as shell from './shell';
import * as stringlib from './string';

std.setenv('ZWE_RUN_ON_ZOS', ""+(os.platform == 'zos'));
const pwd = os.getcwd();
std.setenv('ZWE_PWD', pwd[0] ? pwd[0] : '/');

// Return system name in lower case
let sysname:string;
export function getSysname(): string|undefined {
  if (typeof sysname == 'string') {
    return sysname.toLowerCase();
  }
  let shellReturn = shell.execOutSync('sysvar', 'SYSNAME');
  if (!shellReturn.out) {
    // works for z/OS and most Linux with hostname command
    shellReturn = shell.execOutSync('hostname', '-s');
  }
  if (!shellReturn.out) {
    shellReturn = shell.execOutSync('uname', '-n');
  }
  if (shellReturn.out) {
    sysname = shellReturn.out.toLowerCase();
    return sysname;
  }
  return undefined;
}

export function getUserId(): string|undefined {
  //moved to simplify dependency
  return common.getUserId();
}

export function requireZos(): void {
  if (os.platform != 'zos') {
    common.printErrorAndExit("Error ZWEL0120E: This command must run on a z/OS system.", undefined, 120);
  }
}

// List direct children PIDs of a process
export function findDirectChildProcesses(parent: number, tree?: string[]): number[] {
  let pids:number[] = [];
  
  if (!tree) {
    let shellReturn = shell.execOutSync('ps', '-o', `pid,ppid,comm`, '-A');
    if (shellReturn.out) {
      tree=shellReturn.out.split('\n').slice(2);
    }
  }
  if (tree) {
    tree.forEach((line: string)=> {
      let parts = line.split(' ');
      let pid = parts[0];
      let ppid = parts[1];
      let comm = parts[2];
      if (ppid == parent+'' && comm != 'ps' && comm != '/bin/ps') {
        pids.push(Number(pid));
      }
    });
  }
  return pids;
}

// List all children PIDs of a process
export function findAllChildProcesses(parent: number, tree?: string[]): number[] {
  let pids:number[] = [];
  
  if (!tree) {
    let shellReturn = shell.execOutSync('ps', '-o', `pid,ppid,comm`, '-A');
    if (shellReturn.out) {
      tree=shellReturn.out.split('\n').slice(2);
    }
  }
  if (tree) {
    let children = findDirectChildProcesses(parent, tree);
    children.forEach((child:number)=> {
      pids.push(child);
      pids.concat(findAllChildProcesses(child, tree));
    });
  }
  return pids;
}

// Wait until a single process exits
export function waitForProcessExit(pid: number): boolean {
  common.printFormattedDebug("ZWELS", "sys-utils.ts,waitForProcessExit", `waiting for process ${pid} to exit`);

  let iteratorIndex=0;
  const maxIteratorIndex=30;

  let shellReturn=shell.execOutSync('ps', `-p`, `${pid}`, `-o`, `pid`);
  while (shellReturn.rc == 0) { //0 when there are processes in the list
    os.sleep(1000);
    iteratorIndex++;
    if (iteratorIndex > maxIteratorIndex) {
      break;
    }
    shellReturn=shell.execOutSync('ps', `-p`, `${pid}`, `-o`, `pid`);
  }
  
  if (shellReturn.rc == 0) {
    common.printFormattedDebug("ZWELS", "sys.ts,wait_for_process_exit:", `process ${pid} does NOT exit before timeout`);
    return false;
  } else {
    common.printFormattedDebug("ZWELS", "sys.ts,wait_for_process_exit:", `process ${pid} no longer exists`);
    return true;
  }
}

export function gracefullyShutdown(pid?: number): boolean {
  if (pid === undefined || pid < 1) {
    let pidString = std.getenv("ZWE_GRACEFULLY_SHUTDOWN_PID");
    if (pidString){
      pid = parseInt(pidString);      
    }
    if ((pid===undefined || pid < 1) && os.platform == 'linux') {
      //container case
      pid = 1;
    } else {
      //dont try to shut down pid 1, its unlikely a container
      return false;
    }
  }
  if (pid >= 1) {
    let children = findAllChildProcesses(pid);
    common.printFormattedDebug("ZWELS", "sys.ts,gracefully_shutdown", "SIGTERM signal received, shutting down process ${pid} and all child processes");

    // send SIGTERM to all children
    os.kill(pid, 15);
    children.forEach((pid:number)=>{
      waitForProcessExit(pid);
    });
    common.printFormattedDebug("ZWELS", "sys.ts,gracefully_shutdown", "all child processes exited");
    return true;
  }
  return false;
}

export function executeCommand(...args:string[]) {
  common.printDebug(`- ${args}`);
  let out;
  let handler = (data:string)=> {
    out=data;
  }
  let err;
  let errHandler = (data:string)=> {
    err=data;
  }
  if (!std.getenv('PATH')) {
    std.setenv('PATH','/bin:.:/usr/bin');
  }

  const rc = os.exec(args,
                     {block: true, usePath: true, out: handler, err: errHandler});
  if (!rc) {
    common.printDebug(`  * Succeeded`);
    common.printTrace(`  * Exit code: ${rc}`);
    common.printTrace(`  * Output:`);
    if (out) {
      common.printTrace(stringlib.paddingLeft(out,'    '));
    }
  } else {
    common.printDebug(`  * Failed`);
    common.printError(`  * Exit code: ${rc}`);
    common.printError(`  * Output:`);
    if (err) {
      common.printError(stringlib.paddingLeft(err,'    '));
    }
  }
  return {
    rc, out, err
  };
}
