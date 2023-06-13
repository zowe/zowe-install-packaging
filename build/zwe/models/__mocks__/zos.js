/*
  This program and the accompanying materials are
  made available under the terms of the Eclipse Public License v2.0 which accompanies
  this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

var EXTATTR_SHARELIB = 0;
var EXTATTR_PROGCTL = 0;

function changeTag(path, ccsid) {
    return 0;
}

function changeExtAttr(path, extattr, onOff) {
    return 0;
}

function zstat(path) {
    return [{
        dev: null,
        ino: null,
        uid: null,
        gid: null,
        atime: null,
        mtime: null,
        ctime: null,
        extattrs: null,
        isText: null,
        ccsid: null
    }, 0];
}
