#!/usr/bin/env node

const commandLineArgs = require("command-line-args");
const commandlineUsage = require("command-line-usage");
const path = require('path');
const template = require('./template');
const ide = require("./ide-management");
const templatePath = (filename) => path.join(__dirname, "..", "support", filename);

function camelize(obj) {
  return Object.keys(obj)
    .reduce((result, key) => {
      const camelKey = key.replace(/-([a-z])/g, (g) => g[1].toUpperCase());
      result[camelKey] = obj[key];
      return result
    }, {});
}

function validateOpts(opts) {
  if (Object.values(opts).find(v => v === undefined))
    return false;
  if (isNaN(opts.diskSize) || opts.diskSize < 8)
    return false;
  if (isNaN(opts.shutdownMinutes) || opts.shutdownMinutes < 5)
    return false;
  return true;
}

const optionDefinitions = [
  { name: "disk-size", alias: "d", type: Number, defaultValue: 50, description: "EBS block storage to allocate (minimum: 8)" },
  { name: "email", alias: "e", type: String, description: "Environment owner's @northwestern.edu email address" },
  { name: "github-id", alias: "g", type: String, description: "GitHub ID of environment owner" },
  { name: "instance-type", alias: "t", type: String, defaultValue: "t3.large", description: "EC2 instance type" },
  { name: "net-id", alias: "n", type: String, description: "NetID of environment owner" },
  { name: "shutdown-minutes", alias: "s", type: Number, defaultValue: 30, description: "Number of minutes before environment hibernates (minimum: 5)" },
  { name: "help", alias: "h", type: Boolean, defaultValue: false, description: "Show this help message" }
]

const context = camelize(commandLineArgs(optionDefinitions));

if (context.help || !validateOpts(context)) {
  const usage = commandlineUsage([{
    header: 'Usage',
    optionList: optionDefinitions
  }]);
  console.log(usage);
  process.exit(1);
}

async function createIde(context) {
  const { netId, email, instanceType, diskSize, autoShutdown } = context;
  const ora = (await import('ora')).default;
  let spinner;

  try {
    context.subnetId = await ide.getRandomSubnetId();

    spinner = ora(`Creating ${netId}-dev-environment (${instanceType})`).start();
    context.environmentId = await ide.createEnvironment(instanceType, netId, context.subnetId, autoShutdown);
    spinner.succeed();

    spinner = ora(`Giving ${email} access to ${netId}-dev-environment`).start();
    await ide.shareEnvironment(context.environmentId, email);
    spinner.succeed();

    spinner = ora(`Waiting for ${netId}-dev-environment to start`).start();
    context.instanceId = await ide.waitForEnvironment(context.environmentId);
    spinner.succeed();

    spinner = ora(`Waiting for EC2 instance to initialize`).start();
    await ide.waitForInstanceStatus(context.instanceId, ["ok"]);
    spinner.succeed();

    if (diskSize) {
      spinner = ora(`Resizing EBS volume to ${diskSize} GB`).start();
      await ide.resizeInstanceDisk(context.instanceId, diskSize);
      spinner.succeed();
    }

    spinner = ora(`Running init script on ${netId}-dev-environment`).start();
    const script = template.formatFile(templatePath("cloud9-init.sh"), context);
    await ide.runCommand(context.instanceId, script);
    spinner.succeed();

    return context;
  } catch (err) {
    if (spinner && spinner.isSpinning) spinner.fail();
    throw err;
  }
}

createIde(context)
  .then((context) => {
    console.log(template.formatFile(templatePath("complete.txt"), context));
  })
  .catch((error) => {
    console.error(error)
  });