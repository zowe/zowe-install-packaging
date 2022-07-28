module.exports = [
    {
        key: 'type',
        mdGenerator: (value) => `Property value must be a ${value}`
    },
    // constants
    {
        key: 'const',
        mdGenerator: (value) => `Property value must be ${value}`
    },
    {
        key: 'enum',
        // value is an array
        mdGenerator: (value) => `Property value must be one of \`${value.join('`,`')}\``
    },
    // string constraints
    {
        key: 'minLength',
        mdGenerator: (value) => `Property value must be at least ${value} characters`
    },
    {
        key: 'maxLength',
        mdGenerator: (value) => `Property value must be less than ${value} characters`
    },
    {
        key: 'pattern',
        mdGenerator: (value) => `Property value must match the regular expression '${value}'`
    },
    // integer constraints
    {
        key: 'multipleOf',
        mdGenerator: (value) => `Property value must be a multiple of ${value}`
    },
    {
        key: 'minimum',
        mdGenerator: (value) => `Property value must be at least ${value}`
    },
    {
        key: 'exclusiveMinimum',
        mdGenerator: (value) => `Property value must be at least ${value + 1}`
    },
    {
        key: 'maximum',
        mdGenerator: (value) => `Property value must be at most ${value}`
    },
    {
        key: 'exclusiveMaximum',
        mdGenerator: (value) => `Property value must be ${value - 1}`
    },
    // object constraints
    {
        key: 'minProperties',
        mdGenerator: (value) => `Property object must have at least ${value} properties`
    },
    {
        key: 'maxProperties',
        mdGenerator: (value) => `Property object must have at most ${value} properties`
    },
    // content type constraints
    {
        key: 'contentMediaType',
        mdGenerator: (value) => `Property value must be of media type ${value}`
    },
    {
        key: 'contentEncoding',
        mdGenerator: (value) => `Property value must be ${value} encoded`
    }
    // TODO array constraints http://json-schema.org/understanding-json-schema/reference/array.html
];
// TODO should all schema keywords be in here, with priority to determine order of appearance in md file? including e.g. additionalProperties?