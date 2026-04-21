"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
function updateBinRefs({ orig, file, config }) {
    // replace a fixed-length path to bin, preserves correct output for nested source files with @bin refs
    const updContent = orig.replaceAll('../../../../../../../bin', '../bin');
    return updContent;
}
exports.default = updateBinRefs;
