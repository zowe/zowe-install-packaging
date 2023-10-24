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
const { EXPERIMENTAL, HELP, EXAMPLES, EXCLUSIVE_PARAMETERS, PARAMETERS, ERRORS, DOT_FILE_TABLE_ENTRY_DELIMITER, DOT_FILE_TABLE_ROW_DELIMITER } = require('./dot-file-structure');

const SEPARATOR = '\n\n';
const SECTION_HEADER_PREFIX = '## ';
const SUB_SECTION_HEADER_PREFIX = '#' + SECTION_HEADER_PREFIX;
const MD_TABLE_ROW_DELIMITER = '\n';
const MD_TABLE_ENTRY_DELIMITER = '|';
const CODE_SECTION = '```';

// order content will appear, with prefix/postfix as needed
const orderedDocumentationTypes = [
    { ...HELP, prefix: SECTION_HEADER_PREFIX + 'Description' + SEPARATOR },
    { ...EXPERIMENTAL },
    { ...EXAMPLES, prefix: SECTION_HEADER_PREFIX + 'Examples' + SEPARATOR + CODE_SECTION + '\n', postfix: '\n' + CODE_SECTION },
    { ...EXCLUSIVE_PARAMETERS, prefix: SECTION_HEADER_PREFIX + 'Parameters only for this command' + SEPARATOR },
    { ...PARAMETERS, prefix: SECTION_HEADER_PREFIX + 'Parameters' + SEPARATOR },
    { ...ERRORS, prefix: SECTION_HEADER_PREFIX + 'Errors' + SEPARATOR }
];

function generateDocumentationForNode(curNode, assembledParentNode) {
    const assembledDocNode = assembleDocumentationElementsForNode(curNode, assembledParentNode);
    const { command, linkCommand, children, fileName } = assembledDocNode;

    let mdContent = '# ' + command + SEPARATOR + linkCommand + SEPARATOR + '\t' + command;

    if (children.length) {
        mdContent += ' [sub-command [sub-command]...] [parameter [parameter]...]' + SEPARATOR;
        mdContent += SECTION_HEADER_PREFIX + 'Sub-commands' + SEPARATOR + children.map(c => `* [${c.command}](./${getRelativeFilePathForChild(c, fileName)})`).join('\n');
    } else {
        mdContent += ' [parameter [parameter]...]';
    }

    for (const docType of orderedDocumentationTypes) {
        let docContent = '';
        if (hasDocType(assembledDocNode, docType)) {
            docContent += createDocContent(assembledDocNode[docType.fileName].content, docType);
            const parentDocContent = createDocContent(assembledDocNode[docType.fileName].parentContent, docType);
            if (parentDocContent) {
                docContent += SEPARATOR + SUB_SECTION_HEADER_PREFIX + 'Inherited from parent command' + SEPARATOR + parentDocContent;
            }
        }

        if (docContent) {
            mdContent += SEPARATOR;
            if (docType.prefix) {
                mdContent += docType.prefix;
            }
            mdContent += docContent;
            if (docType.postfix) {
                mdContent += docType.postfix;
            }
        }
    }

    return {
        assembledDocNode,
        mdContent: mdContent
    };
}

function assembleDocumentationElementsForNode(curNode, assembledParentNode) {
    const fileName = assembledParentNode.fileName ? `${assembledParentNode.fileName}-${curNode.command}` : curNode.command;
    const command = assembledParentNode.command ? assembledParentNode.command + ' ' + curNode.command : curNode.command;
    const link = `[${curNode.command}](./${fileName})`;
    const linkCommandElements = assembledParentNode.linkCommandElements ? [...assembledParentNode.linkCommandElements, link] : [link];

    let relPathToParentLinks = './';
    let directory = assembledParentNode.directory ? assembledParentNode.directory : '.';

    if (curNode.children.length) {
        directory += '/' + curNode.command;
        relPathToParentLinks = '../';
    }

    // add '../'to make link to parent commands proper given the directory structure
    for (let elementIndex = 0; elementIndex < linkCommandElements.length - 1; elementIndex++) {
        linkCommandElements[elementIndex] = linkCommandElements[elementIndex].replace(/\(/, '(' + relPathToParentLinks); // path starts after '(', so add '../' after '('
    }

    const linkCommand = linkCommandElements.join(' > ');
    const docElements = {
        fileName,
        command,
        linkCommand,
        linkCommandElements,
        directory,
        children: curNode.children,
    };

    for (const docType of orderedDocumentationTypes) {
        const docForType = { content: '', parentContent: '' };

        if (hasDocType(curNode, docType)) {
            if (docType.meaning) {
                docForType.content = docType.meaning;
            } else {
                const docFileContent = fs.readFileSync(curNode[docType.fileName], 'utf-8');
                if (docType.table) {
                    // filter out ignored table entries
                    docForType.content = docFileContent.split(/$/gm).map(line =>
                        line
                            .trim()
                            .split(docType.table.delimiter)
                            .filter((_, index) => !docType.table.orderedSegments[index] || !docType.table.orderedSegments[index].ignore)
                            .join(DOT_FILE_TABLE_ENTRY_DELIMITER)
                    )
                        .join(DOT_FILE_TABLE_ROW_DELIMITER);
                } else {
                    docForType.content = docFileContent;
                }
            }
        }

        if (hasDocType(assembledParentNode, docType) && docType.inherit) {
            let parentContent = '';
            if (assembledParentNode[docType.fileName].content) {
                parentContent += assembledParentNode[docType.fileName].content;
            }
            if (assembledParentNode[docType.fileName].parentContent) {
                parentContent += assembledParentNode[docType.fileName].parentContent;
            }
            docForType.parentContent = parentContent;
        }

        docElements[docType.fileName] = docForType;
    }

    return docElements
}

function createDocContent(rawContent, docType) {
    let docContent = '';
    if (rawContent) {
        if (docType.table) {
            docContent += createMdTable(rawContent, docType.table);
        } else {
            docContent += rawContent;
        }
    }
    return docContent;
}

function createMdTable(rawContent, docFileTableSyntax) {
    const filteredSegments = docFileTableSyntax.orderedSegments.filter(o => !o.ignore);

    let docContent = '';
    docContent += filteredSegments.map(o => o.meaning).join(MD_TABLE_ENTRY_DELIMITER) + MD_TABLE_ROW_DELIMITER; // Set table headings
    docContent += filteredSegments.map(_ => '|---').join('') + MD_TABLE_ROW_DELIMITER; // Set table separator between headings and fields

    docContent += rawContent.split(DOT_FILE_TABLE_ROW_DELIMITER).map(line => line.trim().split(DOT_FILE_TABLE_ENTRY_DELIMITER) // transform table entries
        .map((segment, index) => {
            if (docFileTableSyntax.orderedSegments[index] && docFileTableSyntax.orderedSegments[index].transform) {
                return docFileTableSyntax.orderedSegments[index].transform(segment);
            }
            return segment;
        })
        .join(MD_TABLE_ENTRY_DELIMITER)) // join fields in a row
        .join(MD_TABLE_ROW_DELIMITER); // join rows with newline

    return docContent;
}

function getRelativeFilePathForChild(child, curCommandFileName) {
    if (curCommandFileName) {
        const childFileName = `${curCommandFileName}-${child.command}`;
        return (child.children.length ? child.command + '/' + childFileName : childFileName) + '.md';
    }
    return child.command + '.md';
}

function hasDocType(docNode, type) {
    return docNode[type.fileName] !== null & docNode[type.fileName] !== undefined;
}

module.exports = {
    generateDocumentationForNode
};
