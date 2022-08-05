import FieldResolver from "./FieldResolver";

export default class DescriptionResolver extends FieldResolver<string> {
    public constructor() {
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
};
