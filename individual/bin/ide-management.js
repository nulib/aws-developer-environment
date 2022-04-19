const AWS = require("aws-sdk");

const waitForEvent = (onCheck, delay, onSuccess, onFailure, onWait) => {
  onCheck()
    .then((returnValue) => {
      if (returnValue !== undefined) {
        onSuccess(returnValue);
      } else {
        if (onWait !== undefined) {
          onWait();
        }
        setTimeout(
          waitForEvent,
          delay,
          onCheck,
          delay,
          onSuccess,
          onFailure,
          onWait
        );
      }
    })
    .catch(onFailure);
};

const createEnvironment = async (
  instanceType,
  netId,
  subnetId,
  shutdownMinutes
) => {
  const cloud9 = new AWS.Cloud9();
  const { environmentId } = await cloud9
    .createEnvironmentEC2({
      name: `${netId}-dev-environment`,
      description: `${netId}'s development environment`,
      instanceType: instanceType,
      imageId: "amazonlinux-2-x86_64",
      subnetId: subnetId,
      connectionType: "CONNECT_SSM",
      automaticStopTimeMinutes: shutdownMinutes,
      tags: [
        {
          Key: "project",
          Value: "dev-environment",
        },
        {
          Key: "owner",
          Value: netId,
        },
      ],
    })
    .promise();

  return environmentId;
};

const shareEnvironment = async (environmentId, email) => {
  const cloud9 = new AWS.Cloud9();
  const sts = new AWS.STS();

  if (!email.match("@")) email = `${email}@northwestern.edu`;
  const { Arn } = await sts.getCallerIdentity().promise();
  const userArn = Arn.replace(/-Admins\//, "-PowerUsers/").replace(
    /[^\/]+$/,
    email
  );
  if (userArn != Arn) {
    await cloud9
      .createEnvironmentMembership({
        environmentId: environmentId,
        userArn: userArn,
        permissions: "read-write",
      })
      .promise();
  }
};

const getEnvironmentInstanceId = async (environmentId) => {
  const ec2 = new AWS.EC2();
  const { Reservations } = await ec2
    .describeInstances({
      Filters: [
        {
          Name: "tag:aws:cloud9:environment",
          Values: [environmentId],
        },
        {
          Name: "instance-state-name",
          Values: ["running"],
        },
      ],
    })
    .promise();

  return Reservations[0]?.Instances[0]?.InstanceId;
};

const getInstanceStatus = async (instanceId) => {
  const ec2 = new AWS.EC2();
  try {
    const { InstanceStatuses } = await ec2
      .describeInstanceStatus({
        InstanceIds: [instanceId],
      })
      .promise();

    return InstanceStatuses[0]?.InstanceStatus.Status;
  } catch (err) {
    if (err.name == "InvalidInstanceID.NotFound") {
      return null;
    } else {
      throw err;
    }
  }
};

const getRandomSubnetId = async () => {
  const ec2 = new AWS.EC2();
  const { Subnets } = await ec2
    .describeSubnets({
      Filters: [
        { Name: "tag:project", Values: ["dev-environment"] },
        { Name: "tag:Name", Values: ["*-public-*"] },
      ],
    })
    .promise();

  return Subnets[Math.floor(Math.random() * Subnets.length)]?.SubnetId;
};

const waitForEnvironment = (environmentId, waitCallback) => {
  return new Promise((resolve, reject) => {
    const checkCallback = async () => {
      return await getEnvironmentInstanceId(environmentId);
    };

    waitForEvent(checkCallback, 1000, resolve, reject, waitCallback);
  });
};

const waitForInstanceStatus = (instanceId, statuses, waitCallback) => {
  return new Promise((resolve, reject) => {
    const checkCallback = async () => {
      const status = await getInstanceStatus(instanceId);
      return statuses.indexOf(status) > -1 ? status : undefined;
    };

    waitForEvent(checkCallback, 1000, resolve, reject, waitCallback);
  });
};

const runCommand = async (instanceId, script, waitCallback) => {
  const ssm = new AWS.SSM();

  const payload = { commands: script.split(/\r?\n/) };

  const { Command } = await ssm
    .sendCommand({
      DocumentName: "AWS-RunShellScript",
      InstanceIds: [instanceId],
      Parameters: payload,
    })
    .promise();

  switch (Command.Status) {
    case "Pending":
    case "InProgress":
    case "Delayed":
      return await monitorCommand(instanceId, Command.CommandId, waitCallback);
    case "Success":
      return Command.Status;
    default:
      throw new Error(`${Command.Status}: ${Command.StatusDetails}`);
  }
};

const monitorCommand = (instanceId, commandId, waitCallback) => {
  return new Promise((resolve, reject) => {
    const checkCallback = async () => {
      const ssm = new AWS.SSM();
      const { Status, StatusDetails } = await ssm
        .getCommandInvocation({ InstanceId: instanceId, CommandId: commandId })
        .promise();
      switch (Status) {
        case "Pending":
        case "InProgress":
        case "Delayed":
          return undefined;
        case "Success":
          return Status;
        default:
          throw new Error(`${Status}: ${StatusDetails}`);
      }
    };

    waitForEvent(checkCallback, 1000, resolve, reject, waitCallback);
  });
};

const waitForVolume = (volumeId, waitCallback) => {
  return new Promise((resolve, reject) => {
    const checkCallback = async () => {
      const ec2 = new AWS.EC2();
      const response = await ec2
        .describeVolumesModifications({
          VolumeIds: [volumeId],
          Filters: [
            {
              Name: "modification-state",
              Values: ["optimizing", "completed"],
            },
          ],
        })
        .promise();
      return response.VolumesModifications.length == 1 ? "ok" : undefined;
    };

    waitForEvent(checkCallback, 1000, resolve, reject, waitCallback);
  });
};

const resizeEbsVolume = async (volumeId, diskSize, waitCallback) => {
  const ec2 = new AWS.EC2();
  const { VolumeModification } = await ec2
    .modifyVolume({ VolumeId: volumeId, Size: diskSize })
    .promise();

  switch (VolumeModification.ModificationState) {
    case "completed":
    case "optimizing":
      return "ok";
    case "modifying":
      return await waitForVolume(volumeId, waitCallback);
    case "failed":
      throw new Error(VolumeModification.StatusMessage);
  }
};

const resizeInstanceDisk = async (instanceId, diskSize, waitCallback) => {
  const ec2 = new AWS.EC2();
  const response = await ec2
    .describeInstances({ InstanceIds: [instanceId] })
    .promise();
  const volumeId =
    response.Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId;
  return await resizeEbsVolume(volumeId, diskSize, waitCallback);
};

module.exports = {
  createEnvironment,
  shareEnvironment,
  getEnvironmentInstanceId,
  getInstanceStatus,
  getRandomSubnetId,
  waitForEnvironment,
  waitForInstanceStatus,
  runCommand,
  monitorCommand,
  resizeEbsVolume,
  resizeInstanceDisk,
};
