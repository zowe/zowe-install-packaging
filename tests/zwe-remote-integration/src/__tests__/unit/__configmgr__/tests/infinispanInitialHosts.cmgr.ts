/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import * as config from '@bin/libs/config';
import { _unit_test } from '@bin/libs/configmgr';
import { assertEqualsStrict } from './common/assert';
import * as common from '@bin/libs/common';
import * as std from 'cm_std';

const ZOWE_CONFIG = config.getZoweConfig();
common.printMessage('Starting "getInfinispanInitialHosts" test cases.');

let rc = 0;

// Test 1: Non-HA (no haInstances) -> returns null
common.printMessage('Test 1: Non-HA (no haInstances) -> returns null');
{
  const saved = ZOWE_CONFIG.haInstances;
  ZOWE_CONFIG.haInstances = undefined;
  const result = _unit_test.getInfinispanInitialHosts(ZOWE_CONFIG);
  rc += assertEqualsStrict(result, null);
  ZOWE_CONFIG.haInstances = saved;
}

// Test 2: HA with 2 instances -> correct hostname[port],hostname[port] list
common.printMessage('Test 2: HA with 2 instances -> correct list');
{
  ZOWE_CONFIG.haInstances = {
    instance1: { hostname: 'host1.example.com' },
    instance2: { hostname: 'host2.example.com' }
  };
  const result = _unit_test.getInfinispanInitialHosts(ZOWE_CONFIG);
  rc += assertEqualsStrict(result, 'host1.example.com[7600],host2.example.com[7600]');
}

// Test 3: Custom port is respected
common.printMessage('Test 3: Custom port is respected');
{
  if (!ZOWE_CONFIG.components) ZOWE_CONFIG.components = {};
  if (!ZOWE_CONFIG.components['caching-service']) ZOWE_CONFIG.components['caching-service'] = {};
  if (!ZOWE_CONFIG.components['caching-service'].storage) ZOWE_CONFIG.components['caching-service'].storage = {};
  if (!ZOWE_CONFIG.components['caching-service'].storage.infinispan) ZOWE_CONFIG.components['caching-service'].storage.infinispan = {};
  ZOWE_CONFIG.components['caching-service'].storage.infinispan.jgroups = { port: 7800 };
  
  ZOWE_CONFIG.haInstances = {
    instance1: { hostname: 'host-a.example.com' },
    instance2: { hostname: 'host-b.example.com' }
  };
  const result = _unit_test.getInfinispanInitialHosts(ZOWE_CONFIG);
  rc += assertEqualsStrict(result, 'host-a.example.com[7800],host-b.example.com[7800]');
  
  // Cleanup
  ZOWE_CONFIG.components['caching-service'].storage.infinispan.jgroups = { port: 7600 };
}

// Test 4: Missing hostname in an instance -> warning logged, instance skipped
common.printMessage('Test 4: Missing hostname -> warning logged, instance skipped');
{
  ZOWE_CONFIG.haInstances = {
    instance1: { hostname: 'host-ok.example.com' },
    instance2: { /* no hostname */ }
  };
  const result = _unit_test.getInfinispanInitialHosts(ZOWE_CONFIG);
  rc += assertEqualsStrict(result, 'host-ok.example.com[7600]');
}

// Test 5: Duplicate hostnames -> deduplicated in output
common.printMessage('Test 5: Duplicate hostnames -> deduplicated');
{
  ZOWE_CONFIG.haInstances = {
    instance1: { hostname: 'host-dup.example.com' },
    instance2: { hostname: 'host-dup.example.com' },
    instance3: { hostname: 'host-unique.example.com' }
  };
  const result = _unit_test.getInfinispanInitialHosts(ZOWE_CONFIG);
  rc += assertEqualsStrict(result, 'host-dup.example.com[7600],host-unique.example.com[7600]');
}

// Test 6: All instances missing hostnames -> returns empty string
common.printMessage('Test 6: All instances missing hostnames -> returns empty string');
{
  ZOWE_CONFIG.haInstances = {
    instance1: {},
    instance2: {}
  };
  const result = _unit_test.getInfinispanInitialHosts(ZOWE_CONFIG);
  rc += assertEqualsStrict(result, '');
}

// Cleanup
ZOWE_CONFIG.haInstances = undefined;

common.printMessage(`Test results: ${rc} failures`);
std.exit(rc);
