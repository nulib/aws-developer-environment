const AWS = require('aws-sdk');

const hostedZoneId = process.env.hosted_zone_id;

const upsertRoute53Record = async (instanceId, owner) => {
  const ec2 = new AWS.EC2();
  const route53 = new AWS.Route53();

  response = await ec2.describeInstances({InstanceIds: [instanceId]}).promise();
  const ipAddress = response.Reservations[0].Instances[0].PublicIpAddress;

  return await route53.changeResourceRecordSets({
    ChangeBatch: {
      Changes: [
        {
          Action: "UPSERT",
          ResourceRecordSet: {
            Name: owner,
            Type: "A",
            ResourceRecords: [{ Value: ipAddress }],
            TTL: 60
          }
        }
      ]
    }
  });
};

const deleteRoute53Record = async (owner) => {
  return await route53.changeResourceRecordSets({
    ChangeBatch: {
      Changes: [
        {
          Action: "DELETE",
          ResourceRecordSet: {
            Name: owner,
            Type: "A",
            TTL: 60
          }
        }
      ]
    }
  });
}

exports.handler = async (event, context) => {
  const ec2 = new AWS.EC2();

  const instanceId = event.detail["instance-id"];
  const { Tags } = await ec2.describeTags({
    Filters: [{
      Name: "resource-id",
      Values: [instanceId]
    }]
  }).promise();
 
  if (! Tags.find(({Key, Value}) => { return Key == "project" && Value == "dev-environment" })) {
    return {};
  }

  const ownerTag = Tags.find(({Key}) => Key == "owner");
  const owner = ownerTag.Value;

  switch (event.detail.state) {
    case "running":
      return await upsertRoute53Record(instanceId, owner);
    case "stopped":
    case "terminated":
      return await deleteRoute53Record(owner);
    default:
      return {};
  }
}