#!/bin/bash -ex
if [[ ! -e /home/ec2-user/.init-complete ]]; then
  DEPS="autojump bzip2-devel cronie cronie-anacron docker git gnupg2 inotify-tools jq krb5-devel libffi-devel \
    libffi-devel libsqlite3x-devel lsof mediainfo nc ncurses-devel openssl-devel perl-Image-ExifTool postgresql13 \
    readline-devel tmux util-linux-user zsh"

  exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
  dnf install -y -d1 https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
  dnf install -y -d1 https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm
  aws s3 cp s3://nul-dev-environment-tfstate/setup/RPM-GPG-KEY-EPEL-9 /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-9
  aws s3 cp s3://nul-dev-environment-tfstate/setup/epel.repo /etc/yum.repos.d/epel.repo
  dnf group install -y "Development Tools"
  dnf install -y -d1 --allowerasing $DEPS
  curl -s http://nul-public.s3.amazonaws.com/ffmpeg.zip -o /tmp/ffmpeg.zip
  unzip -qo /tmp/ffmpeg.zip -d /usr/local
  rm -f /tmp/ffmpeg.zip
  chsh -s /usr/bin/zsh ec2-user
  usermod -a -G docker ec2-user
  systemctl enable --now crond
  systemctl enable --now docker
  if [[ -e /usr/libexec/docker/cli-plugins/buildx ]]; then
    ln -fs /usr/libexec/docker/cli-plugins/buildx /usr/libexec/docker/cli-plugins/docker-buildx
  fi

  INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
  TAG_DATA=$(aws ec2 describe-tags --filters Name=resource-id,Values=$INSTANCE_ID)
  COMMON_CONFIG=$(aws secretsmanager get-secret-value --secret-id "dev-environment/terraform/common" --query "SecretString" --output text)
  
  get_tag() {
    jq -r '.Tags[] | select(.Key == "'$1'") | .Value' <<< $TAG_DATA
  }

  OWNER=$(get_tag Owner)
  hostname "${OWNER}.dev.rdc.library.northwestern.edu"

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
  sudo -Hiu ec2-user /tmp/user_setup.sh $(get_tag GitHubID)
  chown -R ec2-user:ec2-user ~ec2-user/.ssh
  echo "* * * * * root /home/ec2-user/.ide/stop-if-inactive.sh" > /etc/cron.d/auto-shutdown
  touch /home/ec2-user/.init-complete
fi
