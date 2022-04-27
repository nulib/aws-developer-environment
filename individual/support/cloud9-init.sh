pip uninstall aws
curl -s https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscliv2.zip
unzip -qo /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/aws
curl -s http://nul-public.s3.amazonaws.com/ffmpeg.zip -o /tmp/ffmpeg.zip
unzip -qo /tmp/ffmpeg.zip -d /usr/local
rm -f /tmp/ffmpeg.zip
sh -c "$(curl -Ls {initSource}/grow_ebs_volume.sh)"
mv ~ec2-user/.c9/stop-if-inactive.sh ~ec2-user/.c9/stop-if-inactive.sh-SAVE
curl -sLo ~ec2-user/.c9/stop-if-inactive.sh {initSource}/stop-if-inactive.sh
chmod 755 ~ec2-user/.c9/stop-if-inactive.sh
amazon-linux-extras install epel -y
yum install -y -d1 inotify-tools jq mediainfo nc perl-Image-ExifTool postgresql tmux util-linux-user zsh
chsh -s /bin/zsh ec2-user
hostname "{userId}.dev.rdc.library.northwestern.edu"
alias as_user='sudo -Hiu ec2-user '
as_user mkdir -p ~ec2-user/.ssh ~ec2-user/bin
as_user curl -s https://github.com/{githubId}.keys >> ~ec2-user/.ssh/authorized_keys
as_user ssh-keyscan github.com >> ~ec2-user/.ssh/known_hosts
as_user chmod 0600 ~ec2-user/.ssh/known_hosts
as_user git clone https://github.com/asdf-vm/asdf.git ~ec2-user/.asdf --branch v0.9.0
as_user aws configure set default.region us-east-1
as_user curl -Ls {initSource}/zshrc >> ~ec2-user/.zshrc
