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
    // TODO move sub commands up before examples (or just after examples?)
    const nodeContent = getNodeContent(docNode, parent);
    let mdContent = `# ${nodeContent.command}`;
    for (const type of orderedDocumentationTypes) {
        if (nodeContent[type.key]) {
            let content = type.content;
            if (content.includes(FILE_CONTENT_TOKEN)) {
                const fileContent = type.fileContentTransformation ? type.fileContentTransformation(nodeContent[type.key]) : nodeContent[type.key];
                if (docNode.command === 'zwe' && type.key === 'errors') {
                    console.log(fileContent);
                }
                content = content.replace(FILE_CONTENT_TOKEN, fileContent);
            }
            mdContent = mdContent + SEPARATOR + content;
        }
    }
    if (nodeContent.childCommandLinks && nodeContent.childCommandLinks.length) {
        mdContent = mdContent + SEPARATOR + '## Commands' + SEPARATOR + nodeContent.childCommandLinks.join('\n');
    }

    fs.writeFileSync(`${generatedDocDirectory}/${nodeContent.fileName}.md`, mdContent);

    if (docNode.children && docNode.children.length) {
        for (const child of docNode.children) {
            writeMdFiles(child, nodeContent);
        }
    }
}

function getNodeContent(docNode, parent) {
    const fileName = getFileName(docNode.command, parent.fileName);

    const docNodeCommand = `[${docNode.command}](./${fileName})`;
    const command = parent.command ? `${parent.command} > ${docNodeCommand}` : docNodeCommand;

    const nodeContent = { command, fileName };

    if (docNode.children && docNode.children.length) {
        nodeContent.childCommandLinks = docNode.children.map(c => `* [${c.command}](./${getFileName(c.command, fileName)})`);
    }

    for (const type of orderedDocumentationTypes) {
        let content = null;

        if (docNode[type.key]) {
            const fileContent = fs.readFileSync(docNode[type.key], 'utf-8');
            const inheritedContent = type.inherit && parent[type.key] ? parent[type.key] : '';
            content = inheritedContent + fileContent;
        } else if (type.inherit && parent[type.key]) {
            content = parent[type.key];
        }

        if (content) {
            nodeContent[type.key] = content;
        }
    }

    return nodeContent;
}

function getFileName(command, parentFileName) {
    return parentFileName ? `${parentFileName}-${command}` : `doc-${command}`;
}