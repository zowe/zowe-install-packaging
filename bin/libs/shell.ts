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
import * as fs from './fs';

export type ExecReturn = {
  rc: number,
  out?: string,
  err?: string
};

export type path = string;

export function execSync(command: string, args: string): ExecReturn {
  const rc = os.exec([command, args],
                     {block: true, usePath: true});
  return {
    rc
  };
}


export function execOutSync(command: string, args: string): ExecReturn {
  let out;
  let handler = (data:string)=> {
    out=data;
  }
  const rc = os.exec([command, args],
                     {block: true, usePath: true, out: handler});
  return {
    rc, out
  };
}

export function execOutErrSync(command: string, args: string): ExecReturn {
  let out;
  let handler = (data:string)=> {
    out=data;
  }
  let err;
  let errHandler = (data:string)=> {
    err=data;
  }
  const rc = os.exec([command, args],
                     {block: true, usePath: true, out: handler, err: errHandler});
  return {
    rc, out, err
  };
}


export function which(command: string): path|undefined {
  //TODO not windows
  let pathParts = std.getenv('PATH').split(':');
  for (let i = 0; i < pathParts; i++) {
    let files = fs.getFilesInDirectory(pathParts[i]);
    if (files.includes(command)) {
      return `${pathParts[i]}/command`;
    }
  }
}
