# Cloud9 Developer Environment

## Developers

### One-Time Setup

1. Make sure your `~/.bash_profile` file exports the path to your `aws` executable. For example:
   ```shell
   $ which aws
   /usr/local/bin/aws

   $ cat ~/.bash_profile
   export PATH=/usr/local/bin:/usr/local/sbin:$PATH
   ```
   If not, or if `~/.bash_profile` doesn't exist, create or update it as necessary.
2. Install the [AWS SSM Session Manager Plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html#install-plugin-macos)
2. Add the IDE access key pair to your AWS configuration
   ```shell
   bash <(curl -s https://raw.githubusercontent.com/nulib/aws-developer-environment/main/individual/support/dev_environment_profile.sh)
   ```
   (You may be prompted to log into AWS by `aws-adfs`.)
3. Copy the [SSH Proxy Script](individual/support/nul-ssm-proxy.sh) to the `~/.ssh` directory of the user who will be using the new environment.
4. `chmod 0755 ~/.ssh/nul-ssm-proxy.sh`
5. Add the following stanza to the user's `~/.ssh/config`:
   ```
   Host *.dev.rdc.library.northwestern.edu
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
  - Directly via SSH at `DEV_ID.dev.rdc.library.northwestern.edu`
- This hostname can also be used to connect a [Virtual Studio Code Remote SSH](https://code.visualstudio.com/docs/remote/ssh) session
- For convenience, you can create one or more aliases in `~/.ssh/config` by copying the `*.dev.rdc.library.northwestern.edu` stanza and adding a `HostName`:
  ```
  Host dev
    HostName devid.dev.rdc.library.northwestern.edu
    User ec2-user
    ForwardAgent yes
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ProxyCommand sh -c "~/.ssh/nul-ssm-proxy.sh %h %p"
  ```

### Navigating the IDE

- Your username is `ec2-user`.
- Your home directory is `/home/ec2-user`.
- Your VM is exclusive to you, and you have full `sudo` rights. Feel free to customize it however you like. Just be aware that any changes to `~/.zshrc` _must_ retain the contents of this project's [zshrc](individual/support/zshrc) in order for the environment to work correctly.
- The default shell is `zsh`. (Again, if you change this, make sure to look at `~/.zshrc` to see what your new shell will need to do on each login!)
- By default, all working directories are stored under `~/environment/`.
- Several tools come preinstalled, either by AWS or by the IDE [init script](individual/support/cloud9-init.sh):
  - [`asdf`](https://asdf-vm.com)
  - [`aws`](https://aws.amazon.com/cli/)
  - [`exiftool`](https://exiftool.org)
  - [`jq`](https://stedolan.github.io/jq/manual/)
  - [`mediainfo`](https://mediaarea.net/en/MediaInfo)
  - [`psql`](https://www.postgresql.org/docs/current/app-psql.html)
  - [`tmux`](https://github.com/tmux/tmux/wiki)
- Developer VMs are persistent, but also easy to tear down and rebuild in minutes. Meadow data (S3/DB/OpenSearch) will survive a reset,though your configurations and customizations will be gone. Don't hesitate to ask for a reset if you need one.
- Thanks to the `ForwardAgent yes` line in the SSH config above, your local SSH identities will be forwarded/delegated to the remote machine for the duration of your login session. That means you'll be able to automatically authenticate to servers that use public key authentication (e.g., GitHub) without having to copy your private keys around.

#### First Login

##### Configure Git

```shell
git config --global user.name "Your Name Here"
git config --global user.email your.git.email@example.com
```

If you sign your Git commits, you'll need to copy your GPG signing key to your dev environment keyring. Basic instructions on how to do that can be found [here](https://makandracards.com/makandra-orga/37763-gpg-extract-private-key-and-import-on-different-machine). (*Don't forget to delete the exported/copied/imported key files from both your local and remote machines after importing.* Once the secret key is in your keychain, you no longer need the file, and having it sitting around can be a security risk.)

Once you've done that, you'll need to [configure Git to use your signing key](https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key).

##### Clone Meadow

```shell
cd ~/environment
git clone git@github.com:nulib/meadow.git
```

##### Install Development Tools

```shell
cd meadow
# Install necessary asdf plugins and tool versions
asdf-install-plugins
asdf install

# Set the global default for each tool to use the latest installed version
for p in $(asdf plugin list); do
  asdf global $p $(asdf list $p | sort | tail -1)
done

# Install the right version of npm for each installed version of NodeJS
asdf-install-npm
asdf reshim
```

##### Other Customizations

If you want to use [OhMyZSH](https://ohmyz.sh) or another shell configurator, you can install it now. But don't forget to save/re-add the contents of `~/.zshrc` if the
install overwrites it.

For example, to install OhMyZSH:

```shell
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
cat ~/.zshrc.pre-oh-my-zsh >> ~/.zshrc
```

#### Convenience Scripts

- `clean-s3` - purge all data from a set of s3 buckets, e.g.:
  - `clean-s3 dev -y` - delete everything from your dev buckets
  - Without the `-y`, it displays a dry run showing what *would* be deleted if `-y` were present
- `dbconnect` - connect to your `dev` database via `psql`
- `sg` - open and close ports, e.g.:
  - `sg open <IPADDR | IPRANGE | all> PORT` - allow access on port `PORT` from a single source IP address, a source IP range (expressed in CIDR notation), or the entire Internet
  - `sg close <IPADDR | IPRANGE | all> PORT` - close a previously opened port. The address or range must exactly match what was specified on `open`.
  - `sg close all` - close all ports on all addresses
  - `sg show` - show a list of currently open ports and source addresses
  - When you run `mix phx.server`, Meadow runs on port 3001, so you'll need to open that port if you want to access your Meadow dev instance from a browser

#### Automatic Shutdowns

There are two components of the dev environment that spin down automatically after an idle period.

The Aurora PostgreSQL Serverless database scales down to 0 capacity units after 60 minutes with no active connections. Meadow will attempt to wait for it to spin up, but may time out (especially when running `mix test`). Waiting 20 seconds and running the command again should fix it.

Each developer VM will shut down if no *keep-alive* condition has been met for a period of 30 minutes. At present, the keep-alive conditions are:

- An open [VS Code Remote SSH](https://code.visualstudio.com/docs/remote/ssh) session
- An active [AWS Cloud9 Console](https://us-east-1.console.aws.amazon.com/cloud9/home/shared) session

**Note:** This list specifically excludes active SSH sessions, which are allowed to time out normally.

Since AWS does not charge for stopped VMs, it's important to remember to close VS Code and Cloud9 Console sessions when they're not actively being used.

More keep-alive conditions (e.g., active `tmux` sessions) can be added if needed. Suggestions are welcome.

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
2. Create the developer's environment:
   ```shell
   $ cd individual
   $ terraform init
   $ terraform workspace new USERID
   $ terraform apply
   $ profile_arn=$(terraform output -json | jq -r '.ide_instance_profile_arn.value')
   ```
3. Bootstrap the IDE using the instance role ARN created in the previous step:
   ```shell
   $ cd ..
   $ bin/create-ide.js -u USERID -g GITHUB_USERNAME -e EMAIL -p $profile_arn
   ```
   **Note:** The email address provided must be the `@northwestern.edu` address associated with your NUL AWS accounts.

#### Environment Updates

Use the common/individual Terraform directories to add, update, and maintain resources.

#### Deleting an Individual Environment

1. Make sure all S3 buckets are *completely empty*.
2. Delete the developer's environment:
   ```shell
   $ terraform init
   $ terraform refresh
   $ terraform destroy
   ```
3. Delete the Cloud9 IDE environment manually using the AWS Console or `aws` CLI.

