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
const prefix = zoweConfig.zowe?.setup?.dataset?.prefix;
if (!prefix){
  common.printLevel1Message("Install Zowe MVS data sets");
  common.printErrorAndExit(`Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file.`, undefined, 157); 
}

index.execute(prefix);
configmgr.cleanupTempDir();
