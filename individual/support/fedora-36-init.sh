#!/bin/bash -ex

if [[ ! -e /home/ec2-user/.init-complete ]]; then
  exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

  # Install SSM Agent and Session Manager 
  dnf install -y -d1 https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
  dnf install -y -d1 https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm
  systemctl start amazon-ssm-agent
  systemctl start session-manager-plugin

  # Replace `fedora` user with `ec2-user`, maintaing uid and gid
  groupmod -g 1001 fedora
  usermod -u 1001 -g 1001 fedora
  chown -R 1001:1001 /home/fedora
  groupadd -g 1000 ec2-user
  useradd -u 1000 -g 1000 -G adm,wheel,systemd-journal ec2-user
  mkdir -p /home/ec2-user/.ssh
  cp /home/fedora/.ssh/authorized_keys /home/ec2-user/.ssh/authorized_keys
  chown -R 1000:1000 /home/ec2-user
  sed -i s/^fedora/ec2-user/ /etc/sudoers.d/90-cloud-init-users
  userdel -r fedora

  # Install Docker CE and give ec2-user permission to use it
  dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
  dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  systemctl enable --now docker
  usermod -a -G docker ec2-user

  # Install dev and runtime dependencies
  DEPS="autoconf autojump-zsh automake bzip2 bzip2-devel cronie cronie-anacron curl git gnupg2 inotify-tools jq \
    krb5-devel libffi-devel libffi-devel libsqlite3x-devel lsof mediainfo nc ncurses-devel openssl-devel \
    perl-Image-ExifTool postgresql readline-devel tmux util-linux-user zsh"
  dnf group install -y "Development Tools"
  dnf install -y -d1 --allowerasing $DEPS
  systemctl enable --now crond

  # Install ffmpeg
  curl -s http://nul-public.s3.amazonaws.com/ffmpeg.zip -o /tmp/ffmpeg.zip
  unzip -qo /tmp/ffmpeg.zip -d /usr/local
  rm -f /tmp/ffmpeg.zip

  # Install AWS CLI v2
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
  unzip -qo /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install
  rm -rf /tmp/aws /tmp/awscliv2.zip

  # Read instance tags and configuration secrets and set hostname
  INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
  TAG_DATA=$(aws ec2 describe-tags --filters Name=resource-id,Values=$INSTANCE_ID)
  COMMON_CONFIG=$(aws secretsmanager get-secret-value --secret-id "dev-environment/terraform/common" --query "SecretString" --output text)
  
  get_tag() {
    jq -r '.Tags[] | select(.Key == "'$1'") | .Value' <<< $TAG_DATA
  }

  OWNER=$(get_tag Owner)
  hostname "${OWNER}.dev.rdc.library.northwestern.edu"

  # Create and run user setup script
  cat > /tmp/user_setup.sh <<'__END__'
#!/bin/bash -ex
GITHUB_ID=$1
HOME=/home/ec2-user
aws configure set default.region us-east-1
mkdir -p $HOME/.ssh
curl -s https://github.com/${GITHUB_ID}.keys >> $HOME/.ssh/authorized_keys
ssh-keyscan github.com >> $HOME/.ssh/known_hosts
for f in authorized_keys known_hosts; do
  sort -u -o $HOME/.ssh/$f{,}
done
chmod 0600 $HOME/.ssh/known_hosts
set +e
  git clone https://github.com/asdf-vm/asdf.git $HOME/.asdf --branch v0.9.0
  git clone https://github.com/nulib/nul-rdc-devtools $HOME/.nul-rdc-devtools
  source $HOME/.asdf/asdf.sh
  $HOME/.nul-rdc-devtools/bin/backup-ide restore
set -e
if [[ ! -e $HOME/.zprofile ]]; then cat > $HOME/.zprofile <<'__EOC__'; fi
git -C $HOME/.nul-rdc-devtools/ pull --ff-only
source $HOME/.nul-rdc-devtools/scripts/login.sh
__EOC__
set +e
  if asdf list python 2>&1 | grep -v "No " > /dev/null; then
    asdf plugin add python
    asdf install python 3.10.5
    asdf global python 3.10.5
    asdf reshim
  fi
  pip install aws-adfs
set -e
mkdir -p $HOME/.ide
echo SHUTDOWN_TIMEOUT=30 > $HOME/.ide/autoshutdown-configuration
ln -fs $HOME/.nul-rdc-devtools/helpers/stop-if-inactive.sh $HOME/.ide/stop-if-inactive.sh
chmod 755 $HOME/.ide/stop-if-inactive.sh
$HOME/.nul-rdc-devtools/scripts/add_aws_adfs_profile.sh staging arn:aws:iam::625046682746:role/NUL-Avalon-PowerUsers
$HOME/.nul-rdc-devtools/scripts/add_aws_adfs_profile.sh staging-admin arn:aws:iam::625046682746:role/NUL-Avalon-Admins
$HOME/.nul-rdc-devtools/scripts/add_aws_adfs_profile.sh production arn:aws:iam::845225713889:role/NUL-IT-NextGen-PowerUsers
$HOME/.nul-rdc-devtools/scripts/add_aws_adfs_profile.sh production-admin arn:aws:iam::845225713889:role/NUL-IT-NextGen-Admins
rm -rf $HOME/.c9

__END__

  chmod 0755 /tmp/user_setup.sh
  chsh -s /usr/bin/zsh ec2-user
  sudo -Hiu ec2-user /tmp/user_setup.sh $(get_tag GitHubID)
  chown -R ec2-user:ec2-user ~ec2-user/.ssh
  echo "* * * * * root /home/ec2-user/.ide/stop-if-inactive.sh" > /etc/cron.d/auto-shutdown
  touch /home/ec2-user/.init-complete
fi
