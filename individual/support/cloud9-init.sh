pip uninstall aws
curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscliv2.zip
unzip /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/aws
sh -c "$(curl -Ls https://raw.githubusercontent.com/{gitRepo}/{gitRef}/individual/support/grow_ebs_volume.sh)"
mv ~ec2-user/.c9/stop-if-inactive.sh ~ec2-user/.c9/stop-if-inactive.sh-SAVE
curl -sLo ~ec2-user/.c9/stop-if-inactive.sh https://raw.githubusercontent.com/{gitRepo}/{gitRef}/individual/support/stop-if-inactive.sh
chmod 755 ~ec2-user/.c9/stop-if-inactive.sh
yum install -y inotify-tools jq util-linux-user zsh
chsh -s /bin/zsh ec2-user
alias as_user='sudo -Hiu ec2-user '
as_user mkdir -p ~ec2-user/.ssh
as_user curl -s https://github.com/{githubId}.keys >> ~ec2-user/.ssh/authorized_keys
as_user git clone https://github.com/asdf-vm/asdf.git ~ec2-user/.asdf --branch v0.9.0
as_user aws configure set default.region us-east-1
curl -Ls https://raw.githubusercontent.com/{gitRepo}/{gitRef}/individual/support/zlogin >> ~/.zlogin