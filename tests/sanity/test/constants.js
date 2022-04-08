/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

// default Zowe JES job name
const ZOWE_JOB_NAME = (process.env.ZOWE_JOB_PREFIX || 'ZWE') + (process.env.ZOWE_INSTANCE_ID || '1') + 'SV';
const ZOWE_XMEM_JOB_NAME = 'ZWESISTC';

const APIML_AUTH_COOKIE = 'apimlAuthenticationToken';
const ZOSMF_TOKEN = 'LtpaToken2';
const DEFAULT_HTTP_REQUEST_TIMEOUT = 60000;

const DEFAULT_CLIENT_CERTIFICATE = '../../playbooks/roles/custom_for_test/files/USER-cert.cer';
const DEFAULT_CLIENT_CERTIFICATE_PRIVATE_KEY = '../../playbooks/roles/custom_for_test/files/USER-PRIVATEKEY.key';

const EXPLORER_API_TEST_DATASET_PATTERN = 'SYS1.LINKLIB*';
const EXPLORER_API_TEST_DATASET_NAME = 'SYS1.LINKLIB';
const EXPLORER_API_TEST_DATASET_MEMBER_NAME = 'ACCOUNT';

module.exports = {
  ZOWE_JOB_NAME,
  ZOWE_XMEM_JOB_NAME,
  APIML_AUTH_COOKIE,
  ZOSMF_TOKEN,
  DEFAULT_HTTP_REQUEST_TIMEOUT,
  DEFAULT_CLIENT_CERTIFICATE,
  DEFAULT_CLIENT_CERTIFICATE_PRIVATE_KEY,
  EXPLORER_API_TEST_DATASET_PATTERN,
  EXPLORER_API_TEST_DATASET_NAME,
  EXPLORER_API_TEST_DATASET_MEMBER_NAME,
};
