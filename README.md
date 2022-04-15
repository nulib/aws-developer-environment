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
2. Bootstrap the new environment:
   ```shell
   $ cd individual
   $ bin/create-ide.js -n NETID -g GITHUB_USERNAME
   ```
3. The output from the above command provides instructions that will:
   - Select or create a Terraform workspace for the new environment
   - Import the new developer EC2 instance into the Terraform state
   - Apply changes and create all necessary resources

#### Environment Updates

Use the common/individual Terraform directories to add, update, and maintain resources.

#### Deleting an Individual Environment

```shell
$ cd individual
$ terraform workspace select NETID
$ terraform init
$ terraform refresh
$ terraform state rm aws_instance.cloud9_ide_instance
$ terraform destroy
```
