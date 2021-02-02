/*
  This program and the accompanying materials are
  made available under the terms of the Eclipse Public License v2.0 which accompanies
  this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html

  SPDX-License-Identifier: EPL-2.0

  Copyright Contributors to the Zowe Project.
*/

import fs from 'fs-extra';
import { join } from 'path';
import { IBM1047_to_ISO8859_1 } from './charmap';

let debugCharError = false;
let debugLimit = 10;
let debug = false;
let badCharLimit = 100;

interface ScanResult {
  encoding: Encoding;
  data: Buffer;
}

enum CharClass {
  Unprintable = 0,
  CarriageControl = 1,
  AsciiPrintable = 2,
  NonAsciiPrintable = 3,
}

export async function convert(path: string): Promise<void> {
  const stats = await fs.stat(path);
  if (stats.isDirectory()) {
    const files = await fs.readdir(path);
    for (const file of files) {
      if (['.git'].indexOf(file) !== -1) {
        continue;
      }
      const filePath = join(path, file);
      await convert(filePath);
    }
  } else {
    await convertFileIfNeeded(path);
  }
}

async function convertFileIfNeeded(file: string): Promise<void> {
  const { encoding: type, data } = await detectEncoding(file);
  if (type === 'IBM-1047') {
    await convertFile(file, data);
    console.log(`File ${file} converted to ISO-8859-1`);
  }
}

type Encoding = 'ERROR' | 'EMPTY' | 'BOTH' | 'ISO8859-1' | 'IBM-1047' | 'NEITHER';

async function detectEncoding(filename: string): Promise<ScanResult> {
  let debugCount = 0;
  let showedFilename = false;
  const data = await fs.readFile(filename);
  const iso8859Counts = [0, 0, 0, 0];
  const ibm1047Counts = [0, 0, 0, 0];
  for (let pos = 0; pos < data.length; pos++) {
    const ch = data[pos];
    const iso8859Class = classify(ch);
    iso8859Counts[iso8859Class]++;
    if (debugCharError && iso8859Class == 0 && iso8859Counts[iso8859Class] < 10 && debugCount++ < debugLimit) {
      if (!showedFilename) {
        console.log('%s', filename);
        showedFilename = true;
      }
      console.log('ISO8859-1 char error at position=%d, char=0x%s', pos, ch.toString(16));
    }
    const convertedCh = IBM1047_to_ISO8859_1[ch];
    const ibm1047Class = classify(convertedCh);
    ibm1047Counts[ibm1047Class]++;
    if (debugCharError && ibm1047Class == 0 && ibm1047Counts[ibm1047Class] < 10 && debugCount++ < debugLimit) {
      if (!showedFilename) {
        console.log('%s', filename);
        showedFilename = true;
      }
      console.log('IBM-1047 char error at position=%d, char=0x%s', pos, ch.toString(16));
    }
  }
  if (debug) {
    showCounts(iso8859Counts, 'ISO-8859-1');
    showCounts(ibm1047Counts, 'IBM-1047');
  }
  if (0 == (iso8859Counts[CharClass.Unprintable] + iso8859Counts[CharClass.CarriageControl] + iso8859Counts[CharClass.AsciiPrintable] + iso8859Counts[CharClass.NonAsciiPrintable])) {
    return { encoding: 'EMPTY', data };
  } else if (iso8859Counts[CharClass.Unprintable] <= badCharLimit && ibm1047Counts[CharClass.Unprintable] <= badCharLimit) {
    if ((iso8859Counts[CharClass.Unprintable] == 0 && iso8859Counts[CharClass.NonAsciiPrintable] == 0) && !((ibm1047Counts[CharClass.Unprintable] == 0 && ibm1047Counts[CharClass.NonAsciiPrintable] == 0))) {
      return { encoding: 'ISO8859-1', data };
    } else if (!(iso8859Counts[CharClass.Unprintable] == 0 && iso8859Counts[CharClass.NonAsciiPrintable] == 0) && ((ibm1047Counts[CharClass.Unprintable] == 0 && ibm1047Counts[CharClass.NonAsciiPrintable] == 0))) {
      return { encoding: 'IBM-1047', data };
    } else if (iso8859Counts[CharClass.NonAsciiPrintable] <= badCharLimit && ibm1047Counts[CharClass.NonAsciiPrintable] <= badCharLimit) {
      return { encoding: 'BOTH', data };
    } else if (iso8859Counts[CharClass.NonAsciiPrintable] <= badCharLimit) {
      return { encoding: 'ISO8859-1', data };
    } else if (ibm1047Counts[CharClass.NonAsciiPrintable] <= badCharLimit) {
      return { encoding: 'IBM-1047', data };
    } else {
      return { encoding: 'BOTH', data };
    }
  } else if (iso8859Counts[CharClass.Unprintable] <= badCharLimit) {
    return { encoding: 'ISO8859-1', data };
  } else if (ibm1047Counts[CharClass.Unprintable] <= badCharLimit) {
    return { encoding: 'IBM-1047', data };
  } else {
    return { encoding: 'NEITHER', data };
  }
}

/* 0x0009, 0x000A, 0x000B, 0x000C, 0x000D, 0x0085: common cc characters */
/* 0x0000-0x001F: unprintable */
/* 0x0020-0x007F: ASCII printable */
/* 0x00A0: unprintable */
/* 0x00A1-0x00FF: non-ASCII printable */
function classify(ch: number): CharClass {
  if (ch == 0x09 || ch == 0x0A || ch == 0x0B || ch == 0x0C || ch == 0x0D || ch == 20 || ch == 0x85) {
    return CharClass.CarriageControl;
  }
  if (ch <= 0x1F || ch == 0xA0) {
    return CharClass.Unprintable;
  }
  if (ch <= 0x7F) {
    return CharClass.AsciiPrintable;
  }
  return CharClass.NonAsciiPrintable;
}

function showCounts(counts: number[], encoding: string): void {
  console.log('  %s: bad=%d whitespace=%d english=%d international=%d', encoding,
    counts[CharClass.Unprintable], counts[CharClass.CarriageControl],
    counts[CharClass.AsciiPrintable], counts[CharClass.NonAsciiPrintable]
  );
}

async function convertFile(path: string, data: Buffer): Promise<void> {
  convertData(data);
  fs.writeFile(path, data);
}

function convertData(data: Buffer): void {
  for (let pos = 0; pos < data.length; pos++) {
    const ch = data[pos];
    let converted = IBM1047_to_ISO8859_1[ch];
    data[pos] = converted;
  }
}


/*
  This program and the accompanying materials are
  made available under the terms of the Eclipse Public License v2.0 which accompanies
  this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html

  SPDX-License-Identifier: EPL-2.0

  Copyright Contributors to the Zowe Project.
*/
