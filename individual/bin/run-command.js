#!/usr/bin/env node

const commandLineArgs = require("command-line-args");
const fs = require("fs");
const ide = require("./ide-management");

async function runCommand(args) {
  const script = fs.readFileSync(args.script).toString();
  const instanceIds = await Promise.all(args.owner.map(ide.findInstanceByOwnerId));
  console.log(`Running ${args.script} on instances: ${instanceIds.join(', ')}`);
  return await ide.runCommand(instanceIds, script);
}

const args = commandLineArgs([{
  name: "owner",
  alias: "o",
  type: String,
  multiple: true,
  required: true
}, {
  name: "script",
  alias: "s",
  type: String,
  required: true
}]);

runCommand(args)
  .then((result) => console.log(result))
  .catch((error) => console.log(error));
