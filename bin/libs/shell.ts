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
import * as xplatform from 'xplatform';

import * as fs from './fs';
import * as stringlib from './string';

declare namespace console {
  function log(...args:string[]): void;
};


const BUFFER_SIZE=4096;

export type ExecReturn = {
  rc: number,
  out?: string,
  err?: string
};

export type path = string;

const hexDigits = [ "0", "1", "2", "3",
                    "4", "5", "6", "7",
                    "8", "9", "A", "B",
                    "C", "D", "E", "F" ];

class ExpandableBuffer {
  size:number;
  buffer:ArrayBuffer;
  bytes:Uint8Array;
  pos:number;
  
  constructor(size:number){
    this.size = size;
    this.buffer = new ArrayBuffer(size);
    this.bytes = new Uint8Array(this.buffer);
    this.pos = 0;
  }

  append(data:Uint8Array, offset:number, length:number):void {
    if (this.pos+length > this.size){
      let newSize = this.size * 2;
      let newBuffer = new ArrayBuffer(newSize);
      let newBytes = new Uint8Array(newBuffer);
      newBytes.set(this.bytes,0);
      this.bytes = newBytes;
      this.buffer = newBuffer;
      this.size = newSize;
    }
    this.bytes.set(data.slice(offset,length), this.pos);
    this.pos += length;
  }

  dump(lim:number):string {
    let chunks = [];
    for (let i=0; i<lim; i++){
      let b = this.bytes[i];
      let h = (b >> 4)&0xf;
      let l = b&0xf;
      chunks.push(hexDigits[h]+hexDigits[l]+"");
      if ((i % 4) == 3){ chunks.push(" "); }
      if ((i % 16) == 15){ chunks.push("\n"); }
    }
    return chunks.join("");
  }

  getString():string{
    return xplatform.stringFromBytes(this.buffer, 0, this.pos, xplatform.AUTO_DETECT);
  }
}


export function execSync(command: string, ...args: string[]): ExecReturn {
  const rc = os.exec([command, ...args],
                     {block: true, usePath: true});
  return {
    rc
  };
}

function readStreamFully(fd:number):string{
  let readBuffer = new Uint8Array(BUFFER_SIZE);
  let fileBuffer = new ExpandableBuffer(BUFFER_SIZE);
  
  let bytesRead = 0;
  do {
    bytesRead = os.read(fd, readBuffer.buffer, 0, BUFFER_SIZE);
    fileBuffer.append(readBuffer,0,bytesRead);
  } while (bytesRead == BUFFER_SIZE);
  // let hex = fileBuffer.dump(fileBuffer.pos);
  // console.log("out "+hex);
  let result = fileBuffer.getString();
  if (result.endsWith('\n')) {
    return result.substring(0,result.length-1);
  } else {
    return result;
  }
}

export function execOutSync(command: string, ...args: string[]): ExecReturn {
  let pipeArray = os.pipe();
  if (!pipeArray){
    return { rc: -1 };
  }
  const rc = os.exec([command, ...args], { block: true, usePath: true, stdout: pipeArray[1]});
  
  let out = readStreamFully(pipeArray[0]);
  os.close(pipeArray[0]);
  os.close(pipeArray[1]);

  return {
    rc, out
  };
}

export function exec(command: string, ...args: string[]): ExecReturn {
  os.exec([command, ...args], { block: false, usePath: true, stdout: pipeArray[1]});
}


export function execErrSync(command: string, ...args: string[]): ExecReturn {
  let pipeArray = os.pipe();
  if (!pipeArray){
    return { rc: -1 };
  }
  const rc = os.exec([command, ...args], { block: true, usePath: true, stderr: pipeArray[1]});
  
  let err = readStreamFully(pipeArray[0]);
  os.close(pipeArray[0]);
  os.close(pipeArray[1]);

  return {
    rc, err
  };
}


export function execOutErrSync(command: string, ...args: string[]): ExecReturn {
  let pipeArray = os.pipe();
  if (!pipeArray){
    return { rc: -1 };
  }
  let errArray = os.pipe();
  if (!errArray){
    return { rc: -1 };
  }
  const rc = os.exec([command, ...args], { block: true, usePath: true, stdout: pipeArray[1], stderr: errArray[1]});

  let out = readStreamFully(pipeArray[0]);
  os.close(pipeArray[0]);
  os.close(pipeArray[1]);

  let err = readStreamFully(errArray[0]);
  os.close(errArray[0]);
  os.close(errArray[1]);
  return {
    rc, err
  };
}

export function which(command: string): path|undefined {
  //TODO not windows
  let pathParts = (std.getenv('PATH') || "").split(':');
  for (let i = 0; i < pathParts.length; i++) {
    let files:string[] = fs.getFilesInDirectory(pathParts[i]) || [];
    if (files.indexOf(command) != -1) {
      return `${pathParts[i]}/${command}`;
    }
  }
  return undefined;
}
