import FieldResolver from "./FieldResolver";

export default class DescriptionResolver extends FieldResolver<string> {
    private static instance: DescriptionResolver | null = null;

    private constructor() {
        super('description');
    }

    protected override internalResolve(descriptionValues: string[]) {
        return descriptionValues.reduce((acc: string, cur) => {
            if (cur) {
                acc += cur + '\n';
            }
            return acc;
        }, '');
    }

    public static getInstance(): DescriptionResolver {
        if (!this.instance) {
            this.instance = new DescriptionResolver();
        }
        return this.instance;
    }
};
