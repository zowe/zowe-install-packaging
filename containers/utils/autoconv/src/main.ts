/*
  This program and the accompanying materials are
  made available under the terms of the Eclipse Public License v2.0 which accompanies
  this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html

  SPDX-License-Identifier: EPL-2.0

  Copyright Contributors to the Zowe Project.
*/

import { exit } from 'process';
import fs from 'fs-extra';
import { convert } from './converter';
import path from 'path';

function help(): void {
  const prog = 'autoconv';
  console.log(`${prog} copies [input-dir] into [output-dir], detects files in IBM-1047 encoding, and converts them to ISO-8859-1 encoding.`);
  console.log(`Usage:`);
  console.log(`       ${prog} [input-dir] [output-dir]`);
}

async function main(): Promise<void> {
  if (process.argv.length !== 4) {
    help();
    exit(1);
  }
  const inputDir = process.argv[2];
  const outputDir = path.join(process.argv[3], path.basename(inputDir));
  try {
    console.log(`Copying files from ${inputDir} to ${outputDir}...`);
    await fs.copy(inputDir, outputDir);
    console.log(`Scanning files...`);
    await convert(outputDir);
    console.log(`Done.`);
  } catch (e) {
    console.error(e.message);
  }
}

main();


/*
  This program and the accompanying materials are
  made available under the terms of the Eclipse Public License v2.0 which accompanies
  this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html

  SPDX-License-Identifier: EPL-2.0

  Copyright Contributors to the Zowe Project.
*/
