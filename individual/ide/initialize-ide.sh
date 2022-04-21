#!/bin/bash

# Clone Meadow
cd ~/environment
for repo in meadow miscellany; do
  git clone git@github.com:nulib/$repo.git
done
cd meadow

# Install tool dependencies
asdf-install-plugins
asdf install
for p in $(asdf plugin list); do asdf global $p $(asdf list $p | sort | tail -1); done
asdf-install-npm
asdf reshim
