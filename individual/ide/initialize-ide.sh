#!/bin/bash

# If you sign your git commits, export your local key 
# LOCAL machine:
gpg --export-secret-keys YOUR_ID_HERE > private.key
scp private.key REMOTE_MACHINE:

# REMOTE machine:
gpg --import private.key
gpg --list-secret-keys --keyid-format LONG
# Get key ID from line that starts with `sec`:
# It's a 16-digit hex number that follows an integer and a slash
git config --global user.signingkey KEY_ID

# Configure Git
git config --global user.name "Your Name Here"
git config --global user.email your.git.email@example.com

# Clone Meadow
cd ~/environment
git clone git@github.com:nulib/meadow.git

# Install tool dependencies
cd meadow
git switch 2874-cloud9-environment # Just for now until merged
asdf-install-plugins
asdf install
for p in $(asdf plugin list); do asdf global $p $(asdf list $p | sort | tail -1); done
asdf-install-npm
asdf reshim

# If you want oh-my-zsh or another shell configurator, install it now
# But don't forget to save/re-add the contents of ~/.zshrc if the
# install overwrites it.
#
# For example, to install OhMyZSH:

sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
cat ~/.zshrc.pre-oh-my-zsh >> ~/.zshrc

