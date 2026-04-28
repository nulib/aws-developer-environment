export const handler = async (event) => {
  const email = event.request.userAttributes.email;
  const username = email.split('@')[0];
  const rewrittenEmail = `${username}@${process.env.AUTH_DOMAIN}`;

  event.response = {
    claimsAndScopeOverrideDetails: {
      idTokenGeneration: {
        claimsToAddOrOverride: {
          email: rewrittenEmail,
        },
      },
    },
  };

  return event;
};
