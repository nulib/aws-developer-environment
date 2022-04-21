#!/bin/bash

# Clone Meadow
git clone git@github.com:nulib/meadow.git ~/environment/meadow
cd ~/environment/meadow

# Install tool dependencies
asdf-install-plugins
asdf install
for p in $(asdf plugin list); do asdf global $p $(asdf list $p | sort | tail -1); done
asdf-install-npm
asdf reshim
