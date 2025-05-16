/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as xplatform from 'xplatform';
import * as index from './index';
import * as fs from '../../libs/fs';
import * as configmgr from '../../libs/configmgr';

export function execute() {
  let prefix = std.getenv('ZWE_CLI_PARAMETER_DATASET_PREFIX');
  let tmpConfig: string|undefined = undefined;

  if (prefix && prefix.length>0 && !std.getenv('ZWE_CLI_PARAMETER_CONFIG')) {
    tmpConfig = fs.createTmpFile();
    let contents = [
      'zowe:',
      '  setup:',
      '    dataset:',
      '      prefix: '+prefix
    ].join('\n');
    xplatform.storeFileUTF8(tmpConfig, xplatform.AUTO_DETECT, contents);
    std.setenv('ZWE_CLI_PARAMETER_CONFIG', tmpConfig);
  }
  index.execute();
  if (tmpConfig) {
    fs.rmrf(tmpConfig);
  }
  configmgr.cleanupTempDir();
}
