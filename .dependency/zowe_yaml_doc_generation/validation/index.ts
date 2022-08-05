import Ajv2019 from 'ajv/dist/2019';
import fs from 'fs';
import yaml from 'js-yaml';

const ajv = new Ajv2019({ strict: 'log' }); // TODO log errors - issues with caching-service schema

export default function validateYamlAgainstSchema(yamlFilePath: string, schemaFilePath: string): void {
    const zoweYamlAsJson = yaml.load(fs.readFileSync(yamlFilePath, 'utf-8'));

    // TODO - ajv doesn't like the $anchor keyword, I believe because there are multiple fields with thee same anchor value due to schema resolve. The current workaround is to remove the $anchor field.
    const zoweYamlSchemaString = fs.readFileSync(schemaFilePath, 'utf-8').replace(/\$anchor/g, 'anchorreplace');
    const zoweYamlSchema = JSON.parse(zoweYamlSchemaString);

    ajv.addKeyword("anchorreplace");
    const validate = ajv.compile(zoweYamlSchema);
    const isValid = validate(zoweYamlAsJson);

    if (isValid) {
        console.log('valid zowe.yaml');
    } else {
        console.error(validate.errors);
        throw new Error('example-zowe.yaml was not valid against resolved.json schema');
    }
}