/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html

  SPDX-License-Identifier: EPL-2.0

  Copyright Contributors to the Zowe Project.
*/

import * as xplatform from 'xplatform';

import * as common from '../../libs/common';
import * as fs from '../../libs/fs';

export function execute(zoweRuntimeDirectory: string): void {

  if (!zoweRuntimeDirectory) {
    common.printErrorAndExit("Error ZWEL0106E: zowe.runtimeDirectory parameter is required.", undefined, 106);
  }
  const manifestPath = `${zoweRuntimeDirectory}/manifest.json`;
  if (!fs.fileExists(manifestPath, true)) {
    common.printErrorAndExit("Error ZWEL0150E: Failed to find Zowe manifest.json. Zowe runtimeDirectory is invalid.", undefined, 150);
  }
  const contents = xplatform.loadFileUTF8(manifestPath, xplatform.AUTO_DETECT);
  let manifest;
  try {
    manifest = JSON.parse(contents);
  } catch (e) {
    // encoding issue etc.
    common.printErrorAndExit(`Error ZWEL0327E: Failed to read JSON file ${manifestPath} - ${e}`, undefined, 327);
  }
  
  if (!manifest.version) {
    common.printErrorAndExit(`Error ZWEL0327E: Failed to read JSON file ${manifestPath} - "version" not defined.`, undefined, 327);
  }
  common.printMessage("Zowe v" + manifest.version);

  if (!manifest.build?.branch || !manifest.build?.number || !manifest.build?.commitHash) {
    common.printErrorAndExit(`Error ZWEL0327E: Failed to read JSON file ${manifestPath} - "build" section not defined or incomplete.`, undefined, 327);
  }
  common.printDebug(`build and hash: ${manifest.build.branch}#${manifest.build.number} (${manifest.build.commitHash})`);
  
  common.printTrace(`Zowe directory: ${zoweRuntimeDirectory}`);

}
