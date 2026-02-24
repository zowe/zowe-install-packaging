/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import { ConnectionPropsForSessCfg, ISession, Session } from '@zowe/imperative';
import { REMOTE_CONNECTION_CFG } from '../config/TestConfig';
import { AUTH_TYPE_BASIC } from '@zowe/imperative/lib/rest/src/session/SessConstants';

export function getSession(): Session {
  const sessCfg: ISession = {
    hostname: REMOTE_CONNECTION_CFG.host,
    port: REMOTE_CONNECTION_CFG.zosmf_port,
    user: REMOTE_CONNECTION_CFG.user,
    password: REMOTE_CONNECTION_CFG.password,
    rejectUnauthorized: REMOTE_CONNECTION_CFG.zosmf_reject_unauthorized,
    protocol: 'https',
  };

  ConnectionPropsForSessCfg.resolveSessCfgProps(sessCfg, { $0: '', _: [] }, { supportedAuthTypes: [AUTH_TYPE_BASIC] });
  return new Session(sessCfg);
}
