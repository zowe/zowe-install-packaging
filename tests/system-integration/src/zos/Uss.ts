/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import { REMOTE_CONNECTION_CFG } from '../config/TestConfig';
import { Shell, SshSession } from '@zowe/zos-uss-for-zowe-sdk';

export async function runCommand(command: string, cwd: string = '~') {
  const session = new SshSession({
    hostname: REMOTE_CONNECTION_CFG.host,
    port: REMOTE_CONNECTION_CFG.ssh_port,
    user: REMOTE_CONNECTION_CFG.user,
    password: REMOTE_CONNECTION_CFG.password,
  });

  let stdout = '';
  const rc = await Shell.executeSshCwd(session, command, cwd, (data) => {
    if (data.trim()) {
      stdout += data;
    }
    console.log(stdout);
  });
  return { data: stdout, rc: rc };
}
