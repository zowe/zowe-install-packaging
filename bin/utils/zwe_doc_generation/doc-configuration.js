const SEPARATOR = '\n\n';
const FILE_CONTENT_TOKEN = '%f';
const SECTION_HEADER = '## ';

function transformParameters(fileContent) {
    const headings = ['Full name (--)', 'Alias (-)', 'Type', 'Required', 'Default value', 'Help message'];
    const unusedFieldIndices = [5, 6]; // TODO no magic number
    const cleanedFields = fileContent.split(/$/gm).map(fields => {
        const cleaned = fields.trim().split('|').reduce((filteredFields, field, index) => {
            if (!unusedFieldIndices.includes(index)) {
                if (index === 3) { // TODO no magic number
                    filteredFields.push(field === 'required' ? 'yes' : 'no'); // TODO no magic value
                } else if (index === 4) { // TODO no magic number
                    filteredFields.push(filteredFields[2] === 'string' ? field : 'N/A') // TODO no magic value
                } else {
                    filteredFields.push(field);
                }
            }
            return filteredFields;
        }, []);

        return cleaned.join('|');
    });

    return headings.join('|') + '\n' + headings.map(_ => '---').join('|') + '\n' + cleanedFields.join('\n');
}

const EXPERIMENTAL = {
    inherit: true,
    fileName: '.experimental',
    key: 'experimental',
    order: 1,
    content: '**Warning:** This command is for experimental purposes and may not fully function.'
};
const HELP = {
    fileName: '.help',
    key: 'help',
    order: 2,
    content: FILE_CONTENT_TOKEN
};
const EXAMPLES = {
    fileName: '.examples',
    key: 'examples',
    order: 3,
    content: `${SECTION_HEADER}Examples${SEPARATOR}${FILE_CONTENT_TOKEN}`,
    fileContentTransformation: (fileContent) => fileContent,
};
const EXCLUSIVE_PARAMETERS = {
    fileName: '.exclusive-parameters',
    key: 'exclusive-parameters',
    order: 4,
    content: `${SECTION_HEADER}Parameters${SEPARATOR}${FILE_CONTENT_TOKEN}`,
    fileContentTransformation: transformParameters
};
const PARAMETERS = {
    inherit: true,
    fileName: '.parameters',
    key: 'parameters',
    order: 5,
    content: `${SECTION_HEADER}Global Parameters${SEPARATOR}${FILE_CONTENT_TOKEN}`,
    fileContentTransformation: transformParameters
};
const ERRORS = {
    inherit: true,
    fileName: '.errors',
    key: 'errors',
    order: 6,
    content: `${SECTION_HEADER}Errors${SEPARATOR}${FILE_CONTENT_TOKEN}`,
    fileContentTransformation: (fileContent) => '|Error code|Exit code|Error message|\n|---|---|---|\n' + fileContent // TODO more configurable
};

const documentationTypes = [
    EXPERIMENTAL, HELP, EXAMPLES, EXCLUSIVE_PARAMETERS, PARAMETERS, ERRORS
];

const orderedDocumentationTypes = documentationTypes.sort((a, b) => a.order - b.order);

module.exports = {
    FILE_CONTENT_TOKEN,
    SEPARATOR,
    orderedDocumentationTypes
}