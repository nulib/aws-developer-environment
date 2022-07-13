const { ECSClient, RunTaskCommand } = require('@aws-sdk/client-ecs');

const handler = async (_event) => {
  const securityGroups    = process.env.securityGroups?.split(/\s*,\s*/);
  const subnets           = process.env.subnets?.split(/\s*,\s*/);
  const taskDefinition    = process.env.taskDefinition;

  const ecs = new ECSClient();

  const command = new RunTaskCommand({
    launchType: 'FARGATE',
    taskDefinition,
    networkConfiguration: {
      awsvpcConfiguration: {
        assignPublicIp: 'ENABLED',
        securityGroups,
        subnets
      }
    }
  });

  return await ecs.send(command);
};

module.exports = { handler };
