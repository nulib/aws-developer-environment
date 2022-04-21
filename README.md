# Cloud9 Developer Environment

## Developers

### One-Time Setup

4. Copy the [SSH Proxy Script](individual/support/nul-ssm-proxy.sh) to the `~/.ssh` directory of the user who will be using the new environment.
5. `chmod 0755 ~/.ssh/nul-ssm-proxy.sh`
6. Add the following stanza to the user's `~/.ssh/config`:
   ```
   Host *.nul
     User ec2-user
     ForwardAgent yes
     StrictHostKeyChecking no
     UserKnownHostsFile /dev/null
     ProxyCommand sh -c "~/.ssh/nul-ssm-proxy.sh %h %p"
   ```

### Connecting

- Developer environments can be accessed two different ways:
  - Using the [AWS Cloud9 Console](https://us-east-1.console.aws.amazon.com/cloud9/home/shared)
    - The environment is *probably* listed under **Shared with you** rather than **Your environments**
  - Directly via SSH at `NETID.dev-environment.nul`
- This hostname can also be used to connect a [Virtual Studio Code Remote SSH](https://code.visualstudio.com/docs/remote/ssh) session
- For convenience, you can create one or more aliases in `~/.ssh/config` by copying the `*.nul` stanza and adding a `HostName`:
  ```
  Host dev
    HostName netid123.dev-environment.nul
    User ec2-user
    ForwardAgent yes
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ProxyCommand sh -c "~/.ssh/nul-ssm-proxy.sh %h %p"
  ```

## Environment Setup & Maintenance

### Common Infrastructure

The `common` directory contains the Terraform manifests for provisioning and maintaining components common to all developer environments.

#### Usage

`terraform <init|plan|apply>` as you would with any other Terraform project. There are no variables or other configuration to worry about. If initializing for the first time, you'll need to know which S3 bucket holds the existing state.

### Individual Developer Environments

The resources for setting up and maintaining developer environments are in the `individual` directory.

#### New Environment

To create a new environment:

1. Set your `AWS_PROFILE` and authenticate to a profile with admin rights in the account where the developer environments are deployed (e.g., `sandbox-admin`).
2. Create the IDE instance profile:
   ```shell
   $ cd individual/ide
   $ terraform init
   $ terraform workspace new NETID
   $ terraform apply
   $ profile_arn=$(terraform output -json | jq -r '.ide_instance_profile_arn.value')
   ```
3. Bootstrap the IDE using the instance role ARN created in the previous step:
   ```shell
   $ cd ..
   $ bin/create-ide.js -n NETID -g GITHUB_USERNAME -e EMAIL -p $profile_arn
   ```
   **Note:** The email address provided must be the `@northwestern.edu` address associated with your NUL AWS accounts.
4. Create the rest of the environment resources:
   ```shell
   $ cd environment
   $ terraform init
   $ terraform workspace new NETID-dev
   $ terraform apply
   ```
   Repeat the last two commands for additional environments (e.g., test).

#### Environment Updates

Use the common/individual Terraform directories to add, update, and maintain resources.

#### Deleting an Individual Environment

1. Delete environment resources:
   ```shell
   $ cd individual/environment
   $ terraform workspace select NETID-dev
   $ terraform init
   $ terraform refresh
   $ terraform destroy
   ```
   Repeat for any additional environments that were created.
2. Delete the IDE instance role:
   ```
   $ cd ../ide
   $ terraform init
   $ terraform refresh
   $ terraform destroy
   ```
3. Delete the Cloud9 IDE environment manually using the AWS Console or `aws` CLI.

