export default abstract class FieldResolver<T> {
    public readonly field: string;

    protected constructor(field: string) {
        this.field = field;
    }

    // TODO remove anys - should be from a list of allowable keys, including custom keys
    public resolve(schemas: any[]): T {
        const fields: T[] = schemas.filter(s => s[this.field]).map(s => s[this.field]);
        return this.internalResolve(fields);
    }

    protected abstract internalResolve(fields: T[]): T;
}
