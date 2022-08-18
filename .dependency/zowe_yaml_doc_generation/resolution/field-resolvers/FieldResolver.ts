import { JSONSchema } from "json-schema-ref-parser";

export default abstract class FieldResolver<T> {
    public readonly fields: string[];

    protected constructor(...fields: string[]) {
        this.fields = fields;
    }

    public resolve(schemas: JSONSchema[]): T {
        const extractedFields: T[] = [];
        for (const field of this.fields) {
            for (const schema of schemas) {
                const s: any = schema;
                if (s[field]) {
                    extractedFields.push(s[field]);
                }
            }
        }


        return this.internalResolve(extractedFields);
    }

    public resolveField(values: T[]): T {
        return this.internalResolve(values);
    }

    protected abstract internalResolve(fields: T[]): T;
}
