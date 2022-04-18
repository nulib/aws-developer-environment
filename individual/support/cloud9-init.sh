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
sudo -Hiu ec2-user mkdir -p ~ec2-user/.ssh
sudo -Hiu ec2-user curl -s https://github.com/{githubId}.keys >> ~ec2-user/.ssh/authorized_keys
sudo -Hiu ec2-user git clone https://github.com/asdf-vm/asdf.git ~ec2-user/.asdf --branch v0.9.0
sudo -Hiu ec2-user aws configure set default.region us-east-1
echo 'source <(curl -sL https://raw.githubusercontent.com/{gitRepo}/main/individual/support/dev_environment.sh)'  >> ~ec2-user/.zlogin
echo 'source <(curl -sL https://raw.githubusercontent.com/{gitRepo}/main/individual/support/asdf-helpers)' >> ~ec2-user/.zlogin
echo 'export AWS_REGION=us-east-1' >> ~ec2-user/.zlogin
echo '. $HOME/.asdf/asdf.sh' >> ~ec2-user/.zlogin
echo 'if [[ -e ~/.aws/credentials ]]; then rm -f ~/.aws/credentials; fi' >> ~ec2-user/.zlogin
