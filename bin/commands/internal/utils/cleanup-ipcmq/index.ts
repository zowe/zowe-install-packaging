import * as os from 'cm_os';
import * as common from '../../../../libs/common';
import * as shell from '../../../../libs/shell';
import * as config from '../../../../libs/config';

export function execute() {
  // Fix node.js piles up in IPC message queue
  // run this before any node command we start
  if (os.platform == 'zos') {
    const ZOWE_CONFIG=config.getZoweConfig();
    const runtimeDirectory=ZOWE_CONFIG.zowe.runtimeDirectory;
    common.printFormattedTrace("ZWELS", "zwe-internal-cleanup-ipcmq", "Clean up IPC message queue.");
    shell.execSync('sh', `${runtimeDirectory}/bin/utils/cleanup-ipc-mq.sh`);
  }
}
