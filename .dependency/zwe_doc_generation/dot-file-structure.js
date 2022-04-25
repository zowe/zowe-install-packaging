/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2021
 */

const DOT_FILE_TABLE_ENTRY_DELIMITER = '|';
const DOT_FILE_TABLE_ROW_DELIMITER = '\n';

const parameterTable = {
    delimiter: '|',
    orderedSegments: [
        {
            position: 1,
            meaning: 'Full name',
            transform: (content) => content ? `--${content.replace(/,/g, ',--')}` : '' // other full name options are comma delimited
        },
        {
            position: 2,
            meaning: 'Alias',
            transform: (content) => content ? `-${content.replace(/,/g, ',-')}` : '' // other alias options are comma delimited
        },
        {
            position: 3,
            meaning: 'Type'
        },
        {
            position: 4,
            meaning: 'Required',
            transform: (content) => content === 'required' ? 'yes' : 'no'
        },
        {
            position: 5,
            meaning: 'Reserved for future use',
            ignore: true
        },
        {
            position: 6,
            meaning: 'Reserved for future use',
            ignore: true
        },
        {
            position: 7,
            meaning: 'Help message'
        }
    ]
}

const EXPERIMENTAL = {
    inherit: true,
    fileName: '.experimental',
    meaning: 'WARNING: This command is for experimental purposes and could be changed in the future releases.'
};
const HELP = {
    fileName: '.help',
};
const EXAMPLES = {
    fileName: '.examples',
};
const EXCLUSIVE_PARAMETERS = {
    fileName: '.exclusive-parameters',
    table: parameterTable
};
const PARAMETERS = {
    inherit: true,
    fileName: '.parameters',
    table: parameterTable
};
const ERRORS = {
    inherit: true,
    fileName: '.errors',
    table: {
        delimiter: '|',
        orderedSegments: [
            {
                position: 1,
                meaning: 'Error code',
            },
            {
                position: 2,
                meaning: 'Exit code',
            },
            {
                position: 3,
                meaning: 'Error message',
            }
        ]
    }
};

module.exports = {
    EXPERIMENTAL, HELP, EXAMPLES, EXCLUSIVE_PARAMETERS, PARAMETERS, ERRORS, DOT_FILE_TABLE_ENTRY_DELIMITER, DOT_FILE_TABLE_ROW_DELIMITER
};
