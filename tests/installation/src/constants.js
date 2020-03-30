/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2020
 */

const path = require('path');

// the FMID we will use to test PTF
const ZOWE_FMID = 'AZWE001';

// where ansible playbooks located
const ANSIBLE_ROOT_DIR = path.resolve(__dirname, '../../../playbooks');
// where install test located
const INSTALL_TEST_ROOT_DIR = path.resolve(__dirname, '../');
// where sanity test located
const SANITY_TEST_ROOT_DIR = path.resolve(__dirname, '../../sanity');

const TEST_REPORTS_DIR = 'reports';
// where install test located
const INSTALL_TEST_REPORTS_DIR = path.resolve(INSTALL_TEST_ROOT_DIR, TEST_REPORTS_DIR);
// where sanity test located
const SANITY_TEST_REPORTS_DIR = path.resolve(SANITY_TEST_ROOT_DIR, TEST_REPORTS_DIR);

// 90 minutes timeout for installation
const TEST_TIMEOUT_INSTALL_TEST = 90 * 60 * 1000;
// 30 minutes timeout for sanity test
const TEST_TIMEOUT_SANITY_TEST = 30 * 60 * 1000;

module.exports = {
  ZOWE_FMID,
  ANSIBLE_ROOT_DIR,
  INSTALL_TEST_ROOT_DIR,
  SANITY_TEST_ROOT_DIR,
  TEST_REPORTS_DIR,
  INSTALL_TEST_REPORTS_DIR,
  SANITY_TEST_REPORTS_DIR,
  TEST_TIMEOUT_INSTALL_TEST,
  TEST_TIMEOUT_SANITY_TEST,
};
