export const handler = async (event) => {
  const resource = event.queryStringParameters?.resource ?? "";

  const response = {
    subject: resource,
    links: [
      {
        rel: "http://openid.net/specs/connect/1.0/issuer",
        href: process.env.COGNITO_ISSUER_URL
      }
    ]
  };

  return {
    statusCode: 200,
    headers: {
      "Content-Type": "application/jrd+json",
      "Access-Control-Allow-Origin": "*"
    },
    body: JSON.stringify(response)
  };
};
