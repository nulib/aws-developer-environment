#!/usr/bin/env node

const path = require("path");
const template = require("./template");
const ide = require("./ide-management");
const context = require("./cli-options");

const templatePath = (filename) =>
  path.join(__dirname, "..", "support", filename);

async function createIde(context) {
  const { userId, email, instanceProfile, instanceType, diskSize, shutdownMinutes } = context;
  const ora = (await import("ora")).default;
  let spinner;

  try {
    context.subnetId = await ide.getRandomSubnetId();

    spinner = ora(
      `Creating ${userId}-dev-environment (${instanceType})`
    ).start();
    context.environmentId = await ide.createEnvironment(
      instanceType,
      userId,
      context.subnetId,
      shutdownMinutes
    );
    spinner.succeed();

    spinner = ora(`Giving ${email} access to ${userId}-dev-environment`).start();
    await ide.shareEnvironment(context.environmentId, email);
    spinner.succeed();

    spinner = ora(`Waiting for ${userId}-dev-environment to start`).start();
    context.instanceId = await ide.waitForEnvironment(context.environmentId);
    spinner.succeed();

    spinner = ora(`Waiting for EC2 instance to initialize`).start();
    await ide.waitForInstanceStatus(context.instanceId, ["ok"]);
    spinner.succeed();

    spinner = ora(`Assigning instance profile to ${userId}-dev-environment`).start();
    await ide.assignInstanceProfile(context.instanceId, instanceProfile);
    spinner.succeed();

    if (diskSize) {
      spinner = ora(`Resizing EBS volume to ${diskSize} GB`).start();
      await ide.resizeInstanceDisk(context.instanceId, diskSize);
      spinner.succeed();
    }

    spinner = ora(`Running init script on ${userId}-dev-environment`).start();
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
    console.error(error);
  });
