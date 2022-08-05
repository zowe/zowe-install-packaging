import path from 'path';
import fs from 'fs';
import { generateZoweYamlMdDocs } from './documentation';
import SchemaResolver from './resolution/SchemaResolver';

const RESOLVED_SCHEMA_FILE_PATH = path.join(__dirname, './resolved.json');

const schemaResolver = new SchemaResolver(RESOLVED_SCHEMA_FILE_PATH);
schemaResolver.resolveMegaSchema().then(resolvedSchema => {
    const zoweYamlSchema = JSON.parse(fs.readFileSync(RESOLVED_SCHEMA_FILE_PATH, 'utf8'));
    generateZoweYamlMdDocs(zoweYamlSchema);
});

