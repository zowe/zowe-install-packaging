/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as common from './common';

export function jqget(obj: any, path: string): any {
  try {
    let parts = path.split('.');
    let index = 0;
    while (obj && (index < parts.length)) {
      let part = parts[index];
      if (part.length==0) { index++; continue; }
      if (part.endsWith(']')) {
        let start = part.indexOf('[');
        if (start != -1) {
          let firstPart = part.substring(0, start);
          let arrayIndex = part.substring(start+1, part.length-1);
          obj = obj[firstPart];
          if (obj) {
            if (arrayIndex==='') {
              //multi-mode
              let multiResponse = [];
              let remainingParts = parts.slice(index+1).join('.');
              if (Array.isArray(obj)) {
                obj.forEach((innerObj:any) => {
                  multiResponse.push(jqget(innerObj, remainingParts));
                });
                return multiResponse;
              } else {
                const keys = Object.keys(obj);
                keys.forEach((key:string) => {
                  multiResponse.push(jqget(obj[key], remainingParts));
                });
              }
              return multiResponse;
              //returns rather than continues due to exhausting remaining parts.
            } else {
              obj = obj[arrayIndex];
            }
          }
        } else {
          obj = obj[part];
        }
      } else {
        obj = obj[part];
      }
      index++;
    }
    return obj;
  } catch (e) {
    common.printError('JQ-like processing error='+e);
    return undefined;
  }
}

export function jqset(obj: any, path: string, value: any): [ boolean, any ] {
  let parts = path.split('.');
  let index = 0;
  while (obj && (index < parts.length-1)) {
    let part = parts[index];
    if (part.length==0) { index++; continue; }
    if (part.endsWith(']')) {
      let start = part.indexOf('[');
      if (start != -1) {
        let firstPart = part.substring(0, start);
        let arrayIndex = part.substring(start+1, part.length-1);
        obj = obj.firstPart;
        if (obj) {
          obj = obj[arrayIndex];
        }
      } else {
        obj = obj[part];
      }
    } else {
      obj = obj[part];
    }
    index++;
  }
  if (obj) {
    let part = parts[parts.length-1];
    if (part.endsWith(']')) {
      let start = part.indexOf('[');
      if (start != -1) {
        let firstPart = part.substring(0, start);
        let arrayIndex = part.substring(start+1, part.length-1);
        obj = obj.firstPart;
        if (obj) {
          obj[arrayIndex] = value;
          return [true, obj];
        }
      } else {
        obj[part] = value;
        return [true,obj];
      }
    } else {
      obj[part] = value;
      return [true,obj];
    }
  }
  return [false,obj];
}
