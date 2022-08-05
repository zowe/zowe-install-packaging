import path from 'path';
import fs from 'fs';
import { generateZoweYamlMdDocs } from './documentation';
import SchemaResolver from './resolution/SchemaResolver';
import validateYamlAgainstSchema from './validation';

const RESOLVED_SCHEMA_FILE_PATH = path.join(__dirname, './resolved.json');

const schemaResolver = new SchemaResolver(RESOLVED_SCHEMA_FILE_PATH);
schemaResolver.resolveMegaSchema().then(() => {
    validateYamlAgainstSchema(path.join(__dirname, '../../example-zowe.yaml'), RESOLVED_SCHEMA_FILE_PATH);

    const zoweYamlSchema = JSON.parse(fs.readFileSync(RESOLVED_SCHEMA_FILE_PATH, 'utf8'));
    generateZoweYamlMdDocs(zoweYamlSchema);
});

