import FieldResolver from "./FieldResolver";

export default class RequiredResolver extends FieldResolver<string[] | undefined> {
    public constructor() {
        super('required');
    }

    protected override internalResolve(requiredValues: string[][]) {
        const required = requiredValues.reduce((acc: string[], cur: string[]) => {
            // no repeat values
            if (cur) {
                acc.push(...(cur.filter((c: string) => !acc.includes(c))));
            }
            return acc;
        }, []);


        // no required key in resolved schema if no required values
        return required.length ? required : undefined;
    }
};
