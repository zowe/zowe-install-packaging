import path from 'path';
import fs from 'fs';
import { generateZoweYamlMdDocs } from './documentation';

const RESOLVED_SCHEMA_FILE_PATH = path.join(__dirname, './resolved.json');

const zoweYamlSchema = JSON.parse(fs.readFileSync(RESOLVED_SCHEMA_FILE_PATH, 'utf8'));

generateZoweYamlMdDocs(zoweYamlSchema);
