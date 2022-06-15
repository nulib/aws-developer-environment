const { CloudWatchClient, PutMetricDataCommand } = require("@aws-sdk/client-cloudwatch");
const { EC2Client, DescribeInstancesCommand } = require("@aws-sdk/client-ec2");
const util = require('util');

const BilledStates = ["running"];
const CloudWatchNamespace = "NUL/DevEnvironment";

const uptimeMetric = (instance) => {
  if (BilledStates.indexOf(instance.State.Name) > -1) {
    const ownerTag = instance.Tags.find(({Key}) => Key == "Owner");
    const instanceOwner = ownerTag?.Value || "Unknown";

    return [
      {
        Dimensions: [{
          Name: "Owner",
          Value: instanceOwner
        }],
        MetricName: "ContinuousUptime",
        Unit: "Seconds",
        Value: (new Date() - instance.LaunchTime) / 1000
      },
      {
        Dimensions: [{
          Name: "Owner",
          Value: instanceOwner
        }],
        MetricName: "Uptime",
        Unit: "Seconds",
        Value: 300
      }
    ]
  }
}

const putUptimeMetrics = async () => {
  const ec2 = new EC2Client();
  const describeInstances = new DescribeInstancesCommand({
    Filters: [{
      "Name": "tag:Project",
      "Values": ["dev-environment"]
    }]
  });

  const result = await ec2.send(describeInstances);

  const cloudWatch = new CloudWatchClient();
  const metricData = result.Reservations
    .map(({ Instances }) => uptimeMetric(Instances[0]))
    .filter((data) => data !== undefined)
    .flat();

  const putMetricData = new PutMetricDataCommand({
    Namespace: CloudWatchNamespace,
    MetricData: metricData
  });

  return await cloudWatch.send(putMetricData);
}

const handler = async (_event, _context) => {
  return await putUptimeMetrics();
}

module.exports = { handler };