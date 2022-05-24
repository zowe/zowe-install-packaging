/*
  Some very common JS object manipulation utilities to
  avoid the need for loads of NPM effluvia.  

*/

declare namespace console {
  function log(...args:string[]): void;
};

export class Objutils {
    static isObject(x:any){
        let type = typeof x;
        return (x != null) && (type === 'object')
    }

    static isAtom(x:any){
        return !Objutils.isObject(x) && !Array.isArray(x);
    }

    static arrayAll(a:any, predicate: (x:any) => boolean){
        for (const elt of a){
            if (!predicate(a)){
                return false;
            }
        }
        return true;
    }

    static propertyValuesAll(obj:any, predicate: (x:any) => boolean){
        for (const key in obj){
            let value = obj[key];
            if (!predicate(value)){
                return false;
            }
        }
        return true;
    }

}

export class Flattener {
    prefix:string = "";
    separator:string = ".";
    
    constructor(){

    }

    flatten1(json:any, first:boolean, keyPrefix:string, result:any):void {
        if (Array.isArray(json)){
            for (let i=0; i<json.length; i++){
                this.flatten1(json[i],false, keyPrefix+(first ? "" : this.separator)+i,result);
            }
            return result;
        } else if (Objutils.isObject(json)){
            const keys = Object.keys(json);
            for (const key of keys){
                this.flatten1(json[key],false,keyPrefix+(first ? "" : this.separator)+key,result);
            }
        } else {
            result[keyPrefix] = json;
        }
    }

    setSeparator(separator:string):void {
        this.separator = separator;
    }

    setPrefix(prefix:string):void {
        this.prefix = prefix;
    }

    flatten(x:any):any {
        let result = {};
        this.flatten1(x, true, this.prefix, result);
        return result;
    }

}


export class Copier {
    constructor(){

    }


    copy(json:any):any{
        if (Array.isArray(json)){
            let result:any[] = [];
            for (let i=0; i<json.length; i++){
                result[i] = this.copy(json[i]);
            }
            return result;
        } else if (Objutils.isObject(json)){
            let result:any = {};
            const keys = Object.keys(json);
            for (const key of keys){
                result[key] = this.copy(json[key]);
            }
            return result;
        } else {
            return json; // string, boolean, number, Symbol, null, ...
        }
    }

}

export class Merger extends Copier {
    mergeArrays:boolean;
    
    constructor(){
        super();
        this.mergeArrays = true;
    }

    merge(overrides:any, base:any):any {
        if (Array.isArray(base)){
            if (Array.isArray(overrides)){
                if (this.mergeArrays){
                    return base.concat(overrides);
                } else {
                    let empty:any[] = [];
                    return empty.concat(overrides);
                }
            } else {
                return this.copy(overrides);
            }
        } else if (Objutils.isObject(base)){
            if (Objutils.isObject(overrides)){
                /*
                  console.log("merging "+JSON.stringify(base));
                  console.log("and     "+JSON.stringify(overrides));
                */
                let result:any = {};
                const keys = Object.keys(base);
                for (const key of keys){
                    let baseValue = base[key];
                    let overrideValue = overrides[key];
                    if (overrideValue === undefined){
                        result[key] = this.copy(baseValue);
                    } else {
                        result[key] = this.merge(overrideValue,baseValue);
                    }                    
                }
                const overrideKeys = Object.keys(overrides);
                for (const key of overrideKeys){
                    if (base[key] === undefined){
                        result[key] = this.copy(overrides[key]);
                    }
                }
                return result;
            } else {
                return this.copy(overrides);
            }
        } else {
            return this.copy(overrides);
        }
    }
}

const MAX_SHORT_ARRAY = 4;
const MAX_SMALL_OBJECT = 3;

export class PrettyPrinter {
    chunks:string[];
    
    constructor(){
        this.chunks = [];
    }

    newline(){
        this.chunks.push("\n");
        return this;
    }

    indent(depth:number){
        let count = depth*4;
        this.chunks.push("".padEnd(count," "));
    }

    out(x:any){
        this.chunks.push(x.toString());
        return this;
    }

    keyOut(x:string){
        this.chunks.push(x.toString());
        this.chunks.push(": ");
        return this;
    }

    valueOut(x:any){
        if (typeof x === "string"){
            this.chunks.push('"');
            this.chunks.push(x);
            this.chunks.push('"');
        } else {
            this.chunks.push(x.toString());
        }
        
        return this;
    }


    prettyPrint1(x:any, depth:number, pendingKey:string|null, lastInParent:boolean){
        if (Array.isArray(x)){
            let len = x.length;
            if (false){ // (len < MAX_SHORT_ARRAY) && Objutils.arrayAll(x, Objutils.isAtom)){
                
            } else {
                this.indent(depth);
                if (pendingKey){
                    this.keyOut(pendingKey);
                }
                this.out("[");
                this.newline();
                for (let i=0; i<x.length; i++){
                    let value = x[i];
                    let isLast = (i+1 == x.length);
                    this.prettyPrint1(value,depth+1,null,isLast);
                }
                this.indent(depth);
                this.out("]");
                if (!lastInParent){
                    this.out(",");
                }
                this.newline();
            }
        } else if (Objutils.isObject(x)){
            const keys = Object.keys(x);
            if (false){
            } else {
                this.indent(depth);
                if (pendingKey){
                    this.keyOut(pendingKey);
                }
                this.out("{");
                this.newline();
                for (let i=0; i<keys.length; i++){
                    let key = keys[i];
                    let value = x[key];
                    let isLast = (i+1 == keys.length);
                    this.prettyPrint1(value,depth+1,key,isLast);
                }
                this.indent(depth);
                this.out("}");
                if (!lastInParent){
                    this.out(",");
                }
                this.newline();
            }
        } else {
            this.indent(depth);
            if (pendingKey){
                this.keyOut(pendingKey);
            }
            this.valueOut(x);
            if (!lastInParent){
                this.out(",");
            }
            this.newline();
        }
    }

    print(x:any){
        this.chunks = [];
        this.prettyPrint1(x, 0, null, true);
        console.log(""+this.chunks.join(""));
    }
}


