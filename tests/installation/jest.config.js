module.exports = {
  reporters: [
    "default",
    [
      "jest-junit",
      {
        suiteName: "Zowe Install Test",
        outputDirectory: "./reports",
        classNameTemplate: "{filepath}",
        titleTemplate: "{classname} - {title}",
      }
    ]
  ]
};
