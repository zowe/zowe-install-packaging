/*
// This program and the accompanying materials are made available
// under the terms of the Eclipse Public License v2.0 which
// accompanies this distribution, and is available at
// https://www.eclipse.org/legal/epl-v20.html
//
// SPDX-License-Identifier: EPL-2.0
//
// Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as os from 'cm_os';

import * as common from './common';
import * as shell from './shell';
import * as fs from './fs';
import * as stringlib from './string';
//if on zos
import * as zosfs from './zos-fs';

// get ping command, could be empty
export function getPing(): string|undefined {
  let ping = shell.which('ping');

  // z/OS
  if (!ping) {
    ping = shell.which('oping');
  }
  return ping;
}

// get netstat command, could be empty
export function getNetstat(): string|undefined {
  let netstat = shell.which('netstat');
  
  // z/OS
  if (!netstat) {
    netstat = shell.which('onetstat');
  }
  return netstat;
}

// should not be bound to a port currently
export function isPortAvailable(port: number): boolean {
  const netstat=getNetstat();

  const skipValidate = (std.getenv('ZWE_zowe_network_validatePortFree') ? std.getenv('ZWE_zowe_network_validatePortFree') : std.getenv('ZWE_zowe_environments_ZWE_NETWORK_VALIDATE_PORT_FREE')) == 'false';
  if (skipValidate) {
    common.printMessage("Port validation skipped due to zowe.network.validatePortFree=false");
    return true;
  }
  
  if (!netstat) {
    common.printError("No netstat tool found.")
    return false;
  }

  // QUESTION: should we ignore netstat command stderr?
  let retVal;
  let lines;
  switch (os.platform) {
    case 'zos':
    const vipaIp = std.getenv('ZWE_zowe_network_vipaIp') ? std.getenv('ZWE_zowe_network_vipaIp') : std.getenv('ZWE_zowe_environments_ZWE_NETWORK_VIPA_IP');
    if (vipaIp !== undefined) {
      retVal=shell.execOutSync('sh', '-c', `${netstat} -B ${std.getenv('ZWE_zowe_network_vipaIp')}+${port} -c SERVER 2>&1`);
    } else {
      retVal=shell.execOutSync('sh', '-c', `${netstat} -c SERVER -P ${port} 2>&1`);
    }
    if (retVal.rc != 0) {
      common.printError(`Netstat test fail with exit code ${retVal.rc} (${retVal.out})`);
      return false;
    }
    if ((retVal.out as string).includes('Listen')) { 
      common.printError(`Port ${port} is already in use by process (${retVal.out})`);
      return false;
    }
    break;
    case "darwin":
    retVal=shell.execOutErrSync(netstat, `-an`, `-p`, `tcp`);
    if (retVal.rc != 0) {
      common.printError(`Netstat test fail with exit code ${retVal.rc} (${retVal.err})`);
      return false
    }
    lines = (retVal.out as string).split('\n');
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      if (line.includes('LISTEN') && line.includes(''+port)) {
        common.printError(`Port ${port} is already in use by process (${retVal.out})`);
        return false;
      }
    }
    break;
    default: 
    // linux-ish
    retVal=shell.execOutErrSync(netstat, `-nlt`);
    if (retVal.rc != 0) {
      common.printError(`Netstat test fail with exit code ${retVal.rc} (${retVal.err})`);
      return false;
    }
    lines = (retVal.out as string).split('\n');
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      if (line.includes('LISTEN') && line.includes(''+port)) {
        common.printError(`Port ${port} is already in use by process (${retVal.out})`);
        return false;
      }
    }
  }
  return true;
}

// get current IP address
const ipv4Regexp = /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/;
export function getIpAddress(hostname: string): string|undefined {
  let ip;

  // dig is preferred than ping
  const digResult=shell.execOutErrSync('sh', `dig`, `-4`, `+short`, hostname, `||`, `dig`, `+short`, hostname);
  if (digResult.out) {
    const digLines = digResult.out.split('\n');
    for (let i = 0; i < digLines.length; i++) {
      let matchResult = digLines[0].match(ipv4Regexp); // Type error was here
      if (matchResult){
        ip = matchResult[0];  
        break;
      }
    }
  }

  // try ping
  if (!ip) {
    let ping=getPing();
    const timeout=2
    if (ping) {
      // try to get IPv4 address only
      // - Mac: ipv4-only not supported
      let pingResult;
      if (os.platform == 'zos') {
        pingResult=shell.execOutErrSync('sh', ping, `-c`, `1`, `-A`, `ipv4`, `-t`, ""+timeout, hostname);
      } else if (os.platform == 'darwin') {
        pingResult=shell.execOutErrSync('sh', ping, `-c`, `1`, `-t`, ""+timeout, hostname);
      } else { //linux
        pingResult=shell.execOutErrSync('sh', ping, `-c`, `1`, `-4`, `-W`, ""+timeout, hostname);
      }
      if (pingResult.rc==0) {
        let pingOut:string = pingResult.out as string;
        let index = pingOut.indexOf('(');
        if (index != -1) {
          let index2 = pingOut.indexOf(')',index);
          if (index2 != -1) {
            ip=pingOut.substring(index+1,index2);
          }
        }
      }
    }
  }

  // we don't have dig and ping, let's check /etc/hosts
  if (!ip && fs.fileExists('/etc/hosts')) {
    //    const hosts = std.loadFile('/etc/hosts');
    let hosts = std.loadFile('/etc/hosts');
    if (hosts) {
      if (os.platform=='zos') {
        let encoding = zosfs.detectFileEncoding('/etc/hosts',hostname,1047);
        if (encoding==1047) {
          hosts = stringlib.ebcdicToAscii(hosts);
        }
      }
      const lines = hosts.split('\n');
      for (let i = 0; i < lines.length; i++) {
        let cols = lines[i].split(' ');
        if (cols.includes(hostname)) {
          return cols[0];
        }
      }
    }
  }

  return ip;
}
