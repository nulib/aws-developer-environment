const AWS = require('aws-sdk');

const hostedZoneId = process.env.hosted_zone_id;
const hostedZoneName = process.env.hosted_zone_name;

const applyChanges = async (changes) => {
  const route53 = new AWS.Route53();

  if (changes.length == 0) return {};

  return await route53.changeResourceRecordSets({
    HostedZoneId: hostedZoneId,
    ChangeBatch: {
      Changes: changes
    }
  }).promise();
};

const upsertRoute53Record = async (instanceId, hostname) => {
  const ec2 = new AWS.EC2();

  console.log("Getting public IP address for instance ", instanceId);
  const response = await ec2.describeInstances({ InstanceIds: [instanceId] }).promise();
  const ipAddress = response.Reservations[0].Instances[0].PublicIpAddress;

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
  const route53 = new AWS.Route53();

  console.log(`Locating DNS records for ${hostname}`);
  const { ResourceRecordSets } = await route53.listResourceRecordSets({ 
    HostedZoneId: hostedZoneId, 
    StartRecordName: hostname, 
    StartRecordType: "A"
  }).promise();

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
  const ec2 = new AWS.EC2();

  const instanceId = event.detail["instance-id"];
  console.log("Getting tags for instance ", instanceId);
  const { Tags } = await ec2.describeTags({
    Filters: [{
      Name: "resource-id",
      Values: [instanceId]
    }]
  }).promise();

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