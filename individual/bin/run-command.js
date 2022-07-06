#!/usr/bin/env node

const commandLineArgs = require("command-line-args");
const fs = require("fs");
const ide = require("./ide-management");

async function runCommand(args) {
  const instanceId = await ide.findInstanceByOwnerId(args.owner);

  const ora = (await import("ora")).default;
  spinner = ora(`Running ${args.script} on instance ${instanceId}`).start();
  try {
    const script = fs.readFileSync(args.script).toString();
    await ide.runCommand(instanceId, script);
    spinner.succeed();  
  } catch (err) {
    if (spinner && spinner.isSpinning) spinner.fail();
    throw err;
  }
}

const args = commandLineArgs([{
  name: "owner",
  alias: "o",
  type: String,
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
