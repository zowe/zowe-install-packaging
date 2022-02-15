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

const docsRootDirectory = path.join(__dirname, '../../commands');
const generatedDocDirectory = path.join(__dirname, './generated');

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

const docsTree = getDocumentationTree(docsRootDirectory);
console.log(JSON.stringify(docsTree, null, 2));

writeMdFiles(docsTree);

function getDocumentationTree(directory) {
    const documentationNode = { children: [] };
    const objectsInDirectory = fs.readdirSync(directory);

    for (const file of objectsInDirectory) {
        const objectPath = path.join(directory, file);
        if (fs.statSync(objectPath).isDirectory()) {
            documentationNode.children.push(getDocumentationTree(objectPath));
        } else {
            const docFileType = documentationFiles.find((df) => df.fileName === file);
            if (docFileType) {
                documentationNode.command = path.basename(directory);
                documentationNode[docFileType.use] = objectPath;
            }
        }
    }

    return documentationNode;
}

function writeMdFiles(docsNode) {
    if (docsNode.children && docsNode.children.length) {
        for (const child of docsNode.children) {
            writeMdFiles(child);
        }
    }

    // TODO need to apply parent parameters to child docs
    const mdContent = `# zwe ${docsNode.command}${getMdContentForNode(docsNode)}`;
    fs.writeFileSync(`${generatedDocDirectory}/zwe-doc-${docsNode.command}.md`, mdContent);
}

function getMdContentForNode(docNode) {
    // TODO need to order the file content
    // TODO need to transform from . file format to md format (e.g. tables)
    let mdContent = "";
    for (const fileType of documentationFiles) {
        if (docNode[fileType.use]) {
            const fileContent = fs.readFileSync(docNode[fileType.use], 'utf-8');
            mdContent = mdContent.concat(`\n\n## ${fileType.use}\n\n${fileContent}`);
        }
    }

    return mdContent;
}