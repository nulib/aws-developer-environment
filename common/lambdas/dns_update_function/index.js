const { EC2Client, DescribeTagsCommand, DescribeInstancesCommand } = require("@aws-sdk/client-ec2");
const { Route53Client, ChangeResourceRecordSetsCommand, ListResourceRecordSetsCommand } = require("@aws-sdk/client-route-53");

const hostedZoneId = process.env.hosted_zone_id;
const hostedZoneName = process.env.hosted_zone_name;

const applyChanges = async (changes) => {
  const route53 = new Route53Client();

  if (changes.length == 0) return {};

  return await route53.send(new ChangeResourceRecordSetsCommand({
    HostedZoneId: hostedZoneId,
    ChangeBatch: {
      Changes: changes
    }
  }));

};

const getInstanceTags = async (instanceId) => {
  const ec2 = new EC2Client();

  const { Tags } = await ec2.send(new DescribeTagsCommand({
    Filters: [
      {
        Name: "resource-id",
        Values: [instanceId]
      }
    ]
  }));

  return Tags;
};

const upsertRoute53Record = async (instanceId, hostname) => {
  const ec2 = new EC2Client();
  let ipAddress;

  const tags = await getInstanceTags(instanceId);
  for (const tag of tags) {
    if (tag.Key == "tailnet-ip") {
      console.log("Found tailnet IP address for instance ", instanceId);
      ipAddress = tag.Value;
      break;
    }
  }

  if (!ipAddress) {
    console.log("Getting public IP address for instance ", instanceId);
    const response = await ec2.send(new DescribeInstancesCommand({ InstanceIds: [instanceId] }));
    ipAddress = response.Reservations[0].Instances[0].PublicIpAddress;
  }

  console.log(`Updating DNS record for ${hostname} to ${ipAddress}`);
  return await applyChanges([{
    Action: "UPSERT",
    ResourceRecordSet: {
      Name: hostname,
      Type: "A",
      ResourceRecords: [{ Value: ipAddress }],
      TTL: 60
    }
  }]);
};

const deleteRoute53Record = async (hostname) => {
  const route53 = new Route53Client();

  console.log(`Locating DNS records for ${hostname}`);
  
  const { ResourceRecordSets } = await route53.send(new ListResourceRecordSetsCommand({
    HostedZoneId: hostedZoneId, 
    StartRecordName: hostname, 
    StartRecordType: "A"
  }));

  const re = new RegExp(`^${hostname.replace(/\./g, "\\.")}\.*$`);
  const changes = ResourceRecordSets.reduce((result, ResourceRecordSet) => {
    if (re.test(ResourceRecordSet.Name)) {
      result.push({ Action: "DELETE", ResourceRecordSet });
    }
    return result;
  }, []);

  console.log(`Deleting DNS records for ${hostname}`);
  return await applyChanges(changes);  
}

exports.handler = async (event, _context) => {
  const ec2 = new EC2Client();

  const instanceId = event.detail["instance-id"];
  console.log("Getting tags for instance ", instanceId);
  const { Tags } = await ec2.send(new DescribeTagsCommand({
    Filters: [{
      Name: "resource-id",
      Values: [instanceId]
    }]
  }));

  if (!Tags.find(({ Key, Value }) => {
      return Key == "Project" && Value == "dev-environment"
    })) {
    return {};
  }

  const ownerTag = Tags.find(({ Key }) => Key == "Owner");
  const hostname = [ownerTag.Value, hostedZoneName].join(".");

  switch (event.detail.state) {
    case "running":
      return await upsertRoute53Record(instanceId, hostname);
    case "stopped":
    case "stopping":
    case "terminated":
      return await deleteRoute53Record(hostname);
    default:
      return {};
  }
}