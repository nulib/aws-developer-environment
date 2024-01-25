#!/bin/bash -ex

replace_home() {
  home_partition=$1
  eval $(blkid --output export $home_partition)
  cp /etc/fstab /etc/fstab.orig
  grep -v /home /etc/fstab.orig > /etc/fstab
  echo "UUID=$UUID /home                   btrfs   compress=zstd:1 0 0" >> /etc/fstab
  systemctl daemon-reload
  umount /home
  mount /home
}

init_ec2_user() {
  # Create and run user setup script
  GITHUB_ID=$1
  
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
  git clone https://github.com/asdf-vm/asdf.git $HOME/.asdf --branch v0.10.2
  git clone https://github.com/nulib/nul-rdc-devtools $HOME/environment/nul-rdc-devtools
  source $HOME/.asdf/asdf.sh
  conda config --append channels conda-forge
  ln -fs $HOME/environment/nul-rdc-devtools $HOME/.nul-rdc-devtools
  ln -fs $HOME/.nul-rdc-devtools/ide $HOME/.ide
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
set -e
echo SHUTDOWN_TIMEOUT=30 > $HOME/.ide/autoshutdown-configuration
$HOME/.nul-rdc-devtools/scripts/add_aws_adfs_profile.sh staging arn:aws:iam::625046682746:role/NUL-Avalon-PowerUsers
$HOME/.nul-rdc-devtools/scripts/add_aws_adfs_profile.sh staging-admin arn:aws:iam::625046682746:role/NUL-Avalon-Admins
$HOME/.nul-rdc-devtools/scripts/add_aws_adfs_profile.sh production arn:aws:iam::845225713889:role/NUL-IT-NextGen-PowerUsers
$HOME/.nul-rdc-devtools/scripts/add_aws_adfs_profile.sh production-admin arn:aws:iam::845225713889:role/NUL-IT-NextGen-Admins

__END__

  chmod 0755 /tmp/user_setup.sh
  sudo -Hiu ec2-user /tmp/user_setup.sh $GITHUB_ID
  chown -R ec2-user:ec2-user ~ec2-user/.ssh
}

if [[ ! -e /home/ec2-user/.init-complete ]]; then
  exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

  # Install SSM Agent and Session Manager 
  dnf install -y -d1 https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
  dnf install -y -d1 https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm
  systemctl start amazon-ssm-agent
  systemctl start session-manager-plugin

  for dev in /dev/nvme?n1; do
    if [[ $(btrfs property get ${dev}p1 label) == "label=home" ]]; then
      # If there's an existing home filesystem, use it without any new provisioning
      replace_home ${dev}p1
      break
    elif ! sfdisk -d $dev >/dev/null 2>&1; then
      # If there's an empty, unpartitioned volume, partition it, create a filesystem and use it for /home
      parted $dev mklabel gpt
      parted $dev mkpart primary 0% 100%
      sleep 1; partprobe; sleep 1
      mkfs.btrfs -L home ${dev}p1
      sleep 1; partprobe; sleep 1
      eval $(blkid --output export ${dev}p1)
      mkdir /mnt/newhome
      mount -t btrfs ${dev}p1 /mnt/newhome
      rsync -arv /home/ /mnt/newhome/
      umount /mnt/newhome
      rmdir /mnt/newhome
      replace_home ${dev}p1
      new_home=true
      break
    fi
  done

  # Replace `fedora` user with `ec2-user`, maintaing uid and gid
  groupmod -g 1001 fedora
  usermod -u 1001 -g 1001 fedora
  if [[ -d /home/fedora ]]; then
    chown -R 1001:1001 /home/fedora
  fi
  groupadd -g 1000 ec2-user
  useradd -u 1000 -g 1000 -G adm,wheel,systemd-journal ec2-user
  if [[ $new_home == "true" ]]; then
    mkdir -p /home/ec2-user/.ssh
    cp /home/fedora/.ssh/authorized_keys /home/ec2-user/.ssh/authorized_keys
    chown -R 1000:1000 /home/ec2-user
  fi
  sed -i s/^fedora/ec2-user/ /etc/sudoers.d/90-cloud-init-users
  userdel -r fedora

  # Install Docker CE and give ec2-user permission to use it
  dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
  dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  systemctl enable --now docker
  usermod -a -G docker ec2-user

  # Install RPM Fusion repos
  dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
  dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

  # Install dev and runtime dependencies
  DEPS="at autoconf autojump-zsh automake bzip2 bzip2-devel conda cronie cronie-anacron curl direnv ffmpeg 
    fop gcc-c++ git gnupg2 inotify-tools jq krb5-devel libffi-devel libpq-devel libsqlite3x-devel libxslt 
    lsof mediainfo nc ncurses-devel openssl-devel perl perl-Image-ExifTool postgresql readline-devel restic 
    tmux util-linux-user vim zsh"
  dnf group install -y "Development Tools"
  dnf install -y -d1 --allowerasing $DEPS
  systemctl enable --now atd
  systemctl enable --now crond
  chsh -s /usr/bin/zsh ec2-user

  # Install AWS CLI v2
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
  unzip -qo /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install
  rm -rf /tmp/aws /tmp/awscliv2.zip

  # Install MC
  curl -o /usr/local/bin/mc https://dl.min.io/client/mc/release/linux-amd64/mc
  chmod 0755 /usr/local/bin/mc

  # Read instance tags and configuration secrets and set hostname
  INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
  TAG_DATA=$(aws ec2 describe-tags --filters Name=resource-id,Values=$INSTANCE_ID)
  COMMON_CONFIG=$(aws secretsmanager get-secret-value --secret-id "dev-environment/terraform/common" --query "SecretString" --output text)
  
  get_tag() {
    jq -r '.Tags[] | select(.Key == "'$1'") | .Value' <<< $TAG_DATA
  }

  OWNER=$(get_tag Owner)
  hostname "${OWNER}.dev.rdc.library.northwestern.edu"

  if [[ $new_home == "true" ]]; then
    init_ec2_user $(get_tag GitHubID)
  fi
  echo "* * * * * root ( sleep 15 ; /home/ec2-user/.ide/stop-if-inactive.sh )" > /etc/cron.d/auto-shutdown
  touch /home/ec2-user/.init-complete
fi
