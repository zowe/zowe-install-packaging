import { JSONSchema } from "json-schema-ref-parser";

export default abstract class FieldResolver<T> {
    public readonly field: string;

    protected constructor(field: string) {
        this.field = field;
    }

    public resolve(schemas: JSONSchema[]): T {
        const fields: T[] = schemas.filter((s: any) => s[this.field]).map((s: any) => s[this.field]);
        return this.internalResolve(fields);
    }

    public resolveField(values: T[]): T {
        return this.internalResolve(values);
    }

    protected abstract internalResolve(fields: T[]): T;
}
