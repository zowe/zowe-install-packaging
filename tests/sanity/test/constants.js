/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018, 2019
 */

// default Zowe JES job name
const ZOWE_JOB_NAME = (process.env.ZOWE_JOB_PREFIX || 'ZWE') + '1SV';
const ZOWE_XMEM_JOB_NAME = 'ZWESISTC';

module.exports = {
  ZOWE_JOB_NAME,
  ZOWE_XMEM_JOB_NAME,
};
