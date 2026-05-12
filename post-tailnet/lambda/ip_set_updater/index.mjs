import {
  WAFV2Client,
  GetIPSetCommand,
  UpdateIPSetCommand
} from "@aws-sdk/client-wafv2";

const tailscaleApiKey = process.env.TAILSCALE_API_KEY;
const tailnet = process.env.TAILNET;
const ipSetId = process.env.WAF_IP_SET_ID;
const ipSetName = process.env.WAF_IP_SET_NAME;
const scope = "REGIONAL";
const PRIVATE_IPS = /^(100|10|172\.(1[6-9]|2[0-9]|3[0-1])|192\.168)\./;

const routableEndpoints = (addresses) => {
  const result = addresses
    .filter((ip) => !(ip[0] === "[" || PRIVATE_IPS.test(ip.split(":")[0])))
    .map((ip) => ip.split(":")[0]);
  return [...new Set(result)];
};

export const handler = async () => {
  // 1. Fetch tagged devices from Tailscale
  const resp = await fetch(
    `https://api.tailscale.com/api/v2/tailnet/${tailnet}/devices?fields=name,hostname,clientConnectivity&tags=tag:user`,
    {
      headers: { Authorization: `Bearer ${tailscaleApiKey}` }
    }
  );
  const { devices } = await resp.json();

  const discoveredAddresses = devices.map((d) => ({
    hostname: d.hostname,
    endpoints: routableEndpoints(d.clientConnectivity?.endpoints || [])
  }));
  console.log("Discovered addresses", discoveredAddresses);

  const addresses = discoveredAddresses.flatMap(({ endpoints }) =>
    endpoints.map((ep) => `${ep}/32`)
  );

  // 2. Get current IPSet (need lockToken)
  const waf = new WAFV2Client({});
  const { IPSet, LockToken } = await waf.send(
    new GetIPSetCommand({
      Id: ipSetId,
      Name: ipSetName,
      Scope: scope
    })
  );

  // 3. Update
  await waf.send(
    new UpdateIPSetCommand({
      Id: ipSetId,
      Name: ipSetName,
      Scope: scope,
      LockToken,
      Addresses: addresses
    })
  );

  return {
    statusCode: 200,
    body: `Updated IPSet with ${addresses.length} addresses`
  };
};
