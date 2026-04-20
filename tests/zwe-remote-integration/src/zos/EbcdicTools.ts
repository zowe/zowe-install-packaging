/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import EBCDIC from 'ebcdic-ascii';
import * as fs from 'fs-extra';
import * as path from 'path';

export function convertDirToEbcdicInPlace(dir: string) {
  const dirContents = fs.readdirSync(dir, { recursive: true });
  const converter = new EBCDIC('1047');
  for (const entry of dirContents) {
    const filePath = path.resolve(dir, entry.toString());
    const file = fs.lstatSync(filePath);
    if (file.isFile()) {
      const asHex = fs.readFileSync(filePath).toString('hex');
      const asciiChars = converter.splitHex(asHex).map((a) => a.toUpperCase());
      const asEbcdic = asciiChars
        .map((code: string) => {
          // Replace line feeds with new line, ignore carriage returns.
          // Both ascii characters ignored by converter out of the box.
          if (code === '0A') { // Line feed
            return '15';
          } else if (code === '0D') { // Carriage return
            return '';
          } else {
            return converter.charToEBCDIC(code);
          }
        })
        .join('');
      fs.writeFileSync(filePath, Buffer.from(asEbcdic, 'hex'));
    }
  }
}
