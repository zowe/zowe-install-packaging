/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as index from './index';
import * as common from '../../libs/common';
import * as config from '../../libs/config';
import * as configmgr from '../../libs/configmgr';

common.requireZoweYaml();
const zoweConfig = config.getZoweConfig();

const install = {
  prefix: zoweConfig.zowe?.setup?.dataset?.prefix,
  yaml: true,
  runtime: zoweConfig.zowe?.runtimeDirectory,
  jclHeader: zoweConfig.zowe.environments?.jclHeader
}

index.execute(install);
configmgr.cleanupTempDir();
