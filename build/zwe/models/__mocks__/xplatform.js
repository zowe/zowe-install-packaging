/*
  This program and the accompanying materials are
  made available under the terms of the Eclipse Public License v2.0 which accompanies
  this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

function fileCopy(source, destination) {
    return [0, 0, 0];
}
function fileCopyConverted(source, sourceCCSID, destination, destinationCCSID) {
    return [0, 0, 0];
}
function dirname(path) {
    return ['', 0];
}

function getpid() {
    return 0;
}

/**
   sourceCCSID == -1, means apply default charset conversion if necessary.

   sourceCCSID == 0, mean don't translate bytes, trust that they are UTF8, even if they aren't!
*/
function stringFromBytes(data, offset, length, sourceCCSID) {
    return '';
}

/**
   sourceCCSID as above
*/
function loadFileUTF8(path, sourceCCSID) {
    return '';
}
function storeFileUTF8(path, targetCCSID, content) {
    return 0;
}

var AUTO_DETECT = 0;
var NO_CONVERT = 0;

exports.fileCopy = fileCopy;
exports.fileCopyConverted = fileCopyConverted;
exports.dirname = dirname;
exports.getpid = getpid;
exports.stringFromBytes = stringFromBytes;
exports.loadFileUTF8 = loadFileUTF8;
exports.storeFileUTF8 = storeFileUTF8;
