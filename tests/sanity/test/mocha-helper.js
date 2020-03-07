const mocha = require("mocha");
mocha.reporters.Base.symbols.ok = "[ok]";
mocha.reporters.Base.symbols.err = "[x]";
mocha.reporters.Base.symbols.dot = "[.]";
// ok: '✓',
// err: '✖',
// dot: '․',
// comma: ',',
// bang: '!'
