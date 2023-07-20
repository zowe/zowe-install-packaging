/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2020
 */

import * as path from 'path';
// import Debug from 'debug';
// const debug = Debug('zowe-install-test:constants');

// the FMID we will use to test PTF
export const ZOWE_FMID = 'AZWE002';

// where ansible playbooks located
export const ANSIBLE_ROOT_DIR: string = path.resolve(__dirname, '../../../playbooks');
// where install test located
export const INSTALL_TEST_ROOT_DIR: string = path.resolve(__dirname, '../');
// where sanity test located
export const SANITY_TEST_ROOT_DIR: string = path.resolve(__dirname, '../../sanity');

export const TEST_REPORTS_DIR = 'reports';
// where install test located
export const INSTALL_TEST_REPORTS_DIR: string = path.resolve(INSTALL_TEST_ROOT_DIR, TEST_REPORTS_DIR);
// where sanity test located
export const SANITY_TEST_REPORTS_DIR: string = path.resolve(SANITY_TEST_ROOT_DIR, TEST_REPORTS_DIR);

// 90 minutes timeout for install conv. build
export const TEST_TIMEOUT_CONVENIENCE_BUILD: number = 90 * 60 * 1000;

// 90 minutes timeout for installation fmid
export const TEST_TIMEOUT_SMPE_FMID: number = 90 * 60 * 1000;
// 120 minutes timeout for installation ptf
export const TEST_TIMEOUT_SMPE_PTF: number = 120 * 60 * 1000;

export const KEYSTORE_MODE_KEYSTORE = 'KEYSTORE_MODE_KEYSTORE';
export const KEYSTORE_MODE_KEYRING = 'KEYSTORE_MODE_KEYRING';

export const APIML_OIDC_VARS =  {
  'zowe_apiml_security_oidc_client_id': process.env['OKTA_CLIENT_ID'] || 'dummy_id_from_constants_ts',
  'zowe_apiml_security_oidc_client_secret': process.env['OKTA_CLIENT_SECRET'] || 'dummy_secret_from_constants_ts',
  'zowe_apiml_security_oidc_registry': process.env['OIDC_REGISTRY'] || 'dummy_registry_from_constants_ts',
  'zowe_apiml_security_oidc_introspect_url': `https://${process.env['OKTA_HOSTNAME']}/oauth2/default/v1/introspect`,
};

// debug(`process.env >>>>>>>>>>>>>>>>>>>>>>>>>>\n${JSON.stringify(process.env)}\n<<<<<<<<<<<<<<<<<<<<<<<`);
