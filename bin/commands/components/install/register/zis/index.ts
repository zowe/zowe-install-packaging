/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as common from '../../../../../libs/common';
import * as stringlib from '../../../../../libs/string';
import * as shell from '../../../../../libs/shell';
import * as config from '../../../../../libs/config';
import * as component from '../../../../../libs/component';
import * as varlib from '../../../../../libs/var';
import { PathAPI as pathoid } from '../../../../../libs/pathoid';

export function execute(componentName: string, zisPluginDatasets?: string[], dryRun?: boolean) {
  component.processZisPluginInstall(componentDir, false, dryRun);
  /*
    zisPluginInstall()
      copyZisPluginToAuthloadlib
        or
      addZisLoadLibToStcJcl
        then
      zisParmlibRegister
        editZisParmlibContents
          updateUssParmlibKeyValue
   */
}
