# AWS EC2-Based Developer Environment

## Developers

### Prerequisites

- Make sure you have [`aws sso login`](http://docs.rdc.library.northwestern.edu/2._Developer_Guides/Environment_and_Tools/AWS-Authentication/) set up properly on your local system.

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
   (You may be prompted to log into AWS by the SSO login handler.)
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
- This hostname can also be used to connect a [Visual Studio Code Remote SSH](https://code.visualstudio.com/docs/remote/ssh) session
  - The Remote SSH extension's Connect Timeout setting should be changed from the default (15 seconds) to at least 120 seconds.
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
  - [`direnv`](https://direnv.net/)
  - [`exiftool`](https://exiftool.org)
  - [`jq`](https://stedolan.github.io/jq/manual/)
  - [`mediainfo`](https://mediaarea.net/en/MediaInfo)
  - [`psql`](https://www.postgresql.org/docs/current/app-psql.html)
  - [`tmux`](https://github.com/tmux/tmux/wiki)
- Developer VMs are persistent, but also easy to tear down and rebuild in minutes. Meadow data (S3/DB/OpenSearch) will survive a reset,though your configurations and customizations will be gone. Don't hesitate to ask for a reset if you need one.
- Thanks to the `ForwardAgent yes` line in the SSH config above, your local SSH identities will be forwarded/delegated to the remote machine for the duration of your login session. That means you'll be able to automatically authenticate to servers that use public key authentication (e.g., GitHub) without having to copy your private keys around. See [SSH Key Forwarding](#ssh-key-forwarding) below for details and troubleshooting.
- By default, your  have read access to everything in the staging environment, and full access to resources required for "normal" development work (e.g., your own S3 buckets)
  - [`aws sso`](http://docs.rdc.library.northwestern.edu/2._Developer_Guides/Environment_and_Tools/AWS-Authentication/) is also installed and configured in case you need to assume a different role (e.g., to run a Terraform or SAM deploy that creates resources you don't have access to by default)
  - Export the correct `AWS_PROFILE` and log in as usual to assume one of your regular AWS roles
  - To return to the default instance role, simply `export AWS_PROFILE=default` or `unset AWS_PROFILE`

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

- `app-environment` - Write an `.envrc` file (for use with [`direnv`](https://direnv.net/)) for a given app to the local directory
  - `app-environment avr` - Write AVR's dev configuration
- `clean-s3` - purge all data from a set of s3 buckets, e.g.:
  - `clean-s3 --app meadow dev -y` - delete everything from your meadow dev buckets
  - Without the `-y`, it displays a dry run showing what *would* be deleted if `-y` were present
- `dbconnect` - connect to your `dev` database via `psql`
- `es-proxy` - set up a tunnel to the Elasticsearch index
  - `es-proxy start` - start the proxy
  - `es-proxy stop` - stop the proxy
- `https-proxy` - Run an SSL proxy to a local HTTP service
  - `https-proxy start 3002 3000` - start proxying `https://YOUR_HOSTNAME:3002/` to `http://localhost:3000/`
  - `https-proxy stop 3002` - stop the proxy on port 3002
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
- The existence of a file called `/home/ec2-user/.keep-alive` (this is a useful tool to keep your instance running during long-running operations, but don't forget to delete the file afterward!)

**Note:** This list specifically excludes active SSH sessions, which are allowed to time out normally.

Since AWS does not charge for stopped VMs, it's important to remember to close VS Code and Cloud9 Console sessions when they're not actively being used.

More keep-alive conditions (e.g., active `tmux` sessions) can be added if needed. Suggestions are welcome.

#### SSH Key Forwarding

The developer environment forwards SSH authentication requests back to your local system, where the SSH Agent process can respond to them. This allows you to do things like authenticate to GitHub without having to move your private keys onto possibly untrusted servers.

The local SSH Agent only caches keys for a limited time, and if your session lasts beyond the TTL period, you may receive an error such as the following:

```
$ git push origin
git@github.com: Permission denied (publickey).
fatal: Could not read from remote repository.

Please make sure you have the correct access rights
and the repository exists.
```

If this happens, run `ssh-add -l` on the *remote* system and proceed according to the output:
- **Output:** `Could not open a connection to your authentication agent.`
  **Action:** 
  1. Try running `export SSH_AUTH_SOCK=$(ls -c /run/user/1000/vscode-ssh-auth-sock-* | head -1)` on the remote to 
     refresh the socket connection between the local and remote systems. Try `ssh-add -l` again.
  2. If it still can't connect, close your remote terminal (just the terminal, not the whole VS Code window), open a new one, 
     and try this step again.
  3. If that still doesn't solve the problem, try opening the VS Code command panel (Cmd+Shift+P) and issue the **Developer: Reload 
     window** command.
- **Output:** `The agent has no identities.`
- **Action:**
  1. Open a *local* terminal and run `ssh-add`. You may be prompted to enter your key's passphrase, if it has one.
  2. Run `ssh-add -l` on the local system.
  3. Run `ssh-add -l` on the remote system again and see if the list of keys matches the list from Step 2 above.

## Environment Setup & Maintenance

All of the following steps require you to have your `AWS_PROFILE` set to a configured profile with full admin access to the NUL staging environment (e.g., `staging-admin`). If the specified profile is linked to an ADFS role, you'll also need to make sure you're [logged in](http://docs.rdc.library.northwestern.edu/2._Developer_Guides/Environment_and_Tools/AWS-Authentication/).

### Common Infrastructure

The `common` directory contains the Terraform manifests for provisioning and maintaining components common to all developer environments.

#### Usage

`terraform <init|plan|apply>` as you would with any other Terraform project. There are no variables or other configuration to worry about. If initializing for the first time, you'll need to know which S3 bucket holds the existing state.

### Individual Developer Environments

The resources for setting up and maintaining developer environments are in the `individual` directory.

#### New Environment

To create a new environment:

```shell
$ cd individual
$ terraform init
$ terraform workspace new USERID
$ terraform apply
```

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
