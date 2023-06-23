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
//import * as zos from 'zos';

import * as common from './common';
import * as stringlib from './string';
import * as shell from './shell';

// Get file encoding from z/OS USS tagging
export function getFileEncoding(filePath: string): number|undefined {
  //zos.changeTag(file, id)
  let returnArray = os.stat(filePath);
  if (!returnArray[1] && ((returnArray[0].mode & os.S_IFREG) == os.S_IFREG)) { //no error, and is file
    return returnArray[0].ccsid;
  } else {
    common.printError(`getFileEncoding path=${filePath}, err=${returnArray[1]}`);
  }
  return undefined;
}

// TODO logic rewritten, needs more testing
// Detect and verify file encoding
//
// This function will try to verify file encoding by reading sample string.
//
// Note: Return depends on the cases, the output is
//       confirmed encoding to stdout.
//       - file is already tagged: the output will be the encoding tag,
//       - file is not tagged:
//         - expected encoding is auto: the output will be one of IBM-1047, 
//                 ISO8859-1, IBM-850 based on the guess. Output is -1 if none
//                 of those encodings are correct.
//         - expected encoding is not auto: the output will be same as expected
//                 encoding if it's correct. otherwise output will be -1.
//
// Example:
// - detect manifest encoding by checking result "name"
//   detectFileEncoding "/path/to/zowe/components/my-component/manifest.yaml" "name"
export function detectFileEncoding(fileName: string, expectedSample: string, expectedEncoding?: number|string): number {
  let autoEncoding = expectedEncoding == 'auto' || expectedEncoding == 'AUTO';
  let expectedEncodingNumber= typeof expectedEncoding == 'string' ? stringlib.ENCODING_NAME_TO_CCSID[expectedEncoding.toUpperCase()] : expectedEncoding;

  let currentTag = getFileEncoding(fileName);
  if (currentTag) {
    return currentTag;
  } else {
    //loadfile does not convert untagged ebcdic
    let fileContents = std.loadFile(fileName);
    if (fileContents) {
      if ((!expectedEncoding ||
           expectedEncodingNumber == 1047 ||
           autoEncoding) && !fileContents.includes(expectedSample)) {
        return 1047;
      } else if (expectedEncodingNumber) {
        let execReturn = shell.execOutSync('sh', '-c', `iconv -f "${expectedEncodingNumber}" -t 1047 "${fileName}" | grep "${expectedSample}"`);
        if (execReturn.rc == 0 && execReturn.out) {
          return expectedEncodingNumber;
        }
      } else {
        //Common encodings, 8859-1 and ascii 850
        const commonEncodings = [819, 850];
        for (let i = 0; i < commonEncodings.length; i++) {
          const encoding = commonEncodings[i];
          let execReturn = shell.execOutSync('sh', '-c', `iconv -f "${encoding}" -t 1047 "${fileName}" | grep "${expectedSample}"`);
          if (execReturn.rc == 0 && execReturn.out) {
            return encoding;
          }
        }
      }
    }
  }
  return -1;
}

export function copyMvsToUss(dataset: string, file: string): number {
  common.printDebug(`copyMvsToUss dataset=${dataset}, file=${file}`);
  const result = shell.execSync('sh', '-c', `cp "//'${dataset}'" "${file}"`);
  return result.rc;
}

// On z/OS, some file generated could be in ISO8859-1 encoding, but we need it to be IBM-1047
export function ensureFileEncoding(file: string, expectedSample: string, expectedEncoding?: number) {
  if (os.platform != 'zos') {
    return;
  }
  if (!expectedEncoding) {
    expectedEncoding=1047;
  }

  let fileEncoding=detectFileEncoding(file, expectedSample);
  if (fileEncoding) {
    // TODO  any cases we cannot find encoding?
    if (fileEncoding != expectedEncoding) {
      common.printTrace(`- Convert encoding of ${file} from ${fileEncoding} to ${expectedEncoding}.`);
      let shellReturn = shell.execSync('sh', '-c', `iconv -f "${fileEncoding}" -t "${expectedEncoding}" "${file}" > "${file}.tmp"`);
      if (!shellReturn.rc) {
        os.rename(`${file}.tmp`, file);
      }
    }
    common.printTrace(`- Remove encoding tag of ${file}.`);
    //zos.changeTag(file, 0);
    shell.execSync('sh', '-c', `chtag -r ${file}`);
  } else {
    common.printTrace(`- Failed to detect encoding of ${file}.`);
  }
}
