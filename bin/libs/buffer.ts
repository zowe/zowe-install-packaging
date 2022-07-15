/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as xplatform from 'xplatform';


const hexDigits = [ "0", "1", "2", "3",
                    "4", "5", "6", "7",
                    "8", "9", "A", "B",
                    "C", "D", "E", "F" ];

export class ExpandableBuffer {
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
