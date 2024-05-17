/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import { ConnectionPropsForSessCfg, Session } from '@zowe/imperative';
import { REMOTE_CONNECTION_CFG } from './config/TestConfig';

export function getZosmfSession(): Session {
  const sessCfg: unknown = {
    hostname: REMOTE_CONNECTION_CFG.host,
    port: REMOTE_CONNECTION_CFG.zosmf_port,
    user: REMOTE_CONNECTION_CFG.user,
    password: REMOTE_CONNECTION_CFG.password,
    rejectUnauthorized: REMOTE_CONNECTION_CFG.zosmf_reject_unauthorized,
    protocol: 'https',
  };

  ConnectionPropsForSessCfg.resolveSessCfgProps(sessCfg, { $0: '', _: [] }, {});
  return new Session(sessCfg);
}
