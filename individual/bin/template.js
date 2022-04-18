const fs = require("fs");

const formatString = (str, ...arguments) => {
  if (arguments.length) {
    var t = typeof arguments[0];
    var key;
    var args =
      "string" === t || "number" === t
        ? Array.prototype.slice.call(arguments)
        : arguments[0];

    for (key in args) {
      str = str.replace(new RegExp("\\{" + key + "\\}", "gi"), args[key]);
    }
  }

  return str;
};

const formatFile = (fileName, ...arguments) => {
  return formatString(fs.readFileSync(fileName).toString(), ...arguments);
};

module.exports = { formatFile, formatString };
