# Tailnet Setup Guide
## Custom OIDC via AWS Cognito + Microsoft Entra ID Federation

---

## Overview

This guide sets up a private Tailscale tailnet scoped to `dev.rdc.library.northwestern.edu`, isolated from any other tailnets within the broader `northwestern.edu` organization. Because Tailscale scopes tailnets by email domain, we use **AWS Cognito** as a custom OIDC provider, federated to your existing **Microsoft Entra ID** for authentication. Users log in with their normal `@northwestern.edu` credentials; Cognito rewrites the identity to `@dev.rdc.library.northwestern.edu` before presenting it to Tailscale.

### Architecture Summary

```
User (me@northwestern.edu)
  → Tailscale login
    → Cognito hosted UI
      → Entra ID (federated OIDC)
        → back to Cognito
          → Pre Token Generation Lambda rewrites email domain
            → Tailscale sees me@dev.rdc.library.northwestern.edu
              → tailnet scoped to dev.rdc.library.northwestern.edu
```

### What Is and Isn't Automated

Everything in this guide is managed as Terraform code up to the one unavoidable manual step: the **initial tailnet creation**, which requires a one-time browser-based OIDC signup. There is no API for creating a tailnet.

### Prerequisites

- AWS account with Route 53 hosting DNS for `dev.rdc.library.northwestern.edu`
- An existing Entra ID app registration (client ID and client secret in hand)
- AWS CLI and Azure CLI (`az`) configured and authenticated
- Terraform >= 1.5 installed
- Tailscale seats licensed for all users
- Access to the EC2 instances for initial setup (via SSM or EC2 Instance Connect)

---

## Part 1: Configure `terraform.tfvars`

Create `terraform.tfvars` in this directory.

```hcl
aws_region        = "us-east-1"
domain            = "dev.rdc.library.northwestern.edu"
entra_tenant_id   = "<your-entra-tenant-id>"
```

---

## Part 2: AWS + Azure Infrastructure

```bash
terraform init
terraform plan -out terraform plan
# Make sure the plan looks correct
terraform apply terraform.plan
```

Then verify the WebFinger endpoint is working before proceeding:

```bash
curl "https://dev.rdc.library.northwestern.edu/.well-known/webfinger?resource=acct:you@dev.rdc.library.northwestern.edu"
```

Expected response:

```json
{
  "subject": "acct:you@dev.rdc.library.northwestern.edu",
  "links": [
    {
      "rel": "http://openid.net/specs/connect/1.0/issuer",
      "href": "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_XXXXXXXXX"
    }
  ]
}
```

---

## Part 3: Manual — Create the Tailnet

1. Go to [https://login.tailscale.com/start/oidc](https://login.tailscale.com/start/oidc).
2. Enter your email as `your-email-username@dev.rdc.library.northwestern.edu`.
3. Click **Get OIDC Issuer** — Tailscale discovers your Cognito issuer via WebFinger.
4. Enter the values from Terraform outputs:
   ```bash
   terraform output -raw cognito_client_id
   terraform output -raw cognito_client_secret
   ```
5. Click **Sign up with OIDC** and authenticate via Entra ID with your normal `@northwestern.edu` credentials.
6. You should be redirected to the Tailscale Admin Console welcome / guided tour page.

Then create the Tailscale OAuth client that Terraform will use to manage the tailnet:

---

## Part 5: EC2 Enrollment

1. Go to https://login.tailscale.com/admin/machines/new-linux
2. In Step 1, Select `tag:dev-instance`
3. Click **Generate install script** and copy the generated script
4. Connect to the new EC2 instance via SSM or EC2 Instance Connect
5. Paste the script and execute it
6. Run the following to make sure the Tailscale service starts at boot:
   ```shell
   sudo systemctl enable tailscaled
   sudo tailscale set --operator=ec2-user
   ```
7. Run the following to check the status of the tailnet:
   ```
   tailscale status
   ```
8. Go to https://login.tailscale.com/admin/machines
9. Click the context menu to the right of the new instance, and select **Edit machine name...**.
10. Uncheck **Auto-generate from OS hostname** and change the hostname to the short username of the instance's owner.
11. Make sure the new instance has the **Expiry disabled** label. If not, click the context menu and select **Disable key expiry**.

---

## Part 7: Mac Laptops — User Onboarding

Each user installs Tailscale on their own Mac. No manual key generation is required — federated login handles everything.

```bash
brew install --cask tailscale
```

Or download from the [Mac App Store](https://tailscale.com/download/mac).

To connect:

1. Open Tailscale from the menu bar and click **Log in**.
2. Enter `your-northwestern-email-username@dev.rdc.library.northwestern.edu` when prompted for an email.
3. You'll be redirected through Cognito to Entra ID — log in with your normal NetID credentials.
4. The Mac will appear in the [Machines page](https://login.tailscale.com/admin/machines).

---

## Reference Links

- [Tailscale custom OIDC providers](https://tailscale.com/kb/1240/sso-custom-oidc)
- [Tailscale OIDC signup](https://login.tailscale.com/start/oidc)
- [Tailscale OAuth clients](https://tailscale.com/kb/1215/oauth-clients)
- [WebFinger spec (RFC 7033)](https://www.rfc-editor.org/rfc/rfc7033)
- [AWS Cognito federated identities](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-identity-federation.html)
- [Cognito Pre Token Generation trigger](https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-lambda-pre-token-generation.html)
- [Terraform azuread provider](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs)
- [Terraform aws_cognito_user_pool](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool)
- [Auth Keys](https://tailscale.com/kb/1085/auth-keys)
- [Install Tailscale on AWS EC2](https://tailscale.com/kb/1449/quick-guide-aws)
- [Tailscale SSH](https://tailscale.com/kb/1193/tailscale-ssh)
- [ACL Policy Reference](https://tailscale.com/kb/1018/acls)
