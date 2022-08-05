import path from 'path';
import validateYamlAgainstSchema from "./validation";

const RESOLVED_SCHEMA_FILE_PATH = path.join(__dirname, './resolved.json');

validateYamlAgainstSchema(path.join(__dirname, '../../example-zowe.yaml'), RESOLVED_SCHEMA_FILE_PATH);