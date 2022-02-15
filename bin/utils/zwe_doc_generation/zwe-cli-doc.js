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

const rootDirectory = '../commands';

const documentationFiles = [
    {
        fileName: '.help',
        use: 'help'
    },
    {
        fileName: '.examples',
        use: 'examples'
    },
    {
        fileName: '.parameters',
        use: 'parameters'
    },
    {
        fileName: '.exclusive-parameters',
        use: 'exclusive-parameters'
    },
    {
        fileName: '.errors',
        use: 'errors'
    },
    {
        fileName: '.experimental',
        use: 'experimental'
    }
]

function getDocumentationTree(rootDirectory) {
    const documentationNode = { children: [] };
    const objectsInDirectory = fs.readdirSync(rootDirectory);

    for (const file of objectsInDirectory) {
        const objectPath = path.join(rootDirectory, file);
        if (fs.statSync(objectPath).isDirectory()) {
            documentationNode.children.push(getDocumentationTree(objectPath));
        } else {
            const docFileType = documentationFiles.find((df) => df.fileName === file);
            console.log(docFileType);
            if (docFileType) {
                documentationNode.command = path.basename(rootDirectory);
                documentationNode[docFileType.use] = objectPath;
            }
        }
    }

    return documentationNode;
}

const docsTree = getDocumentationTree('../commands');
console.log(JSON.stringify(docsTree, null, 2));

