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
import { NodeSSH } from 'node-ssh';
import { SshResponse } from './SshResponse';
import { sleep } from '../utils';

export class UssSession {
  private static shrSess: UssSession;
  private sessionInit: boolean = false;
  private readonly ssh = new NodeSSH();

  private constructor() {
    this.ssh
      .connect({
        host: REMOTE_CONNECTION_CFG.host,
        username: REMOTE_CONNECTION_CFG.user,
        port: REMOTE_CONNECTION_CFG.ssh_port,
        password: REMOTE_CONNECTION_CFG.password,
        tryKeyboard: true,
        onKeyboardInteractive: (name, instructions, instructionsLang, prompts, finish) => {
          if (prompts.length > 0 && prompts[0].prompt.toLowerCase().includes('password')) {
            finish([REMOTE_CONNECTION_CFG.password]);
          }
        },
      })
      .then(() => {
        console.log('uss session connected');
        this.sessionInit = true;
      });
  }

  public shutdown() {
    this.ssh.dispose();
  }

  /**
   * Re-uses an existing SSH session context to run commands.
   */
  public static sharedSession() {
    if (this.shrSess == null) {
      this.shrSess = new UssSession();
    }
    return this.shrSess;
  }

  /**
   * Creates a new SSH session, ignoring any existing shared session contexts.
   */
  public static newSession() {
    return new UssSession();
  }

  public async runCommand(command: string, cwd: string = '~'): Promise<SshResponse> {
    let tries = 10;
    while (!this.sessionInit && tries > 0) {
      await sleep(500);
      tries--;
    }
    if (!this.sessionInit) {
      console.log(`Could not run command, SSH session couldn't be established.`);
    }
    const response = await this.ssh.execCommand(command, { cwd: cwd });
    return { data: response.stdout, rc: response.code, error: response.stderr };
  }
}
