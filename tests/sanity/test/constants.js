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
const ZOWE_JOB_NAME = (process.env.ZOWE_JOB_PREFIX || 'ZWE') + (process.env.ZOWE_INSTANCE_ID || '1') + 'SV';
const ZOWE_XMEM_JOB_NAME = 'ZWESISTC';

const APIML_AUTH_COOKIE = 'apimlAuthenticationToken';
const ZOSMF_TOKEN = 'LtpaToken2';
const DEFAULT_HTTP_REQUEST_TIMEOUT = 120000;

const DEFAULT_CLIENT_CERTIFICATE = '../../playbooks/roles/custom_for_test/files/USER-cert.cer';
const DEFAULT_CLIENT_CERTIFICATE_PRIVATE_KEY = '../../playbooks/roles/custom_for_test/files/USER-PRIVATEKEY.key';


module.exports = {
  ZOWE_JOB_NAME,
  ZOWE_XMEM_JOB_NAME,
  APIML_AUTH_COOKIE,
  ZOSMF_TOKEN,
  DEFAULT_HTTP_REQUEST_TIMEOUT,
  DEFAULT_CLIENT_CERTIFICATE,
  DEFAULT_CLIENT_CERTIFICATE_PRIVATE_KEY,
};
