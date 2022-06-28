/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/


export function jqget(obj: any, path: string): any {
  let parts = path.split('.');
  let index = parts[0] == '' && parts.length > 1 ? 1 : 0;
  while (obj && (index < parts.length)) {
    let part = parts[index];
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
  return obj;
}

export function jqset(obj: any, path: string, value: any): boolean {
  let parts = path.split('.');
  let index = parts[0] == '' && parts.length > 1 ? 1 : 0;
  while (obj && (index < parts.length-1)) {
    let part = parts[index];
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
          return true;
        }
      } else {
        obj[part] = value;
        return true;
      }
    } else {
      obj[part] = value;
      return true;
    }
  }
  return false;
}
