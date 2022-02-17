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

const { FILE_CONTENT_TOKEN, SEPARATOR, orderedDocumentationTypes } = require('./doc-configuration');

const docsRootDirectory = path.join(__dirname, '../../commands');
const generatedDocDirectory = path.join(__dirname, './generated');

const docsTree = getDocumentationTree(docsRootDirectory);
console.log(JSON.stringify(docsTree, null, 2));

writeMdFiles(docsTree); // TODO can this process be merged into getting the docs tree? So its one pass, not two?

function getDocumentationTree(directory) {
    const documentationNode = { children: [] };
    const objectsInDirectory = fs.readdirSync(directory);

    for (const file of objectsInDirectory) {
        const objectPath = path.join(directory, file);
        if (fs.statSync(objectPath).isDirectory()) {
            documentationNode.children.push(getDocumentationTree(objectPath));
        } else {
            const docFileType = orderedDocumentationTypes.find((df) => df.fileName === file);
            if (docFileType) {
                documentationNode.command = path.basename(directory);
                if (documentationNode.command === 'commands') {
                    documentationNode.command = 'zwe'; // special case for root directory name
                }
                documentationNode[docFileType.key] = objectPath;
            }
        }
    }

    return documentationNode;
}

const PARENT_TYPES = {
    PARAMETER: "parameters",
    ERRORS: "errors",
    EXPERIMENTAL: "experimental"
}

function writeMdFiles(docNode, parent = {}) {
    // TODO undefined errMessage and help param for root zwe files
    const nodeContent = getNodeContent(docNode, parent);
    let mdContent = `# ${nodeContent.command}`;
    for (const type of orderedDocumentationTypes) {
        if (nodeContent[type.key]) {
            let content = type.content;
            if (content.includes(FILE_CONTENT_TOKEN)) {
                const fileContent = type.fileContentTransformation ? type.fileContentTransformation(nodeContent[type.key]) : nodeContent[type.key];
                content = content.replace(FILE_CONTENT_TOKEN, fileContent);
            }
            mdContent = mdContent + SEPARATOR + content;
        }
    }

    fs.writeFileSync(`${generatedDocDirectory}/doc-${nodeContent.command.replace(/\s/g, '-')}.md`, mdContent);

    if (docNode.children && docNode.children.length) {
        for (const child of docNode.children) {
            writeMdFiles(child, nodeContent);
        }
    }
}

function getNodeContent(docNode, parent) {
    // TODO need to link to children and parent commands
    const command = parent.command ? `${parent.command} ${docNode.command}` : docNode.command;
    const nodeContent = { command };

    for (const type of orderedDocumentationTypes) {
        let content = null;

        if (docNode[type.key]) {
            const fileContent = fs.readFileSync(docNode[type.key], 'utf-8');
            const inheritedContent = type.inherit ? parent[type.key] : '';
            content = inheritedContent + fileContent;
        } else if (type.inherit) {
            content = parent[type.key];
        }

        if (content) {
            nodeContent[type.key] = content;
        }
    }

    return nodeContent;
}
