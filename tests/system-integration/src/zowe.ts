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
import { REMOTE_CONNECTION } from './constants';

let cachedZosmfSession: Session;

export function getZosmfSession(): Session {
  if (cachedZosmfSession != null) {
    return cachedZosmfSession;
  }

  const sessCfg: unknown = {
    hostname: REMOTE_CONNECTION.host,
    port: REMOTE_CONNECTION.zosmf_port,
    user: REMOTE_CONNECTION.user,
    password: REMOTE_CONNECTION.password,
    rejectUnauthorized: REMOTE_CONNECTION.zosmf_reject_unauthorized,
    protocol: 'https',
  };

  ConnectionPropsForSessCfg.resolveSessCfgProps(sessCfg, { $0: '', _: [] }, {});
  cachedZosmfSession = new Session(sessCfg);
  console.log('returning not cached ' + cachedZosmfSession);
  return cachedZosmfSession;
}
