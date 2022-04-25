#!/bin/bash

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
