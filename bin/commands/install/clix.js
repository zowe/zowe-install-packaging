/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as index from './index';
import * as std from 'cm_std';
import * as common from '../../libs/common';
import * as zosdataset from '../../libs/zos-dataset';

const prefix = std.getenv("ZWE_CLI_PARAMETER_DATASET_PREFIX");
if (!prefix || !zosdataset.validDatasetName(prefix)){
  common.printLevel1Message("Install Zowe MVS data sets");
  common.printErrorAndExit(`Error ZWEL0102E: Invalid parameter --dataset-prefix="${prefix}".`, undefined, 102);
}

index.execute(prefix);
