/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2021
 */
const fs = require('fs');
const path = require('path');
const { getDocumentationTree } = require('./doc-tree');
const { generateDocumentationForNode } = require('./md-content');

const generatedDocDirectory = path.join(__dirname, './generated')

const rootDocNode = getDocumentationTree({ dir: path.join(__dirname, '../../commands'), command: 'zwe' });
writeMdFiles(rootDocNode, {});

function writeMdFiles(docNode, parent) {
    const nodeContent = generateDocumentationForNode(docNode, parent);
    fs.writeFileSync(`${generatedDocDirectory}/${nodeContent.fileName}.md`, nodeContent.mdContent);

    if (docNode.children && docNode.children.length) {
        for (const child of docNode.children) {
            writeMdFiles(child, nodeContent);
        }
    }
}