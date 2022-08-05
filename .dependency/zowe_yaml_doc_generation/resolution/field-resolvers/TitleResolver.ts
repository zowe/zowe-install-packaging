import FieldResolver from "./FieldResolver";

export default class TitleResolver extends FieldResolver<string> {
    public constructor() {
        super('title');
    }

    protected override internalResolve(titles: string[]) {
        return titles.reduce((acc: string, cur: string) => {
            if (cur) {
                acc += cur + '\n';
            }
            return acc;
        }, '');
    }
};
