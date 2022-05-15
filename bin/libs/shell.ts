/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

// @ts-ignore
import * as std from 'std';
// @ts-ignore
import * as os from 'os';

import * as fs from './fs';
import * as stringlib from './string';

const BUFFER_SIZE=4096;

export type ExecReturn = {
  rc: number,
  out?: string,
  err?: string
};

export type path = string;

export function execSync(command: string, ...args: string[]): ExecReturn {
  const rc = os.exec([command, ...args],
                     {block: true, usePath: true});
  return {
    rc
  };
}

export function execOutSync(command: string, ...args: string[]): ExecReturn {
    let pipeArray = os.pipe();
    const rc = os.exec([command, ...args], { block: true, usePath: true, stdout: pipeArray[1]});  //stdout: handler });

    let buff = new Uint8Array(BUFFER_SIZE);
    os.open(pipeArray[0]);
    let bytesRead = os.read(pipeArray[0], buff.buffer, 0, BUFFER_SIZE);
    let out = '';
    while (bytesRead == BUFFER_SIZE) {
      out+=String.fromCharCode.apply(null, buff);
      buff.fill(0, 0, bytesRead);
      bytesRead = os.read(pipeArray[0], buff.buffer, 0, BUFFER_SIZE);
    }
    if (bytesRead>0) {
      out+=String.fromCharCode.apply(null, buff.slice(0,bytesRead-1));
    }
    os.close(pipeArray[0]);
    os.close(pipeArray[1]);
    if (os.platform == 'zos') {
      out=stringlib.ebcdicToAscii(out);
    }
    return {
        rc, out
    };
}

export function execOutErrSync(command: string, ...args: string[]): ExecReturn {
  let pipeArray = os.pipe();
    let errArray = os.pipe();
    const rc = os.exec([command, ...args], { block: true, usePath: true, stdout: pipeArray[1], stderr: errArray[1]});

    let buff = new Uint8Array(BUFFER_SIZE);
    os.open(pipeArray[0]);
    let bytesRead = os.read(pipeArray[0], buff.buffer, 0, BUFFER_SIZE);
    let out = '';
    while (bytesRead == BUFFER_SIZE) {
      out+=String.fromCharCode.apply(null, buff);
      buff.fill(0, 0, bytesRead);
      bytesRead = os.read(pipeArray[0], buff.buffer, 0, BUFFER_SIZE);
    }
    if (bytesRead>0) {
      out+=String.fromCharCode.apply(null, buff.slice(0,bytesRead-1));
    }
    os.close(pipeArray[0]);
    os.close(pipeArray[1]);
    if (os.platform == 'zos') {
      out=stringlib.ebcdicToAscii(out);
    }


    let errBuff = new Uint8Array(BUFFER_SIZE);
    os.open(errArray[0]);
    bytesRead = os.read(errArray[0], errBuff.buffer, 0, BUFFER_SIZE);
    let err = '';
    while (bytesRead == BUFFER_SIZE) {
      err+=String.fromCharCode.apply(null, errBuff);
      errBuff.fill(0, 0, bytesRead);
      bytesRead = os.read(errArray[0], errBuff.buffer, 0, BUFFER_SIZE);
    }
    if (bytesRead>0) {
      err+=String.fromCharCode.apply(null, errBuff.slice(0,bytesRead-1));
    }
    os.close(errArray[0]);
    os.close(errArray[1]);
    if (os.platform == 'zos') {
      err=stringlib.ebcdicToAscii(err);
    }
    return {
        rc, out, err
    };
}


export function which(command: string): path|undefined {
  //TODO not windows
  let pathParts = std.getenv('PATH').split(':');
  for (let i = 0; i < pathParts; i++) {
    let files = fs.getFilesInDirectory(pathParts[i]);
    if (files.indexOf(command) != -1) {
      return `${pathParts[i]}/command`;
    }
  }
  return undefined;
}
