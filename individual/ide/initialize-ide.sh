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

# Clone Meadow
cd ~/environment
for repo in meadow miscellany; do
  git clone git@github.com:nulib/$repo.git
done

# Just for now until miscellancy is merged
cd miscellany
git switch 2874-dev-environment

source ~/.zshrc

# Install tool dependencies
cd ../meadow
git switch 2874-cloud9-environment # Just for now until merged
asdf-install-plugins
asdf install
for p in $(asdf plugin list); do asdf global $p $(asdf list $p | sort | tail -1); done
asdf-install-npm
asdf reshim

# If you want oh-my-zsh or another shell configurator, install it now
# But don't forget to save/re-add the contents of ~/.zshrc if the
# install overwrites it.
