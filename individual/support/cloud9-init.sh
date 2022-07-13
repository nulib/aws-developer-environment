pip uninstall aws
curl -s https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscliv2.zip
unzip -qo /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/aws
curl -s http://nul-public.s3.amazonaws.com/ffmpeg.zip -o /tmp/ffmpeg.zip
unzip -qo /tmp/ffmpeg.zip -d /usr/local
rm -f /tmp/ffmpeg.zip
sh -c "$(curl -Ls {initSource}/grow_ebs_volume.sh)"
amazon-linux-extras install epel -y
yum install -y -d1 inotify-tools jq mediainfo nc perl-Image-ExifTool postgresql tmux util-linux-user zsh
chsh -s /bin/zsh ec2-user
hostname "{userId}.dev.rdc.library.northwestern.edu"
as_user mkdir -p ~ec2-user/.ssh
as_user curl -s https://github.com/{githubId}.keys >> ~ec2-user/.ssh/authorized_keys
as_user ssh-keyscan github.com >> ~ec2-user/.ssh/known_hosts
as_user chmod 0600 ~ec2-user/.ssh/known_hosts
as_user git clone https://github.com/asdf-vm/asdf.git ~ec2-user/.asdf --branch v0.9.0
as_user aws configure set default.region us-east-1
as_user git clone https://github.com/nulib/nul-rdc-devtools ~ec2-user/.nul-rdc-devtools
as_user echo 'git -C $HOME/.nul-rdc-devtools/ pull --ff-only' >> ~ec2-user/.zshrc
as_user echo 'source $HOME/.nul-rdc-devtools/scripts/login.sh' >> ~ec2-user/.zshrc
as_user mv ~ec2-user/.c9/stop-if-inactive.sh ~ec2-user/.c9/stop-if-inactive.sh-SAVE
as_user ln -s ~ec2-user/.nul-rdc-devtools/helpers/stop-if-inactive.sh ~ec2-user/.c9/stop-if-inactive.sh
as_user chmod 755 ~ec2-user/.c9/stop-if-inactive.sh
chown -R ec2-user:ec2-user ~ec2-user/.ssh
