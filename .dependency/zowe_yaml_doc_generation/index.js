const { generateDocumentation: generateZoweYamlMdDocs } = require('./md-content');
const rootSchema = require('./temp.json');

const schemas = rootSchema.allOf?.reduce((collected, s) => {
    if (s.properties) {
        collected.push({ title: s.title, description: s.description, properties: s.properties });
    }
    return collected;
}, []);

// TODO resolve full yaml schema and then use it here
const schema = schemas[0];

generateZoweYamlMdDocs(schema);
