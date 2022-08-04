import { FILE_EXT } from './md-constants';
import { Schema } from './types';

export function getRelativePathForChild(childSchema: Schema, childSchemaKey: string, curSchemaFileName: string, isPatternPropFile: boolean) {
    const childSchemaFileName = getSchemaFileName(childSchemaKey, curSchemaFileName, isPatternPropFile);
    if (childSchema.properties) {
        // child file name twice, once for directory name once for file name
        return `${childSchemaFileName}/${childSchemaFileName}${FILE_EXT}`;
    }
    return childSchemaFileName + FILE_EXT;
}

export function getSchemaFileName(schemaKey: string, parentFileName: string, isPatternPropFile: boolean) {
    if (isPatternPropFile) {
        // regex, use special file name. Must have a parent
        return `${parentFileName}.patternProperty`;
    }
    // not regex, use normal file name procedure
    return schemaKey;
}

// returns true then anchor link within same page to the config, false means link to new md file
export function hasNestedConfigurationBlock(childSchema: Schema) {
    return childSchema && (childSchema.properties || childSchema.patternProperties || childSchema.oneOf || childSchema.allOf);
}
