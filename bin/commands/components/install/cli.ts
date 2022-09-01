/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as index from './index';
import * as std from 'std';
import * as os from 'os';

declare namespace console {
  function log(...args:string[]): void;
};


if (!std.getenv('ZWE_PRIVATE_TMP_MERGED_YAML_DIR')) {
  std.setenv('ZWE_PRIVATE_TMP_MERGED_YAML_DIR', '1');
}

index.execute(std.getenv('ZWE_CLI_PARAMETER_COMPONENT_FILE'), std.getenv('ZWE_CLI_PARAMETER_AUTO_ENCODING'), (std.getenv('ZWE_CLI_PARAMETER_SKIP_ENABLE') === 'true'));

const tmpDir = std.getenv('ZWE_PRIVATE_TMP_MERGED_YAML_DIR');
if (!std.getenv('PATH')) {
  std.setenv('PATH','/bin:.:/usr/bin');
}
const rc = os.exec(['rm', '-rf', tmpDir],
                       {block: true, usePath: true});
if (rc == 0) {
  console.log(`Temporary directory ${tmpDir} removed successfully.`);
} else {
  console.log(`Error: Temporary directory ${tmpDir} was not removed successfully, manual cleanup is needed. rc=${rc}`);
}
